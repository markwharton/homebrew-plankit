class Plankit < Formula
  desc "Plan-driven development toolkit for Claude Code"
  homepage "https://plankit.com/pk/"
  version "1.10.0"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/markwharton/plankit/releases/download/v#{version}/pk-darwin-arm64"
      sha256 "badc5415ed42bbab5e47b47e66f7bf7d2c8a5967114737b0421817f5d80ab322"
    end
    on_intel do
      url "https://github.com/markwharton/plankit/releases/download/v#{version}/pk-darwin-amd64"
      sha256 "9ab50860a3e2bf5fc746ce1a98c334c646b71db4abfb94be1332e8d2b2ca0921"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/markwharton/plankit/releases/download/v#{version}/pk-linux-arm64"
      sha256 "a8f947c1049ecc618ba59bfedda340a6c1bf716c62f9454e705310f8936ae494"
    end
    on_intel do
      url "https://github.com/markwharton/plankit/releases/download/v#{version}/pk-linux-amd64"
      sha256 "a0817f578eac446280f77db913fb618479a5b75cb8d65b5f53af53ddf36cfd33"
    end
  end

  # homebrew/core ships an unrelated "pk" (field extractor) that also installs
  # a `pk` binary, so the two can't be linked at once. Named "plankit" to avoid
  # the bare-name collision; this makes the binary conflict explicit.
  conflicts_with "pk", because: "both install a `pk` binary"

  def install
    bin.install Dir["pk-*"].first => "pk"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/pk --version 2>&1")
  end
end
