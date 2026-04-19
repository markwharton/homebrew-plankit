class McpBridge < Formula
  desc "Stdio-to-HTTP bridge for MCP servers. Single Go binary, zero dependencies"
  homepage "https://plankit.com/mcp-bridge/"
  version "0.1.0"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/markwharton/mcp-bridge/releases/download/v#{version}/mcp-bridge-darwin-arm64"
      sha256 "433caf649cbada8fb61d1de83592e44237b016fe0b9cde792df617de31e6fa2d"
    end
    on_intel do
      url "https://github.com/markwharton/mcp-bridge/releases/download/v#{version}/mcp-bridge-darwin-amd64"
      sha256 "59b8bc828c2f3fc403a7ddddca968592df5b737966f4a1f2e6ee4e84d4575a18"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/markwharton/mcp-bridge/releases/download/v#{version}/mcp-bridge-linux-arm64"
      sha256 "b35a0fe1e14a1afff42723d12b9dc6b8b6f1f392bfbb837c3a7e29f5e252b127"
    end
    on_intel do
      url "https://github.com/markwharton/mcp-bridge/releases/download/v#{version}/mcp-bridge-linux-amd64"
      sha256 "f87aede7cc1a9155e0fbf78d406581fc1b376eaf9b5d9ad4fa214dd9af6dd07e"
    end
  end

  def install
    bin.install Dir["mcp-bridge-*"].first => "mcp-bridge"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/mcp-bridge --version 2>&1")
  end
end
