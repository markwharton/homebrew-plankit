class Pk < Formula
  desc "Plan-driven development toolkit for Claude Code"
  homepage "https://plankit.com/pk/"
  version "0.24.0"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/markwharton/plankit/releases/download/v#{version}/pk-darwin-arm64"
      sha256 "0697303668e48f00f4bdfc3a452c2657689d21e0cf60570a1a79b240633a2177"
    end
    on_intel do
      url "https://github.com/markwharton/plankit/releases/download/v#{version}/pk-darwin-amd64"
      sha256 "aa104ff6e143bce87e8593829b776ecfd80d3e8578f1f8df530ac5c6504792bd"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/markwharton/plankit/releases/download/v#{version}/pk-linux-arm64"
      sha256 "6eb1078ba30b716486e844f00c0fa20c99d959fcfd630b400918a6adaf426daa"
    end
    on_intel do
      url "https://github.com/markwharton/plankit/releases/download/v#{version}/pk-linux-amd64"
      sha256 "c5c849c33cac8e27506492eaf0b52ab6d52c143e2f69dfc430cc1a338320c739"
    end
  end

  def install
    bin.install Dir["pk-*"].first => "pk"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/pk --version 2>&1")
  end
end
