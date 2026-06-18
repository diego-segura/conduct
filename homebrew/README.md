# Distributing `conduct` with Homebrew

Homebrew installs software from **formulae** (Ruby files). For a personal project you
publish them in your own **tap** — a public GitHub repo named `homebrew-<name>` (the
`homebrew-` prefix is required and dropped in commands). `homebrew/conduct.rb` here is
the production formula; copy it to `Formula/conduct.rb` in your tap repo.

## A. Publish for real

1. **Push `conduct` to GitHub**, e.g. `github.com/diego-segura/conduct`, and tag a release:
   ```sh
   git tag v0.1.0 && git push origin v0.1.0
   ```
2. **Get the release tarball's checksum** (GitHub auto-generates the tarball):
   ```sh
   curl -fsSL https://github.com/diego-segura/conduct/archive/refs/tags/v0.1.0.tar.gz | shasum -a 256
   ```
3. **Edit `conduct.rb`**: replace `diego-segura` (homepage + url) and paste the
   `sha256` from step 2.
4. **Create the tap repo** `github.com/diego-segura/homebrew-conduct`, put the formula at
   `Formula/conduct.rb`, and push.
5. **Users install with:**
   ```sh
   brew install diego-segura/conduct/conduct
   # equivalently: brew tap diego-segura/conduct && brew install conduct
   ```
6. **Releasing updates:** tag a new version, recompute the sha256, bump `url`/`sha256`
   in the tap's formula. Users get it via `brew upgrade`.

## B. Test locally before publishing

You don't need GitHub to test — point the formula at a **local tarball** and install
from a **local tap**. The repo ships a script that does the whole loop:

```sh
bash ~/conduct/homebrew/test-install.sh
```

It will:
1. build `conduct-<version>.tar.gz` from the working tree (with the `conduct-<version>/`
   prefix dir GitHub uses),
2. compute its sha256,
3. create a throwaway local tap and drop in a formula whose `url` is `file://…` with that sha,
4. `brew install` it, then run `brew audit --strict`, `brew style`, and `brew test`,
5. verify the installed binary (`conduct help`) and that it resolves `cities.txt` from the prefix,
6. uninstall and remove the throwaway tap.

This is exactly how Homebrew maintainers smoke-test a formula: a `file://` URL plus
`brew audit`/`brew test`. Nothing is published, and your manual `~/.local/bin/conduct`
install is left untouched (Homebrew installs into `$(brew --prefix)/bin`).

## Tap trust (recent Homebrew)

Homebrew now requires you to **trust** third-party taps before it will run their
formulae. After `brew tap`, users may need:

```sh
brew trust --formula diego-segura/conduct/conduct      # trust just this formula
# or:  brew trust diego-segura/conduct                  # trust the whole tap
```

(A locally created tap is auto-trusted, which is why the local test installs without a
prompt.) Mention this in your tap's README so users aren't surprised.

## Notes

- `uses_from_macos "git"` means: use the system git on macOS, depend on brew git only on
  Linux. Keeps installs light on Mac.
- The formula installs `conduct` + `cities.txt` into `libexec` and symlinks the script
  into `bin`. This matters: `conduct` finds `cities.txt` *relative to its own resolved
  path*, so the program asset travels inside the prefix while user data stays in
  `~/conduct` (`CONDUCT_HOME`).
- `caveats` detects a pre-existing manual install and warns — it never deletes it.
  Homebrew formulae must not touch files they didn't install.
