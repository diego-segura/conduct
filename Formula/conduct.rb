# Homebrew formula for `conduct`.
#
# This repo is its own tap (no separate homebrew-conduct repo). Install with:
#   brew tap diego-segura/conduct https://github.com/diego-segura/conduct
#   brew install conduct
#
# When cutting a new release: tag it, then update `url` + `sha256` here, e.g.
#   curl -fsSL https://github.com/diego-segura/conduct/archive/refs/tags/v0.1.0.tar.gz | shasum -a 256
#
# See homebrew/README.md for the full release + local-testing workflow.
class Conduct < Formula
  desc "Run Claude Code or Codex in parallel git worktrees from the terminal"
  homepage "https://github.com/diego-segura/conduct"
  url "https://github.com/diego-segura/conduct/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "c49cf1ca1246fbb9aa369c36152082c7c231b75c92c93b28f312ea79897b0f21"
  license "MIT"

  # conduct shells out to git; on macOS the system git is fine, on Linux brew git.
  uses_from_macos "git"

  def install
    # Keep the script next to its data file so conduct's self-relative asset
    # lookup (SCRIPT_DIR/cities.txt) finds the city list inside the prefix.
    libexec.install "conduct", "cities.txt"
    bin.install_symlink libexec/"conduct"
  end

  def caveats
    s = <<~EOS
      conduct keeps its worktrees, logs, and state under ~/conduct
      (override with CONDUCT_HOME). Program assets live in the Homebrew prefix.

      Requires an agent CLI on your PATH: `claude` (Claude Code) and/or `codex`.
      Optional: `gh` (for `conduct finish`), `lsof` (better port detection).
    EOS
    if File.exist?("#{Dir.home}/.local/bin/conduct")
      s += <<~EOS

        NOTE: a manual install was found at ~/.local/bin/conduct. Homebrew installs
        into #{HOMEBREW_PREFIX}/bin, so both may be on your PATH. Remove the manual
        one to avoid ambiguity:
            rm ~/.local/bin/conduct
      EOS
    end
    s
  end

  test do
    assert_match "conduct", shell_output("#{bin}/conduct help")
    assert_path_exists libexec/"cities.txt"
  end
end
