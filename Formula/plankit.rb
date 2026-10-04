class Plankit < Formula
  desc "Plan-driven development toolkit for Claude Code"
  homepage "https://plankit.com/pk/"
  version "1.5.0"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/markwharton/plankit/releases/download/v#{version}/pk-darwin-arm64"
      sha256 "ba6bb83a3a59712188cddde4cde1833da21c7baf86fae1c73d04655292e654e7"
    end
    on_intel do
      url "https://github.com/markwharton/plankit/releases/download/v#{version}/pk-darwin-amd64"
      sha256 "bb5a20a81a33ce557c02cf402c78096be72bfadfc56f755cc8a5ba5f5bb36e1c"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/markwharton/plankit/releases/download/v#{version}/pk-linux-arm64"
      sha256 "447a45069b1c97d2986efa5efc4af1b0efc2fee8dc5871a14a2169c2cdd12a0a"
    end
    on_intel do
      url "https://github.com/markwharton/plankit/releases/download/v#{version}/pk-linux-amd64"
      sha256 "bcfff12a8f1ff1d8198d5798feb2e8a28be33d9aeba762f75ef021b27c65b709"
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
