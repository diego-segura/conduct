#!/usr/bin/env bash
#
# install.sh — put `conduct` on your PATH.
#
#   bash ~/conduct/install.sh
#
# Idempotent: safe to re-run. Symlinks the script into a bin dir and, if needed,
# adds that dir to your shell's PATH.
#
set -euo pipefail

SRC_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SRC_DIR/conduct"

[[ -f "$SRC" ]] || { echo "error: $SRC not found" >&2; exit 1; }
[[ -f "$SRC_DIR/cities.txt" ]] || { echo "error: $SRC_DIR/cities.txt not found" >&2; exit 1; }
chmod +x "$SRC"

# Choose a bin dir: prefer ~/.local/bin (no sudo). Use /usr/local/bin only if it
# already exists and is writable.
if [[ -w "/usr/local/bin" && -d "/usr/local/bin" && ! -d "$HOME/.local/bin" ]]; then
  BIN_DIR="/usr/local/bin"
else
  BIN_DIR="$HOME/.local/bin"
fi
mkdir -p "$BIN_DIR"

LINK="$BIN_DIR/conduct"
ln -sf "$SRC" "$LINK"
echo "✓ linked $LINK -> $SRC"

# Ensure BIN_DIR is on PATH, persisting to the right shell rc file.
ensure_path() {
  case ":$PATH:" in *":$BIN_DIR:"*) return 0;; esac   # already active

  local rc=""
  case "${SHELL##*/}" in
    zsh)  rc="$HOME/.zshrc" ;;
    bash) rc="$HOME/.bashrc"; [[ -f "$HOME/.bash_profile" ]] && rc="$HOME/.bash_profile" ;;
    *)    rc="$HOME/.profile" ;;
  esac

  local line="export PATH=\"$BIN_DIR:\$PATH\""
  if [[ -f "$rc" ]] && grep -qF "$BIN_DIR" "$rc"; then
    echo "• $BIN_DIR already referenced in $rc"
  else
    printf '\n# added by conduct installer\n%s\n' "$line" >> "$rc"
    echo "✓ added $BIN_DIR to PATH in $rc"
  fi
  echo "  → run:  source $rc    (or open a new terminal)"
}
ensure_path

echo
echo "Done. Try:  conduct help"
