#!/usr/bin/env python3
"""Validate the YAML frontmatter of agent / command / skill markdown files.

Claude Code parses the frontmatter block of every `.claude/agents/*.md`,
`.claude/commands/*.md` (including namespaced subdirectories) and
`.claude/skills/*/SKILL.md`. A malformed block is not reported anywhere: an agent
with unparseable frontmatter is silently dropped from the roster, a command/skill
silently falls back to its body text. The classic trigger is an unquoted
description containing ": " — YAML then reads it as a nested mapping key and the
parse fails.

Usage: check-frontmatter.py <dir> [<dir> ...]
       check-frontmatter.py --selftest
Exits non-zero and prints GitHub-Actions error annotations on any finding.
"""

import pathlib
import re
import sys
import tempfile

import yaml

# `name` is not required for commands — Claude Code derives it from the filename.
# `description` is required everywhere: without it a command/skill degrades to its
# body text and stops matching the trigger words it was written for.
REQUIRED = {
    "agents": ("name", "description"),
    "commands": ("description",),
    "skills": ("name", "description"),
}

# Which files each kind of directory contributes. Skills recurse for SKILL.md only,
# so a skill's reference docs (which carry no frontmatter) are not false-flagged.
PATTERNS = {"agents": "*.md", "commands": "*.md", "skills": "SKILL.md"}

# Anthropic documents these limits for skill frontmatter. They are enforced for agents and
# commands too: the fields serve the same purpose everywhere, and an over-long description is
# the same silent degradation this guard exists for — it loads today and may be truncated
# tomorrow, taking the trigger words at the end with it.
MAX_LEN = {"name": 64, "description": 1024}

# A frontmatter block is fenced by a line that is exactly "---". Splitting on the
# bare string would also cut a valid description that happens to contain "---".
FENCE = re.compile(r"\A---[ \t]*\r?\n(.*?)(?:\r?\n)?---[ \t]*(?:\r?\n|\Z)", re.S)


def kind_of(path: pathlib.Path) -> str:
    """Classify a path as agents / commands / skills by its directory components.

    Matches the innermost component, so an absolute path whose ancestor happens to
    be named e.g. `agents/` does not misclassify what lies below it.
    """
    for part in reversed(path.parts):
        if part in PATTERNS:
            return part
    return "unknown"


def check(path: pathlib.Path) -> list[str]:
    """Return the frontmatter problems of one file — empty list means valid."""
    text = path.read_text(encoding="utf-8-sig")  # tolerate a BOM
    if not text.startswith("---"):
        return ["missing YAML frontmatter block"]
    match = FENCE.match(text)
    if not match:
        return ["unterminated YAML frontmatter block"]
    if not match.group(1).strip():
        return ["empty frontmatter block"]
    try:
        data = yaml.safe_load(match.group(1))
    except yaml.YAMLError as exc:
        first = str(exc).splitlines()[0]
        hint = ""
        if "mapping values are not allowed" in str(exc):
            hint = " (unquoted value containing ': '?)"
        return [f"invalid YAML frontmatter{hint}: {first}"]
    if not isinstance(data, dict):
        return ["frontmatter is not a mapping"]
    problems = []
    for key in REQUIRED.get(kind_of(path), ()):
        value = data.get(key)
        if not isinstance(value, str) or not value.strip():
            problems.append(f"missing or empty '{key}'")
    # Length is checked on whatever is present, not only on required keys: a command carrying
    # an over-long `name` is just as truncatable as an agent's.
    for key, limit in MAX_LEN.items():
        value = data.get(key)
        if isinstance(value, str) and len(value) > limit:
            problems.append(f"'{key}' is {len(value)} characters, limit is {limit}")
    return problems


def collect(roots: list[str]) -> list[pathlib.Path]:
    """Gather every frontmatter-carrying file below the given directories."""
    files: list[pathlib.Path] = []
    for root in roots:
        base = pathlib.Path(root)
        if not base.is_dir():
            continue
        files += sorted(base.rglob(PATTERNS.get(kind_of(base), "*.md")))
    return files


# Each fixture is (relative path, file body, expected-to-fail): the original
# unquoted-colon bug, a nested command, a valid description containing "---", a
# missing description, and every structural way a block can be malformed.
SELFTEST_FIXTURES = [
    ("agents/good.md", '---\nname: good\ndescription: "a: colon, quoted"\n---\nbody\n', False),
    ("agents/dashes.md", '---\nname: dashes\ndescription: "has --- dashes"\n---\nbody\n', False),
    ("commands/ok.md", '---\ndescription: plain description\n---\nbody\n', False),
    ("skills/s/SKILL.md", '---\nname: s\ndescription: plain\n---\nbody\n', False),
    ("agents/unquoted.md", "---\nname: bad\ndescription: two hats: architect\n---\nbody\n", True),
    ("commands/ns/nested.md", "---\ndescription: broken: value here\n---\nbody\n", True),
    ("commands/nodesc.md", "---\nargument-hint: <id>\n---\nbody\n", True),
    ("skills/t/SKILL.md", "---\nname: t\n---\nbody\n", True),
    ("agents/nofence.md", "no frontmatter at all\n", True),
    ("agents/unterminated.md", "---\nname: u\ndescription: never closed\n", True),
    ("agents/scalar.md", "---\njust a string\n---\nbody\n", True),
    ("agents/empty.md", "---\n---\nbody\n", True),
    # length limits: at the limit is fine, one over is not — for both fields
    ("skills/atlimit/SKILL.md",
     f"---\nname: {'n' * 64}\ndescription: {'d' * 1024}\n---\nbody\n", False),
    ("skills/longname/SKILL.md",
     f"---\nname: {'n' * 65}\ndescription: fine\n---\nbody\n", True),
    ("agents/longdesc.md",
     f"---\nname: longdesc\ndescription: {'d' * 1025}\n---\nbody\n", True),
]


def selftest() -> int:
    """Verify the guard accepts valid frontmatter and rejects each known failure."""
    failed = 0
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        for rel, body, _ in SELFTEST_FIXTURES:
            target = root / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(body, encoding="utf-8")
        for rel, _, should_fail in SELFTEST_FIXTURES:
            problems = check(root / rel)
            if bool(problems) != should_fail:
                want = "rejected" if should_fail else "accepted"
                print(f"::error::selftest: {rel} should have been {want}, got {problems}")
                failed = 1
        found = {p.relative_to(root).as_posix() for p in collect(
            [str(root / "agents"), str(root / "commands"), str(root / "skills")])}
        expected = {rel for rel, _, _ in SELFTEST_FIXTURES}
        if found != expected:
            print(f"::error::selftest: collect() missed {sorted(expected - found)} "
                  f"and picked up {sorted(found - expected)}")
            failed = 1
    print(f"selftest: {len(SELFTEST_FIXTURES)} fixtures" + (" — FAILED" if failed else " — ok"))
    return failed


def main(argv: list[str]) -> int:
    """Check every file below the argument directories; annotate and count problems."""
    if argv[:1] == ["--selftest"]:
        return selftest()
    files = collect(argv)
    if not files:
        print("::error::no frontmatter files found — wrong paths?")
        return 1
    failed = 0
    for path in files:
        for problem in check(path):
            print(f"::error file={path.as_posix()}::{problem}")
            failed = 1
    print(f"checked {len(files)} frontmatter files")
    return failed


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
