#!/usr/bin/env bash
#
# test-install.sh — end-to-end local test of the Homebrew formula, no GitHub needed.
#
# Builds a local release tarball, drops a file://-based formula into a throwaway tap,
# installs it, then runs `brew audit` / `brew style` / `brew test` and verifies the
# installed binary. Cleans up the tap and the install afterward. Your manual
# ~/.local/bin/conduct install is never touched.
#
set -uo pipefail
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_ENV_HINTS=1

VERSION="0.1.0"
TAP="local/conduct"                 # tap repo: homebrew-conduct under user "local"
FORMULA="local/conduct/conduct"
SRC="$HOME/conduct"
PROD_FORMULA="$SRC/Formula/conduct.rb"
TAP_DIR="$(brew --repository)/Library/Taps/local/homebrew-conduct"

PASS=0; FAIL=0
step() { printf '\n\033[1m========== %s ==========\033[0m\n' "$*"; }
check() { if [ "$1" = 0 ]; then echo "  ✓ $2"; PASS=$((PASS+1)); else echo "  ✗ $2"; FAIL=$((FAIL+1)); fi; }

cleanup() {
  step "cleanup"
  brew uninstall --force conduct >/dev/null 2>&1 && echo "  uninstalled conduct" || true
  brew untap "$TAP" >/dev/null 2>&1 && echo "  untapped $TAP" || true
  [ -n "${WORK:-}" ] && rm -rf "$WORK" && echo "  removed $WORK"
}
trap cleanup EXIT

# Start clean in case a previous run left things behind.
brew uninstall --force conduct >/dev/null 2>&1 || true
brew untap "$TAP" >/dev/null 2>&1 || true

step "1. build release tarball (mirrors GitHub's prefix dir)"
WORK="$(mktemp -d)"
STAGE="$WORK/conduct-$VERSION"
mkdir -p "$STAGE"
cp "$SRC/conduct" "$SRC/cities.txt" "$SRC/README.md" "$SRC/LICENSE" "$STAGE/"
TARBALL="$WORK/conduct-$VERSION.tar.gz"
tar -C "$WORK" -czf "$TARBALL" "conduct-$VERSION"
SHA="$(shasum -a 256 "$TARBALL" | awk '{print $1}')"
echo "  tarball: $TARBALL"
echo "  sha256:  $SHA"
[ -f "$TARBALL" ]; check $? "tarball built"

step "2. create throwaway tap"
brew tap-new "$TAP" --no-git >/dev/null 2>&1 || brew tap-new "$TAP" >/dev/null 2>&1
[ -d "$TAP_DIR/Formula" ]; check $? "tap created at $TAP_DIR"

step "3. generate file:// formula from the production formula"
# strip the leading comment block, then point url->file:// + insert the real sha
awk 'f||/^class /{f=1; print}' "$PROD_FORMULA" \
  | sed -e "s#^  url \".*\"#  url \"file://$TARBALL\"#" \
        -e "s#^  sha256 \".*\"#  sha256 \"$SHA\"#" \
  > "$TAP_DIR/Formula/conduct.rb"
echo "  --- generated formula head ---"
sed -n '1,8p' "$TAP_DIR/Formula/conduct.rb"
grep -q "file://$TARBALL" "$TAP_DIR/Formula/conduct.rb"; check $? "url rewritten to local tarball"
grep -q "$SHA" "$TAP_DIR/Formula/conduct.rb"; check $? "sha256 inserted"

step "4. brew style (rubocop)"
brew style "$FORMULA"; check $? "brew style clean"

step "5. brew audit --strict"
brew audit --strict "$FORMULA"; check $? "brew audit clean"

step "6. brew install"
brew install "$FORMULA"; check $? "brew install succeeded"

step "7. verify the installed binary"
BREW_BIN="$(brew --prefix)/bin/conduct"
[ -L "$BREW_BIN" ]; check $? "$BREW_BIN is a symlink"
echo "  -> $(readlink "$BREW_BIN")"
LINK_TARGET="$(readlink "$BREW_BIN")"
case "$LINK_TARGET" in */Cellar/conduct/*) check 0 "symlink points into the Cellar";; *) check 1 "symlink points into the Cellar";; esac
# run the brew-installed copy explicitly (bypass PATH ambiguity with the manual install)
out="$("$BREW_BIN" help 2>&1)"; echo "$out" | grep -q "isolated git worktrees"; check $? "'conduct help' runs from prefix"
# confirm it resolves cities.txt from libexec (prefix), not ~/conduct
[ -f "$(brew --prefix conduct)/libexec/cities.txt" ]; check $? "cities.txt shipped in prefix libexec"

step "8. brew test"
brew test "$FORMULA"; check $? "brew test passed"

step "9. confirm manual install untouched"
[ -L "$HOME/.local/bin/conduct" ]; check $? "~/.local/bin/conduct still present (not disturbed)"

step "SUMMARY"
echo "  PASS=$PASS  FAIL=$FAIL"
[ "$FAIL" = 0 ] && echo "  ALL GREEN" || echo "  SOME CHECKS FAILED"
exit "$FAIL"
