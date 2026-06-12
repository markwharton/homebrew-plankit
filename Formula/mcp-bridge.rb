class McpBridge < Formula
  desc "Stdio-to-HTTP bridge for MCP servers. Single Go binary, zero dependencies"
  homepage "https://plankit.com/mcp-bridge/"
  version "0.2.0"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/markwharton/mcp-bridge/releases/download/v#{version}/mcp-bridge-darwin-arm64"
      sha256 "556758e71ed7fba5f00081c7960ec2d8cf809de479016fa9312eff238bc6dffd"
    end
    on_intel do
      url "https://github.com/markwharton/mcp-bridge/releases/download/v#{version}/mcp-bridge-darwin-amd64"
      sha256 "67aa9fe1e542fe6c5b065e001b1f622eece9c6ba145e0b23ef3d61c0f1193984"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/markwharton/mcp-bridge/releases/download/v#{version}/mcp-bridge-linux-arm64"
      sha256 "1c0383851f84471b9b0af9707f30b6ad0aa424f1276034006874afda3dd9573b"
    end
    on_intel do
      url "https://github.com/markwharton/mcp-bridge/releases/download/v#{version}/mcp-bridge-linux-amd64"
      sha256 "3d9f80d158bd01012ffb3871151476b072a4fc9e62e47c674a61ac3d64fb9a90"
    end
  end

  def install
    bin.install Dir["mcp-bridge-*"].first => "mcp-bridge"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/mcp-bridge --version 2>&1")
  end
end
