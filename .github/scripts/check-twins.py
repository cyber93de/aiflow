#!/usr/bin/env python3
"""Guard the Bash/PowerShell twin contract.

CLAUDE.md: everything a project invokes on its own ships as a `.sh` + `.ps1` pair,
and several `lib/*.ps1` are full native implementations rather than shims — so a
feature added to one twin only ships broken on the other platform, silently. That
has happened (aiflow-coy) and nothing detected it.

Three checks, all mechanical:
  pairing   every twinned script has both halves
  dispatch  `bin/aiflow` and `bin/aiflow.ps1` expose the same subcommands
  help      every dispatched subcommand appears in its own entry point's USAGE block

What this does NOT check: divergence *inside* an existing twin pair — a step added
to `lib/apply.sh` with no counterpart in `lib/apply.ps1` is still invisible here.
"enforced" means the surface, not proven parity.

Usage: check-twins.py [<repo root>]
       check-twins.py --selftest
Exits non-zero and prints GitHub-Actions error annotations on any finding.
"""

import pathlib
import re
import sys
import tempfile

# Directories whose *.sh must have a *.ps1 next to them, and vice versa.
# `.aiflow/` is deliberately absent: in a generated project it is rendered output that
# `aiflow project-update` refreshes from `templates/.aiflow/` (which IS covered), not
# source. This repo's own `.aiflow/` is stale and missing halves — tracked separately.
TWIN_DIRS = [
    "lib",
    ".claude/hooks",
    "templates/.aiflow",
    "templates/.claude/hooks",
    "templates/docker",
]

# Twinned pairs that do not live in a TWIN_DIRS directory.
TWIN_FILES = ["install"]

# Scripts that are deliberately one-platform-only, as repo-relative paths (e.g.
# "lib/foo.sh") so an exemption never leaks to a same-named script elsewhere. Add with a
# comment saying why — an empty exemption list is the point, not an accident.
TWIN_EXEMPT: set[str] = set()

# Handled by the Bash `*)` catch-all and the PowerShell `default` branch rather than an
# explicit case, so they never appear as a label — comparing them would always fail.
DISPATCH_EXEMPT = {"help", "-h", "--help"}

# Both entry points carry ~28 dispatch groups. A parser that suddenly finds far fewer has
# been broken by a layout change — fail loudly rather than pass an unchecked file.
MIN_GROUPS = 15

# `  cmd|alias)` — a case label inside the dispatch `case` block. The 2-4 space window
# assumes dispatch labels stay at the top level of the block: a nested `case` inside a
# subcommand body would be read as another label (a loud false positive, not a silent pass).
SH_CASE = re.compile(r"^\s{2,4}[\"']?([a-z0-9|_.-]+)[\"']?\)")
# `'cmd' {` or `{ $_ -in 'cmd','alias' } {` — a switch label in bin/aiflow.ps1.
PS_CASE = re.compile(
    r"^(?:\{\s*\$_\s+-in\s+)?((?:[\"'][a-z0-9._-]+[\"']\s*,\s*)*[\"'][a-z0-9._-]+[\"'])\s*(?:\}\s*)?\{")
PS_LABEL = re.compile(r"[\"']([a-z0-9._-]+)[\"']")


def sh_dispatch_block(text: str) -> str:
    """The body of the LAST `case "$cmd" in` — bin/aiflow has an earlier, unrelated one."""
    starts = [m.end() for m in re.finditer(r'case\s+"\$cmd"\s+in', text)]
    if not starts:
        return ""
    body = text[starts[-1]:]
    end = re.search(r"^esac", body, re.M)
    return body[:end.start()] if end else body


def ps_dispatch_block(text: str) -> str:
    """The body of `switch ($cmd) {` up to the closing brace in column 0."""
    start = re.search(r"switch\s+\(\$cmd\)\s*\{", text)
    if not start:
        return ""
    body = text[start.end():]
    end = re.search(r"^\}", body, re.M)
    return body[:end.start()] if end else body


def sh_usage_block(text: str) -> str:
    """The `cat <<'EOF' … EOF` usage heredoc — NOT the whole file.

    Searched inside the dispatch block (the heredoc lives in its catch-all branch), so an
    unrelated heredoc elsewhere in the file cannot be mistaken for the usage text. Must
    contain USAGE, or the caller treats it as not found rather than checking the wrong text.
    """
    m = re.search(r"<<\s*['\"]?EOF['\"]?\n(.*?)^EOF$", sh_dispatch_block(text), re.S | re.M)
    return m.group(1) if m and "USAGE" in m.group(1) else ""


def ps_usage_block(text: str) -> str:
    """The `@' … '@` usage here-string — NOT the whole file. Must contain USAGE."""
    m = re.search(r"^@'\n(.*?)^'@", ps_dispatch_block(text), re.S | re.M)
    return m.group(1) if m and "USAGE" in m.group(1) else ""


def sh_dispatch(text: str) -> list[set[str]]:
    """Alias groups dispatched by bin/aiflow, one set per case label."""
    return [set(m.group(1).split("|")) for line in sh_dispatch_block(text).splitlines()
            if (m := SH_CASE.match(line))]


def ps_dispatch(text: str) -> list[set[str]]:
    """Alias groups dispatched by bin/aiflow.ps1, one set per switch label."""
    groups = []
    for line in ps_dispatch_block(text).splitlines():
        m = PS_CASE.match(line.strip())
        if m:
            groups.append(set(PS_LABEL.findall(m.group(1))))
    return groups


def check_pairing(root: pathlib.Path) -> list[tuple[str, str]]:
    """Report scripts that exist as only one half of a twin pair, as (file, problem)."""
    problems = []
    targets: list[tuple[pathlib.Path, str]] = []
    for rel in TWIN_DIRS:
        base = root / rel
        if base.is_dir():
            targets += [(p, rel) for p in sorted(base.glob("*.sh")) + sorted(base.glob("*.ps1"))]
    for name in TWIN_FILES:
        targets += [(root / f"{name}{ext}", "") for ext in (".sh", ".ps1")
                    if (root / f"{name}{ext}").is_file()]
    for path, rel in targets:
        where = f"{rel}/{path.name}" if rel else path.name
        if where in TWIN_EXEMPT:
            continue
        other = ".ps1" if path.suffix == ".sh" else ".sh"
        if not path.with_suffix(other).exists():
            problems.append((where, f"{where} has no {other} twin"))
    return problems


def check_dispatch(sh_groups: list[set[str]], ps_groups: list[set[str]]) -> list[tuple[str, str]]:
    """Report subcommands one entry point dispatches and the other does not."""
    sh_all = {c for g in sh_groups for c in g} - DISPATCH_EXEMPT
    ps_all = {c for g in ps_groups for c in g} - DISPATCH_EXEMPT
    problems = []
    for cmd in sorted(sh_all - ps_all):
        problems.append(("bin/aiflow.ps1", f"bin/aiflow dispatches '{cmd}' but bin/aiflow.ps1 does not"))
    for cmd in sorted(ps_all - sh_all):
        problems.append(("bin/aiflow", f"bin/aiflow.ps1 dispatches '{cmd}' but bin/aiflow does not"))
    return problems


def check_help(groups: list[set[str]], usage: str, name: str) -> list[tuple[str, str]]:
    """Report dispatched subcommands the entry point's own USAGE block never mentions."""
    problems = []
    for group in groups:
        if group & DISPATCH_EXEMPT:
            continue
        if not any(re.search(rf"aiflow {re.escape(c)}\b", usage) for c in group):
            problems.append((name, f"{name} dispatches {'/'.join(sorted(group))} "
                                   f"but its usage block never mentions it"))
    return problems


def run(root: pathlib.Path) -> list[tuple[str, str]]:
    """Run all three checks against a repo root."""
    problems = check_pairing(root)
    sh_path, ps_path = root / "bin/aiflow", root / "bin/aiflow.ps1"
    if not sh_path.is_file() or not ps_path.is_file():
        return problems + [("bin/aiflow", "bin/aiflow and bin/aiflow.ps1 must both exist")]
    sh_text = sh_path.read_text(encoding="utf-8")
    ps_text = ps_path.read_text(encoding="utf-8")
    sh_groups, ps_groups = sh_dispatch(sh_text), ps_dispatch(ps_text)
    if len(sh_groups) < MIN_GROUPS or len(ps_groups) < MIN_GROUPS:
        return problems + [("bin/aiflow", f"parsed only {len(sh_groups)}/{len(ps_groups)} dispatch "
                                          f"groups (expected >= {MIN_GROUPS}) — the layout changed, "
                                          f"fix this script instead of trusting it")]
    sh_usage, ps_usage = sh_usage_block(sh_text), ps_usage_block(ps_text)
    if not sh_usage or not ps_usage:
        return problems + [("bin/aiflow", "could not locate a usage block in one of the entry "
                                          "points — fix this script")]
    problems += check_dispatch(sh_groups, ps_groups)
    problems += check_help(sh_groups, sh_usage, "bin/aiflow")
    problems += check_help(ps_groups, ps_usage, "bin/aiflow.ps1")
    return problems


# Deliberately includes the shapes that have fooled this script: an earlier `case "$cmd" in`
# that is not the dispatch block, and a help mention outside the usage heredoc.
SH_FIXTURE = """\
case "$cmd" in
  init|update) : ;;
esac
echo "  (skipped - run 'aiflow only-sh' anytime)"
case "$cmd" in
  init)    bash init.sh ;;
  a|b)     bash ab.sh ;;
  only-sh) bash x.sh ;;
  help|-h) usage ;;
  *)
    cat <<'EOF'
USAGE
  aiflow init  do a thing
  aiflow a     do another
EOF
    ;;
esac
"""

PS_FIXTURE = """\
switch ($cmd) {
  'init'    { & 'init.ps1' }
  { $_ -in 'a','b' } { & 'ab.ps1' }
  default {
@'
USAGE
  aiflow init  do a thing
'@ | Write-Output
  }
}
"""


def selftest() -> int:
    """Verify every check fires on a known-bad fixture and stays quiet on a good one."""
    failed = 0

    def expect(condition: bool, what: str) -> None:
        nonlocal failed
        if not condition:
            print(f"::error::selftest: {what}")
            failed = 1

    sh_groups, ps_groups = sh_dispatch(SH_FIXTURE), ps_dispatch(PS_FIXTURE)
    # the leading non-dispatch `case` must NOT contribute a group
    expect(sh_groups == [{"init"}, {"a", "b"}, {"only-sh"}, {"help", "-h"}],
           f"sh_dispatch parsed {sh_groups}")
    expect(ps_groups == [{"init"}, {"a", "b"}], f"ps_dispatch parsed {ps_groups}")

    disp = check_dispatch(sh_groups, ps_groups)
    expect(len(disp) == 1 and "'only-sh'" in disp[0][1], f"check_dispatch returned {disp}")
    expect(not check_dispatch(sh_groups, sh_dispatch(SH_FIXTURE)), "identical dispatch flagged")

    sh_usage = sh_usage_block(SH_FIXTURE)
    expect("aiflow init" in sh_usage and "only-sh" not in sh_usage,
           f"sh_usage_block leaked or truncated: {sh_usage!r}")
    # 'a' is documented so its alias 'b' must not be reported; 'only-sh' is mentioned ONLY
    # outside the usage block, so it must be.
    sh_help = check_help(sh_groups, sh_usage, "sh")
    expect(len(sh_help) == 1 and "only-sh" in sh_help[0][1], f"check_help returned {sh_help}")
    ps_help = check_help(ps_groups, ps_usage_block(PS_FIXTURE), "ps")
    expect(len(ps_help) == 1 and "a/b" in ps_help[0][1], f"ps check_help returned {ps_help}")

    # a truncated dispatch must trip the floor rather than pass an unchecked file
    floor = run(pathlib.Path(tempfile.gettempdir()))  # no bin/aiflow there
    expect(any("must both exist" in p for _, p in floor), f"missing entry points not caught: {floor}")

    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        (root / "lib").mkdir()
        for name in ("orphan.sh", "other.ps1", "paired.sh", "paired.ps1"):
            (root / "lib" / name).write_text("x", encoding="utf-8")
        (root / "install.sh").write_text("x", encoding="utf-8")  # TWIN_FILES, no .ps1
        pairing = check_pairing(root)
        expect(len(pairing) == 3, f"check_pairing returned {pairing}")
        expect(any(w == "install.sh" for w, _ in pairing), "TWIN_FILES pair not checked")
        expect(all("paired" not in p for _, p in pairing), "check_pairing flagged a matched pair")

    print("selftest: dispatch, usage, help and pairing" + (" — FAILED" if failed else " — ok"))
    return failed


def main(argv: list[str]) -> int:
    """Check a repo root (default: cwd) and annotate every finding."""
    if argv[:1] == ["--selftest"]:
        return selftest()
    root = pathlib.Path(argv[0] if argv else ".")
    problems = run(root)
    for where, problem in problems:
        print(f"::error file={where}::{problem}")
    print(f"twin check: {len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
