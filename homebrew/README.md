# Distributing `conduct` with Homebrew

This repo is **its own Homebrew tap** — there is no separate `homebrew-conduct`
repo. The formula lives at [`Formula/conduct.rb`](../Formula/conduct.rb), which is one
of the directories Homebrew searches in a tap.

## Install (for users)

```sh
brew tap diego-segura/conduct https://github.com/diego-segura/conduct
brew install conduct
```

The explicit URL is required on the `tap` line because the repo is named `conduct`
rather than `homebrew-conduct` (the short `brew tap diego-segura/conduct` form only
works for repos with the `homebrew-` prefix). After tapping, `brew upgrade` works
normally. On recent Homebrew, users may also need to trust the tap:

```sh
brew trust --formula diego-segura/conduct/conduct   # or: brew trust diego-segura/conduct
```

> One-off alternative (no tap, no upgrade tracking):
> `brew install https://raw.githubusercontent.com/diego-segura/conduct/main/Formula/conduct.rb`

## Cutting a release (for the maintainer)

A formula needs a stable tarball + checksum, so each release is just a git tag:

1. **Tag and push:**
   ```sh
   git tag v0.1.0 && git push origin v0.1.0
   ```
2. **Get the tarball checksum** (GitHub auto-generates the tarball for the tag):
   ```sh
   curl -fsSL https://github.com/diego-segura/conduct/archive/refs/tags/v0.1.0.tar.gz | shasum -a 256
   ```
3. **Update `Formula/conduct.rb`**: set `url` to the new tag and paste the `sha256`.
   Commit + push to `main`. (Homebrew reads the formula from `main`, and downloads the
   tagged tarball named in `url` — they don't have to be the same commit.)

Users get the update via `brew upgrade conduct`.

## Test locally before tagging

You don't need GitHub to validate the formula — point `url` at a **local `file://`
tarball** and install from a **throwaway local tap**. The repo ships a script that does
the whole loop against `Formula/conduct.rb`:

```sh
bash ~/conduct/homebrew/test-install.sh
```

It builds a local tarball, generates a `file://` formula with the real sha, then runs
`brew style`, `brew audit --strict`, `brew install`, and `brew test`, verifies the
installed binary, and cleans up. Your manual `~/.local/bin/conduct` install is left
untouched (Homebrew installs into `$(brew --prefix)/bin`).

## Notes

- `uses_from_macos "git"` means: use the system git on macOS, depend on brew git only on
  Linux. Keeps installs light on Mac.
- The formula installs `conduct` + `cities.txt` into `libexec` and symlinks the script
  into `bin`. This matters: `conduct` finds `cities.txt` *relative to its own resolved
  path*, so the program asset travels inside the prefix while user data stays in
  `~/conduct` (`CONDUCT_HOME`).
- `caveats` detects a pre-existing manual install and warns — it never deletes it.
  Homebrew formulae must not touch files they didn't install.
