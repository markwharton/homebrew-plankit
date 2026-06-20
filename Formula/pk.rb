class Pk < Formula
  desc "Plan-driven development toolkit for Claude Code"
  homepage "https://plankit.com/pk/"
  version "0.24.1"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/markwharton/plankit/releases/download/v#{version}/pk-darwin-arm64"
      sha256 "b5888d52ded4502a7e880cc6778b4457d326f9e9c7fd46c1d4e830fe0fc43cfc"
    end
    on_intel do
      url "https://github.com/markwharton/plankit/releases/download/v#{version}/pk-darwin-amd64"
      sha256 "db54ddd4b9213febd429147b709be6483d61c52f4333664492e27a49e245c1ba"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/markwharton/plankit/releases/download/v#{version}/pk-linux-arm64"
      sha256 "070e67cd23d5fa8fd216d388ac3a2440c4c59dbb343257c4aad7117ecf9670f6"
    end
    on_intel do
      url "https://github.com/markwharton/plankit/releases/download/v#{version}/pk-linux-amd64"
      sha256 "f555cfd9a8a24d211c25af4b696417abbc7363c2909ddf73c8bc83a25856501b"
    end
  end

  def install
    bin.install Dir["pk-*"].first => "pk"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/pk --version 2>&1")
  end
end
