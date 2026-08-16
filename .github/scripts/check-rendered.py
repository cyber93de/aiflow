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

# `apply.sh`/`apply.ps1` stamp this line into exactly these five audit-only subagents when
# `modelRouting.enabled` is true (the default), and strip it again when it is false — the
# templates deliberately never carry it (aiflow-jxe). So the rendered copy here legitimately
# has one line the template does not, and comparing bytes would fail forever without this.
STAMPED_LINE = b"model: haiku\n"
STAMPED_FILES = frozenset({
    "docs-sync.md", "test-gap-advisor.md", "dependency-auditor.md",
    "performance-advisor.md", "onboarder.md",
})

# (template dir, rendered copy, globs, exempt). `exempt` names files in the RENDERED copy that
# legitimately have no template counterpart — add one only with a comment saying why. Globs are
# matched recursively, so `SKILL.md` reaches `skills/<name>/SKILL.md`, and files are compared by
# their path below the directory, not by bare name.
MIRRORS = [
    ("templates/.aiflow", ".aiflow", ("*.sh", "*.ps1"), frozenset()),
    ("templates/.claude/hooks", ".claude/hooks", ("*.sh", "*.ps1"), frozenset()),
    # the CI guards themselves are mechanically copied into a project by project-update;
    # these three deliberately stay repo-only. Two are about aiflow's own structure; the
    # exec-gate guard is generic shell hygiene, but the shell a project runs is aiflow's
    # own (`.aiflow/*.sh`, hooks) and is already checked here — shipping it would cost
    # every generated project a Python CI step for a class it cannot introduce.
    ("templates/.github/scripts", ".github/scripts", ("*.py",),
     frozenset({"check-twins.py", "check-rendered.py", "check-exec-gates.py"})),
    # CLAUDE.md requires .claude/ and templates/.claude/ to stay in sync — keeping them so is part
    # of shipping a template change, and until aiflow-5o3 nothing checked it.
    ("templates/.claude/agents", ".claude/agents", ("*.md",), frozenset()),
    ("templates/.claude/commands", ".claude/commands", ("*.md",), frozenset()),
    ("templates/.claude/skills", ".claude/skills", ("SKILL.md",), frozenset()),
]


def normalised(path: pathlib.Path, strip_stamp: bool = False) -> bytes:
    """File content with line endings flattened.

    `.gitattributes` pins `*.sh` to LF and `*.ps1` to CRLF, so both copies normally agree
    byte for byte — but a checkout with different settings must not fail the build over
    invisible characters. Real content drift survives this.
    """
    content = path.read_bytes().replace(b"\r\n", b"\n")
    if strip_stamp:
        content = content.replace(STAMPED_LINE, b"", 1)
    return content


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

    def below(base: pathlib.Path) -> set[str]:
        # rglob, and keyed by the path BELOW the directory: `skills/<name>/SKILL.md` needs the
        # subdirectory to be part of the identity, or every skill would collide on "SKILL.md".
        # exempt applies to BOTH sides: a repo-only script that later gains a template
        # counterpart must stay ignored, not flip into "missing from the rendered copy".
        found = {q.relative_to(base).as_posix() for g in globs for q in base.rglob(g)}
        return {rel for rel in found if rel not in exempt and rel.rsplit("/", 1)[-1] not in exempt}

    expected, present = below(src), below(dst)
    for name in sorted(expected - present):
        problems.append((f"{dst_rel}/{name}",
                         f"{dst_rel}/{name} is missing — copy it from {src_rel}/"))
    for name in sorted(present - expected):
        problems.append((f"{dst_rel}/{name}",
                         f"{dst_rel}/{name} has no counterpart in {src_rel}/ — this copy is "
                         f"rendered from the templates, so add the script there instead"))
    for name in sorted(expected & present):
        stamped = name.rsplit("/", 1)[-1] in STAMPED_FILES
        if normalised(src / name) != normalised(dst / name, strip_stamp=stamped):
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

    # nested identity + the stamped line, on their own tree
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        src, dst = root / "templates/.claude/skills", root / ".claude/skills"
        for base in (src, dst):
            (base / "alpha").mkdir(parents=True)
            (base / "beta").mkdir(parents=True)
            (base / "alpha/SKILL.md").write_text("alpha body\n", encoding="utf-8")
        # same basename, different subdirectory, different content: must be compared per skill
        (src / "beta/SKILL.md").write_text("beta body\n", encoding="utf-8")
        (dst / "beta/SKILL.md").write_text("beta CHANGED\n", encoding="utf-8")
        nested = check_mirror(root, "templates/.claude/skills", ".claude/skills", ("SKILL.md",))
        expect(len(nested) == 1 and "beta/SKILL.md" in nested[0][0],
               f"nested SKILL.md not compared per directory: {nested}")

        agents_src, agents_dst = root / "templates/.claude/agents", root / ".claude/agents"
        agents_src.mkdir(parents=True)
        agents_dst.mkdir(parents=True)
        body = "---\nname: x\n---\nbody\n"
        stamped_name = sorted(STAMPED_FILES)[0]
        (agents_src / stamped_name).write_text(body, encoding="utf-8")
        (agents_dst / stamped_name).write_text(
            body.replace("name: x\n", "name: x\nmodel: haiku\n"), encoding="utf-8")
        # the identical extra line on a NOT-stamped agent must still be reported
        (agents_src / "reviewer.md").write_text(body, encoding="utf-8")
        (agents_dst / "reviewer.md").write_text(
            body.replace("name: x\n", "name: x\nmodel: haiku\n"), encoding="utf-8")
        stamp = check_mirror(root, "templates/.claude/agents", ".claude/agents", ("*.md",))
        expect(len(stamp) == 1 and "reviewer.md" in stamp[0][0],
               f"stamp handling wrong — expected only reviewer.md: {stamp}")

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
