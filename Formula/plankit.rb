class Plankit < Formula
  desc "Plan-driven development toolkit for Claude Code"
  homepage "https://plankit.com/pk/"
  version "0.28.0"
  license "MIT"

  # homebrew/core ships an unrelated "pk" (field extractor) that also installs
  # a `pk` binary, so the two can't be linked at once. Named "plankit" to avoid
  # the bare-name collision; this makes the binary conflict explicit.
  conflicts_with "pk", because: "both install a `pk` binary"

  on_macos do
    on_arm do
      url "https://github.com/markwharton/plankit/releases/download/v#{version}/pk-darwin-arm64"
      sha256 "92e5a5b88ff6a8ff4390150ff0bf6ba0dfff95581d685024caef4ae037d9543a"
    end
    on_intel do
      url "https://github.com/markwharton/plankit/releases/download/v#{version}/pk-darwin-amd64"
      sha256 "a76d8a180defa30a4e7cfeae5f21f1af0765d96e13d5baffbe9ec70a9b8552ec"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/markwharton/plankit/releases/download/v#{version}/pk-linux-arm64"
      sha256 "d266ae5dec1cdff5f3019eb9d4570028db13d21992de086fa88cf9bab1bb8ca5"
    end
    on_intel do
      url "https://github.com/markwharton/plankit/releases/download/v#{version}/pk-linux-amd64"
      sha256 "7558b75edb1892d3b9378a31e9652a3d6c2ce06a376454f02730985b4164c0ba"
    end
  end

  def install
    bin.install Dir["pk-*"].first => "pk"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/pk --version 2>&1")
  end
end
