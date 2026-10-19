class Plankit < Formula
  desc "Plan-driven development toolkit for Claude Code"
  homepage "https://plankit.com/pk/"
  version "1.7.0"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/markwharton/plankit/releases/download/v#{version}/pk-darwin-arm64"
      sha256 "e1d533abcaf82dc627d467a5b8a7d2460273c997fab78635cee0977a4ce13a74"
    end
    on_intel do
      url "https://github.com/markwharton/plankit/releases/download/v#{version}/pk-darwin-amd64"
      sha256 "ec3f5757c246bb444cdb85e91d13e4824d33a1fbe1481ffbb44a17af7437f244"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/markwharton/plankit/releases/download/v#{version}/pk-linux-arm64"
      sha256 "5b6f128f5666c20b63e97f32a58ac25dd6f75646722cc1415ed8871ad2b31754"
    end
    on_intel do
      url "https://github.com/markwharton/plankit/releases/download/v#{version}/pk-linux-amd64"
      sha256 "cc2aacbe9292e8fcf8b37cc4f9dd0944989c26ccef768871bb732ec5ee0b4cbf"
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
