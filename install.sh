#!/usr/bin/env bash
# Install aiflow on Linux/macOS/Git-Bash: symlink bin/aiflow onto PATH.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

DEST="${INSTALL_DIR:-}"
if [ -z "$DEST" ]; then
  if [ -w "/usr/local/bin" ]; then DEST="/usr/local/bin"; else DEST="$HOME/.local/bin"; fi
fi
mkdir -p "$DEST"
chmod +x "$HERE/bin/aiflow" "$HERE/lib/"*.sh "$HERE/templates/.aiflow/"*.sh "$HERE/templates/docker/"*.sh 2>/dev/null || true
ln -sf "$HERE/bin/aiflow" "$DEST/aiflow"
echo "linked $DEST/aiflow -> $HERE/bin/aiflow"
case ":$PATH:" in *":$DEST:"*) ;; *) echo "NOTE: add $DEST to PATH";; esac

# ---- optional prerequisites (ask once, at install time) ----
YES=0; for a in "$@"; do case "$a" in --yes|-y) YES=1;; esac; done
have() { command -v "$1" >/dev/null 2>&1; }
case "$(uname -s 2>/dev/null)" in Darwin) OS=macos;; Linux) OS=linux;; *) OS=other;; esac
TTY=/dev/tty; [ -r /dev/tty ] || TTY=/dev/stdin
ask_yn() { local p="$1" d="$2" a; if [ "$YES" = 1 ]; then a="$d"; else printf "  %s (y/n) [%s]: " "$p" "$d" >&2; read -r a <"$TTY" || a=""; a="${a:-$d}"; fi; case "$a" in [Yy]*) return 0;; *) return 1;; esac; }
pkg_install() { # pkg_install <brew-name> <apt-name>
  if [ "$OS" = macos ] && have brew; then brew install "$1";
  elif [ "$OS" = linux ]; then (sudo apt-get install -y "$2" || sudo dnf install -y "$2" || sudo pacman -S --noconfirm "$2") 2>/dev/null || echo "  ! install $2 manually";
  else echo "  ! install $1/$2 manually"; fi
}
echo
echo "Optional prerequisites (so 'aiflow init' later only asks which Ollama models to pull):"
if ! have git; then ask_yn "Install git?" y && pkg_install git git; else echo "  git already present"; fi
have svn || { ask_yn "Install Subversion (svn)?" n && pkg_install subversion subversion; }
if ! have ollama; then
  if ask_yn "Install Ollama (local models)?" n; then
    if [ "$OS" = macos ] && have brew; then brew install ollama; else curl -fsSL https://ollama.com/install.sh | sh || echo "  ! install ollama: https://ollama.com/download"; fi
  fi
else echo "  ollama already present"; fi

echo
echo "next:"
echo "  aiflow doctor              # see what's present"
echo "  aiflow install-deps --all  # install the rest of the toolchain"
echo "  aiflow init                # bootstrap a project (pick Ollama models, remote host + MCP, etc.)"
