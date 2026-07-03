#!/usr/bin/env bash
# Version helper for the configured strategy (semver|calver). Reads/uses the VERSION file.
# Usage: version.sh current | release | next-dev [release-version]
set -uo pipefail
MODEL=".aiflow/branching.json"
STRAT="semver"
[ -f "$MODEL" ] && command -v jq >/dev/null 2>&1 && STRAT="$(jq -r '.release.versionStrategy // "semver"' "$MODEL")"
VER="$( [ -f VERSION ] && cat VERSION || echo "" )"

cmd="${1:-current}"; arg="${2:-}"

case "$STRAT" in
  calver)
    case "$cmd" in
      current)  echo "${VER:-$(date +%Y.%m)}" ;;
      release)  date +%Y.%m ;;                                  # current calendar version
      next-dev) base="${arg:-$(date +%Y.%m)}"; y="${base%%.*}"; m="${base##*.}"; m=$((10#$m + 1));
                if [ "$m" -gt 12 ]; then m=1; y=$((y+1)); fi; printf "%04d.%02d\n" "$y" "$m" ;;
    esac ;;
  *) # semver  X.Y.Z[-SNAPSHOT|-build.N]
    base="${VER:-0.1.0-SNAPSHOT}"; core="${base%%-*}"
    IFS=. read -r MA MI PA <<<"$core"; MA="${MA:-0}"; MI="${MI:-1}"; PA="${PA:-0}"
    case "$cmd" in
      current)  echo "$base" ;;
      release)  echo "${MA}.${MI}.${PA}" ;;                     # strip pre-release suffix
      next-dev) rel="${arg:-${MA}.${MI}.${PA}}"; IFS=. read -r a b c <<<"$rel";
                echo "${a}.$((b + 1)).0-SNAPSHOT" ;;            # MINOR+1, PATCH 0
    esac ;;
esac
