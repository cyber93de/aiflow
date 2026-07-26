#!/usr/bin/env bash
# aiflow update - self-update the aiflow installation (AIFLOW_HOME) to the latest release.
#  - Git checkout (AIFLOW_HOME/.git exists): git pull --ff-only origin main.
#  - Archive install (no .git, e.g. installed from a downloaded release zip/tar.gz): checks the
#    GitHub Releases API for a newer version, downloads the matching per-OS archive, verifies it
#    against the published SHA256SUMS.txt, and installs it over AIFLOW_HOME.
# Only touches the aiflow install itself. For a single project's copied templates, see
# `aiflow project-update`.
set -uo pipefail

AIFLOW_HOME="${AIFLOW_HOME:-$(cd -P "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
GITHUB_REPO="cyber93de/aiflow"
OLD_VER="$(cat "$AIFLOW_HOME/VERSION" 2>/dev/null || echo 0.0.0)"

is_newer() { [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n1)" = "$1" ]; }
# --ssl-revoke-best-effort: Schannel (Windows curl) can fail TLS purely because a revocation
# check couldn't complete (common behind some corporate proxies/AV); this degrades that one
# check to best-effort instead of a hard failure. No-op on non-Schannel builds (Linux/macOS).
dl() { curl -fsSL --ssl-revoke-best-effort "$@"; }

if [ -d "$AIFLOW_HOME/.git" ]; then
  if [ -n "$(git -C "$AIFLOW_HOME" status --porcelain 2>/dev/null)" ]; then
    echo "aiflow install has local changes - refusing to update. Commit/stash in $AIFLOW_HOME first." >&2
    exit 1
  fi
  echo ">> updating aiflow ($AIFLOW_HOME, git checkout)..."
  git -C "$AIFLOW_HOME" fetch --tags origin >/dev/null 2>&1 || { echo "fetch failed" >&2; exit 1; }
  git -C "$AIFLOW_HOME" pull --ff-only origin main || { echo "update failed (not fast-forward?) - resolve manually in $AIFLOW_HOME" >&2; exit 1; }
  NEW_VER="$(cat "$AIFLOW_HOME/VERSION" 2>/dev/null || echo 0.0.0)"
else
  echo ">> checking latest release for $GITHUB_REPO (archive install: $AIFLOW_HOME)..."
  command -v curl >/dev/null 2>&1 || { echo "curl required to check/download releases" >&2; exit 1; }
  command -v jq   >/dev/null 2>&1 || { echo "jq required" >&2; exit 1; }

  REL_JSON="$(dl "https://api.github.com/repos/$GITHUB_REPO/releases/latest")" \
    || { echo "could not reach the GitHub releases API - check network/rate limits" >&2; exit 1; }
  LATEST_TAG="$(printf '%s' "$REL_JSON" | jq -r '.tag_name // empty')"
  [ -n "$LATEST_TAG" ] || { echo "no releases found for $GITHUB_REPO" >&2; exit 1; }
  LATEST_VER="${LATEST_TAG#v}"

  if ! is_newer "$LATEST_VER" "$OLD_VER"; then
    echo ">> already on latest (aiflow $OLD_VER)."
    exit 0
  fi

  case "$(uname -s 2>/dev/null)" in
    MINGW*|MSYS*|CYGWIN*) OSNAME=windows; EXT=zip ;;
    Darwin) OSNAME=macos; EXT=tar.gz ;;
    Linux)  OSNAME=linux; EXT=tar.gz ;;
    *) echo "unsupported OS for archive auto-update - download manually: https://github.com/$GITHUB_REPO/releases/tag/$LATEST_TAG" >&2; exit 1 ;;
  esac

  ASSET="aiflow-$LATEST_VER-$OSNAME.$EXT"
  SUMS="aiflow-$LATEST_VER-SHA256SUMS.txt"
  BASE_URL="https://github.com/$GITHUB_REPO/releases/download/$LATEST_TAG"
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT

  echo "   downloading $ASSET..."
  dl -o "$TMP/$ASSET" "$BASE_URL/$ASSET" || { echo "download failed: $BASE_URL/$ASSET" >&2; exit 1; }
  dl -o "$TMP/$SUMS"  "$BASE_URL/$SUMS"  || { echo "download failed: $BASE_URL/$SUMS" >&2; exit 1; }

  echo "   verifying checksum..."
  EXPECTED="$(grep " $ASSET\$" "$TMP/$SUMS" | awk '{print $1}')"
  [ -n "$EXPECTED" ] || { echo "no checksum entry for $ASSET in $SUMS" >&2; exit 1; }
  if command -v sha256sum >/dev/null 2>&1; then ACTUAL="$(sha256sum "$TMP/$ASSET" | awk '{print $1}')"
  else ACTUAL="$(shasum -a 256 "$TMP/$ASSET" | awk '{print $1}')"
  fi
  [ "$EXPECTED" = "$ACTUAL" ] || { echo "checksum mismatch for $ASSET (expected $EXPECTED, got $ACTUAL) - aborting" >&2; exit 1; }

  echo "   extracting..."
  mkdir -p "$TMP/extracted"
  case "$EXT" in
    zip)
      if command -v unzip >/dev/null 2>&1; then unzip -q "$TMP/$ASSET" -d "$TMP/extracted"
      else powershell -NoProfile -Command "Expand-Archive -Path '$TMP/$ASSET' -DestinationPath '$TMP/extracted' -Force" \
        || { echo "no unzip or powershell available to extract the archive" >&2; exit 1; }
      fi ;;
    tar.gz) tar -xzf "$TMP/$ASSET" -C "$TMP/extracted" ;;
  esac

  STAGE="$TMP/extracted/aiflow-$LATEST_VER"
  [ -d "$STAGE" ] || { echo "unexpected archive layout (no aiflow-$LATEST_VER/ directory)" >&2; exit 1; }

  echo "   installing into $AIFLOW_HOME..."
  cp -rf "$STAGE"/. "$AIFLOW_HOME"/
  chmod +x "$AIFLOW_HOME/bin/aiflow" "$AIFLOW_HOME/lib/"*.sh "$AIFLOW_HOME/templates/.aiflow/"*.sh \
    "$AIFLOW_HOME/templates/docker/"*.sh 2>/dev/null || true
  NEW_VER="$(cat "$AIFLOW_HOME/VERSION" 2>/dev/null || echo 0.0.0)"
fi

if [ "$OLD_VER" = "$NEW_VER" ]; then
  echo ">> already on latest (aiflow $NEW_VER)."
else
  echo ">> aiflow updated: $OLD_VER -> $NEW_VER"
  echo "   Run 'aiflow project-update' in each project to pull the new templates in."
fi
