#!/usr/bin/env bash
# Build the exact OS-scoped archives used by CI and the release workflow.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERSION="$(tr -d ' \t\r\n' < "$ROOT/VERSION")"
[[ "$VERSION" =~ ^[0-9A-Za-z.+-]+$ ]] || {
  echo "invalid VERSION: '$VERSION'" >&2
  exit 1
}
command -v zip >/dev/null 2>&1 || {
  echo "zip is required to build the Windows archive" >&2
  exit 1
}

OUT_DIR="${1:-dist/out}"
case "$OUT_DIR" in
  /*) ;;
  *) OUT_DIR="$ROOT/$OUT_DIR" ;;
esac
mkdir -p "$OUT_DIR"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/aiflow-package.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
STAGE="aiflow-$VERSION"

mkdir -p "$WORK/win/$STAGE/bin" "$WORK/win/$STAGE/lib"
cp "$ROOT/bin/aiflow.ps1" "$WORK/win/$STAGE/bin/"
cp "$ROOT"/lib/*.ps1 "$WORK/win/$STAGE/lib/"
cp "$ROOT/install.ps1" "$WORK/win/$STAGE/"
cp -r "$ROOT/README.md" "$ROOT/README.de.md" "$ROOT/LICENSE" "$ROOT/VERSION" \
  "$ROOT/release-workflows" "$ROOT/templates" "$WORK/win/$STAGE/"

mkdir -p "$WORK/posix/$STAGE/bin" "$WORK/posix/$STAGE/lib"
cp "$ROOT/bin/aiflow" "$WORK/posix/$STAGE/bin/"
cp "$ROOT"/lib/*.sh "$WORK/posix/$STAGE/lib/"
cp "$ROOT/install.sh" "$WORK/posix/$STAGE/"
cp -r "$ROOT/README.md" "$ROOT/README.de.md" "$ROOT/LICENSE" "$ROOT/VERSION" \
  "$ROOT/release-workflows" "$ROOT/templates" "$WORK/posix/$STAGE/"

tar -czf "$OUT_DIR/aiflow-$VERSION-linux.tar.gz" -C "$WORK/posix" "$STAGE"
tar -czf "$OUT_DIR/aiflow-$VERSION-macos.tar.gz" -C "$WORK/posix" "$STAGE"
(cd "$WORK/win" && zip -qr "$OUT_DIR/aiflow-$VERSION-windows.zip" "$STAGE")

(cd "$OUT_DIR" && sha256sum \
  "aiflow-$VERSION-linux.tar.gz" \
  "aiflow-$VERSION-macos.tar.gz" \
  "aiflow-$VERSION-windows.zip" > "aiflow-$VERSION-SHA256SUMS.txt")
tar -tzf "$OUT_DIR/aiflow-$VERSION-linux.tar.gz" >/dev/null
tar -tzf "$OUT_DIR/aiflow-$VERSION-macos.tar.gz" >/dev/null
zip -T "$OUT_DIR/aiflow-$VERSION-windows.zip" >/dev/null
ls -lh "$OUT_DIR"/aiflow-"$VERSION"-*
