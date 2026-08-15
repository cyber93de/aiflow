#!/usr/bin/env python3
"""Guard this repo's rendered copies of `templates/` against drift.

aiflow develops on itself: `.aiflow/` here is a rendered copy of `templates/.aiflow/`,
refreshed from it and never hand-edited (see `.claude/memory/design-decisions.md`).
Nothing enforced that, and it rotted — six missing `.ps1`, both `protect` halves gone,
and a `ralph-headless.sh` two designs out of date, which broke `aiflow protect` on every
platform here and every audit command on Windows (aiflow-30k).

`check-twins.py` only sees a *missing half*. This sees *content* drift, which was the
worst part of that bug and the part nothing could catch.

Only mechanical scripts are compared. Per-project state (`config.json`, `branching.json`)
and run artifacts are not mirrored and are never touched.

Not shipped into `templates/`: a generated project has no `templates/` to compare against.

Usage: check-rendered.py [<repo root>]
       check-rendered.py --selftest
Exits non-zero and prints GitHub-Actions error annotations on any finding.
"""

import contextlib
import io
import pathlib
import sys
import tempfile

# (template dir, rendered copy, globs, exempt). `exempt` names files in the RENDERED copy that
# legitimately have no template counterpart — add one only with a comment saying why.
# `.claude/agents|commands|skills` is not here yet: five agents carry a deliberate local
# `model: haiku` line that would have to be exempted first (aiflow-jxe).
MIRRORS = [
    ("templates/.aiflow", ".aiflow", ("*.sh", "*.ps1"), frozenset()),
    ("templates/.claude/hooks", ".claude/hooks", ("*.sh", "*.ps1"), frozenset()),
    # the CI guards themselves are mechanically copied into a project by project-update;
    # these two are about aiflow's own structure and deliberately stay repo-only.
    ("templates/.github/scripts", ".github/scripts", ("*.py",),
     frozenset({"check-twins.py", "check-rendered.py"})),
]


def normalised(path: pathlib.Path) -> bytes:
    """File content with line endings flattened.

    `.gitattributes` pins `*.sh` to LF and `*.ps1` to CRLF, so both copies normally agree
    byte for byte — but a checkout with different settings must not fail the build over
    invisible characters. Real content drift survives this.
    """
    return path.read_bytes().replace(b"\r\n", b"\n")


def check_mirror(root: pathlib.Path, src_rel: str, dst_rel: str, globs: tuple[str, ...],
                 exempt: frozenset[str] = frozenset()) -> list[tuple[str, str]]:
    """Compare one rendered directory against its template, as (file, problem) pairs."""
    src, dst = root / src_rel, root / dst_rel
    # A configured mirror whose directories are gone means MIRRORS is stale — reporting
    # "0 problems" for a tree nobody looked at is worse than no guard at all.
    for rel, path in ((src_rel, src), (dst_rel, dst)):
        if not path.is_dir():
            return [(rel, f"{rel} is not a directory but MIRRORS expects it — fix this script "
                          f"instead of trusting it")]
    problems = []
    # exempt applies to BOTH sides: a repo-only script that later gains a template counterpart
    # must stay ignored, not flip into "missing from the rendered copy".
    expected = {p.name for g in globs for p in src.glob(g)} - exempt
    present = {p.name for g in globs for p in dst.glob(g)} - exempt
    for name in sorted(expected - present):
        problems.append((f"{dst_rel}/{name}",
                         f"{dst_rel}/{name} is missing — copy it from {src_rel}/"))
    for name in sorted(present - expected):
        problems.append((f"{dst_rel}/{name}",
                         f"{dst_rel}/{name} has no counterpart in {src_rel}/ — this copy is "
                         f"rendered from the templates, so add the script there instead"))
    for name in sorted(expected & present):
        if normalised(src / name) != normalised(dst / name):
            problems.append((f"{dst_rel}/{name}",
                             f"{dst_rel}/{name} differs from {src_rel}/{name} — refresh it from "
                             f"the template rather than editing it here"))
    return problems


def run(root: pathlib.Path, mirrors: list | None = None) -> list[tuple[str, str]]:
    """Check every configured mirror. `mirrors` is injectable so the selftest need not
    mutate the module global."""
    problems = []
    for src_rel, dst_rel, globs, exempt in (MIRRORS if mirrors is None else mirrors):
        problems += check_mirror(root, src_rel, dst_rel, globs, exempt)
    return problems


def selftest() -> int:
    """Verify each drift shape is reported and a clean mirror stays quiet."""
    failed = 0

    def expect(condition: bool, what: str) -> None:
        nonlocal failed
        if not condition:
            print(f"::error::selftest: {what}")
            failed = 1

    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        src, dst = root / "templates/.aiflow", root / ".aiflow"
        src.mkdir(parents=True)
        dst.mkdir(parents=True)
        for d in (src, dst):
            (d / "same.sh").write_text("echo hi\n", encoding="utf-8")
        (src / "missing.sh").write_text("echo gone\n", encoding="utf-8")
        (src / "drifted.sh").write_text("echo new\n", encoding="utf-8")
        (dst / "drifted.sh").write_text("echo old\n", encoding="utf-8")
        (dst / "handmade.sh").write_text("echo mine\n", encoding="utf-8")
        # line endings alone must not be reported
        (src / "eol.ps1").write_text("Write-Output hi\n", encoding="utf-8")
        (dst / "eol.ps1").write_bytes(b"Write-Output hi\r\n")
        # not a mechanical script: must be ignored even though it differs
        (src / "config.json").write_text("{}", encoding="utf-8")
        (dst / "config.json").write_text('{"local": true}', encoding="utf-8")

        found = {name: text for name, text in check_mirror(
            root, "templates/.aiflow", ".aiflow", ("*.sh", "*.ps1"))}
        expect(len(found) == 3, f"expected 3 problems, got {sorted(found)}")
        expect("is missing" in found.get(".aiflow/missing.sh", ""), "missing file not reported")
        expect("differs from" in found.get(".aiflow/drifted.sh", ""), "content drift not reported")
        expect("no counterpart" in found.get(".aiflow/handmade.sh", ""), "hand-added file not reported")
        expect(".aiflow/same.sh" not in found, "identical file reported")
        expect(".aiflow/eol.ps1" not in found, "line-ending-only difference reported")
        expect(".aiflow/config.json" not in found, "project state compared")

        # an exempted repo-only file must not count as "no counterpart"
        exempted = check_mirror(root, "templates/.aiflow", ".aiflow", ("*.sh", "*.ps1"),
                                frozenset({"handmade.sh"}))
        expect(not any("handmade.sh" in f for f, _ in exempted), "exemption not honoured")

        # a stale MIRRORS entry must fail loudly, never report a clean tree
        gone = check_mirror(root, "templates/nope", ".nope", ("*.sh",))
        expect(len(gone) == 1 and "MIRRORS expects it" in gone[0][1],
               f"missing mirror dir not reported: {gone}")

        # an exemption must hold even once the file exists on BOTH sides
        (src / "guard.py").write_text("x", encoding="utf-8")
        (dst / "guard.py").write_text("x", encoding="utf-8")
        both = check_mirror(root, "templates/.aiflow", ".aiflow", ("*.py",),
                            frozenset({"guard.py"}))
        expect(not both, f"exempted file reported once present on both sides: {both}")

        # run() wiring: tuple arity, and main()'s exit-code mapping
        one = [("templates/.aiflow", ".aiflow", ("*.sh", "*.ps1"), frozenset())]
        expect(len(run(root, one)) == 3, "run() disagrees with check_mirror")
        # swallow main()'s annotations: a ::error line from a PASSING selftest would
        # show up as a bogus failure annotation on the CI run
        with contextlib.redirect_stdout(io.StringIO()):
            rc = main([str(root)])
        expect(rc == 1, "main() did not exit non-zero on findings")

    print("selftest: mirror drift shapes" + (" — FAILED" if failed else " — ok"))
    return failed


def main(argv: list[str]) -> int:
    """Check a repo root (default: cwd) and annotate every finding."""
    if argv[:1] == ["--selftest"]:
        return selftest()
    root = pathlib.Path(argv[0] if argv else ".")
    problems = run(root)
    for where, problem in problems:
        print(f"::error file={where}::{problem}")
    print(f"rendered-copy check: {len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
