class McpBridge < Formula
  desc "Stdio-to-HTTP bridge for MCP servers. Single Go binary, zero dependencies"
  homepage "https://plankit.com/mcp-bridge/"
  version "0.2.1"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/markwharton/mcp-bridge/releases/download/v#{version}/mcp-bridge-darwin-arm64"
      sha256 "0928382d504e0650cd9064e16157e5566ce5bf150546d939cfcd0d95f2815f4f"
    end
    on_intel do
      url "https://github.com/markwharton/mcp-bridge/releases/download/v#{version}/mcp-bridge-darwin-amd64"
      sha256 "5ec3c40653c69767b414ab98da524fe81176c64a1260ce0a47371358d747fd5d"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/markwharton/mcp-bridge/releases/download/v#{version}/mcp-bridge-linux-arm64"
      sha256 "715e433adf2373054179e0b32fddf40d850586a098d3b5ae81f9b28c1f5919d7"
    end
    on_intel do
      url "https://github.com/markwharton/mcp-bridge/releases/download/v#{version}/mcp-bridge-linux-amd64"
      sha256 "f81c11ad88cf51c27b3357cb09225fdaf6cdc13f6e6871076b2f22fcbfa77724"
    end
  end

  def install
    bin.install Dir["mcp-bridge-*"].first => "mcp-bridge"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/mcp-bridge --version 2>&1")
  end
end
