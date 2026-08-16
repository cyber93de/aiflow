#!/usr/bin/env python3
"""Guard against `[ -x ]` gates in front of interpreter calls.

aiflow-wrn: `bin/aiflow` refused to run its `.aiflow/*.sh` helpers unless the file
carried the exec bit — and then invoked them as `bash <path>`, where the exec bit is
irrelevant. On Windows `core.filemode=false` drops the bit silently, so a project
developed there checks the scripts in as 100644 and every one of those commands dies on
Linux with a misleading "not found / not executable". The gate bought nothing and cost
the feature. That shape survived aiflow-e0o and its review because nothing looked for it.

The check is mechanical: inside one file, an `-x` test predicate whose operand is later
(or earlier) passed to an interpreter — `bash`, `sh`, `pwsh`, `python3`, `node`, … — is
an error. Use `[ -f ]` there. A `-x` test in front of a *direct* call (`"$f" --flag`) is
the legitimate case and is not reported.

Scope is deliberately one file at a time: a gate in `bin/aiflow` guarding a `bash` call
that lives in `lib/foo.sh` is not detected. Matching across files needs path resolution
through variables and would trade this script's zero false positives for guesswork.

Repo-only, like check-twins.py and check-rendered.py — it is not shipped into
`templates/`, so generated projects do not pay for a Python CI step to check it.

Usage: check-exec-gates.py [<repo root>]
       check-exec-gates.py --selftest
Exits non-zero and prints GitHub-Actions error annotations on any finding.
"""

import pathlib
import re
import sys
import tempfile

# Directories never worth walking: VCS internals, the issue DB, vendored trees.
SKIP_DIRS = {".git", ".beads", "node_modules", "__pycache__", ".venv"}

# Extensionless shell files live here; everything else is matched by the `.sh` suffix.
HOOK_DIRS = {".githooks", "hooks"}

# Interpreters that read the script as *data* — the exec bit means nothing to them.
INTERPRETERS = r"bash|sh|dash|zsh|ksh|pwsh|powershell|python3|python|node|perl|ruby"

# `[ -x foo ]`, `[[ -x foo ]]`, `test -x foo`, and their negations. The operand runs to
# the next whitespace or `]` and may be quoted.
X_TEST = re.compile(r"""(?:\[\[?|\btest)\s+(?:!\s+)?-x\s+("[^"]*"|'[^']*'|[^\s\]]+)""")

# `bash foo`, `pwsh -File foo`, `python3 -u foo` — an interpreter plus optional flags. A
# leading `exec`/`command`/`&&`/`|` is irrelevant: \b anchors on the interpreter itself.
INTERP_CALL = re.compile(
    rf"""\b(?:{INTERPRETERS})\b((?:\s+-[^\s]+)*)\s+("[^"]*"|'[^']*'|[^\s;|&)]+)""")

# Files whose findings are accepted, as "<repo-relative path>: <operand>". Add with a
# comment saying why the exec bit genuinely matters there — an empty list is the point.
EXEC_GATE_EXEMPT: set[str] = set()


def normalize(operand: str) -> str:
    """Strip quoting and `${VAR}` braces so the gate and the call compare equal."""
    operand = operand.strip()
    if len(operand) >= 2 and operand[0] == operand[-1] and operand[0] in "\"'":
        operand = operand[1:-1]
    return re.sub(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}", r"$\1", operand).strip()


def shell_files(root: pathlib.Path) -> list[pathlib.Path]:
    """Every shell script under `root`: any `*.sh`, plus extensionless hook files."""
    found = []
    for path in root.rglob("*"):
        if not path.is_file() or any(part in SKIP_DIRS for part in path.parts):
            continue
        if path.suffix == ".sh" or (not path.suffix and path.parent.name in HOOK_DIRS):
            found.append(path)
    return sorted(found)


def interpreted_operands(text: str) -> set[str]:
    """Normalized paths this file hands to an interpreter (`bash x.sh`, `pwsh -File x`)."""
    operands = set()
    for flags, operand in INTERP_CALL.findall(text):
        # `bash -c '…'` / `sh -c` take a program, not a path — the exec bit is irrelevant
        # there for a different reason, and the operand is a code string.
        if re.search(r"\s-\w*c\b", flags):
            continue
        operands.add(normalize(operand))
    return operands


def check_file(text: str, where: str) -> list[tuple[str, int, str]]:
    """Report `-x` gates on a path this file also runs through an interpreter."""
    called = interpreted_operands(text)
    problems = []
    for lineno, line in enumerate(text.splitlines(), 1):
        for operand in X_TEST.findall(line):
            target = normalize(operand)
            if not target or target not in called:
                continue
            if f"{where}: {target}" in EXEC_GATE_EXEMPT:
                continue
            problems.append((where, lineno, (
                f"`-x` gate on {target}, which this file runs as `bash {target}` — the exec "
                f"bit is irrelevant to an interpreted call and is dropped by "
                f"core.filemode=false on Windows. Use `[ -f ]`.")))
    return problems


def run(root: pathlib.Path) -> list[tuple[str, int, str]]:
    """Check every shell script under a repo root."""
    problems = []
    for path in shell_files(root):
        where = path.relative_to(root).as_posix()
        problems += check_file(path.read_text(encoding="utf-8", errors="replace"), where)
    return problems


# The shapes that matter: the aiflow-wrn two-line gate, a one-line `&&` gate, brace vs
# bare variable spelling, and the two legitimate uses that must stay quiet.
FIXTURE = """\
#!/usr/bin/env bash
[ -x "$AIFLOW_DIR/gated.sh" ] || { echo "not executable" >&2; exit 1; }
bash "$AIFLOW_DIR/gated.sh" "$@"

test -x "${DIR}/braced.sh" && bash "$DIR/braced.sh"

[[ -x "$DIR/psgate.ps1" ]] && pwsh -NoProfile -File "$DIR/psgate.ps1"

# legitimate: gate before a DIRECT call, where the exec bit is exactly what is needed
[ -x "$DIR/direct.sh" ] && "$DIR/direct.sh" --flag

# legitimate: probing a tool on PATH, nothing interpreted here
[ -x "$(command -v jq)" ] || echo "install jq" >&2

# not a path: `bash -c` takes a program string
[ -x "$DIR/inline.sh" ]; bash -c 'echo hi'
"""


def selftest() -> int:
    """Verify each bad shape fires exactly once and each good shape stays quiet."""
    failed = 0

    def expect(condition: bool, what: str) -> None:
        nonlocal failed
        if not condition:
            print(f"::error::selftest: {what}")
            failed = 1

    problems = check_file(FIXTURE, "fixture.sh")
    flagged = {lineno for _, lineno, _ in problems}
    expect(flagged == {2, 5, 7}, f"expected findings on lines 2, 5, 7; got {sorted(flagged)}")

    expect(normalize('"${A}/b.sh"') == "$A/b.sh", f"normalize: {normalize('${A}/b.sh')!r}")
    expect(normalize("'x'") == "x", "normalize does not strip single quotes")

    ops = interpreted_operands("bash a.sh\npwsh -File b.ps1\nbash -c 'echo'\npython3 -u c.py\n")
    expect(ops == {"a.sh", "b.ps1", "c.py"}, f"interpreted_operands returned {ops}")

    # the exemption must silence a real finding, and only the one it names
    EXEC_GATE_EXEMPT.add("fixture.sh: $AIFLOW_DIR/gated.sh")
    try:
        left = {lineno for _, lineno, _ in check_file(FIXTURE, "fixture.sh")}
        expect(left == {5, 7}, f"exemption left {sorted(left)}, expected [5, 7]")
    finally:
        EXEC_GATE_EXEMPT.discard("fixture.sh: $AIFLOW_DIR/gated.sh")

    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        (root / ".githooks").mkdir()
        (root / ".githooks/pre-commit").write_text(FIXTURE, encoding="utf-8")
        (root / "clean.sh").write_text('[ -f "$D/x.sh" ] && bash "$D/x.sh"\n', encoding="utf-8")
        (root / ".git").mkdir()
        (root / ".git/hooks").mkdir()
        (root / ".git/hooks/pre-commit").write_text(FIXTURE, encoding="utf-8")
        files = sorted(p.relative_to(root).as_posix() for p in shell_files(root))
        expect(files == [".githooks/pre-commit", "clean.sh"],
               f"shell_files collected {files} (the .git/ copy must not be walked)")
        found = run(root)
        expect(len(found) == 3 and {w for w, _, _ in found} == {".githooks/pre-commit"},
               f"run() over a tree returned {found}")

    print("selftest: gate shapes, normalization, exemption, file walk"
          + (" — FAILED" if failed else " — ok"))
    return failed


def main(argv: list[str]) -> int:
    """Check a repo root (default: cwd) and annotate every finding."""
    if argv[:1] == ["--selftest"]:
        return selftest()
    root = pathlib.Path(argv[0] if argv else ".")
    problems = run(root)
    for where, lineno, problem in problems:
        print(f"::error file={where},line={lineno}::{problem}")
    print(f"exec-gate check: {len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
