class Pk < Formula
  desc "Plan-driven development toolkit for Claude Code"
  homepage "https://plankit.com/pk/"
  version "0.12.0"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/markwharton/plankit/releases/download/v#{version}/pk-darwin-arm64"
      sha256 "88c1bb71c1c1204fdac2c296b3a58d45636aded99fae07d1802b012468b96116"
    end
    on_intel do
      url "https://github.com/markwharton/plankit/releases/download/v#{version}/pk-darwin-amd64"
      sha256 "17fa14acdb72f2fe4d84c72a5856b1730a9b143c5ad3095a61cea82304871070"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/markwharton/plankit/releases/download/v#{version}/pk-linux-arm64"
      sha256 "f51d9376febf6e1869bcecbd1649e3462c6b4dbc70c5dcd4049b46e37b213534"
    end
    on_intel do
      url "https://github.com/markwharton/plankit/releases/download/v#{version}/pk-linux-amd64"
      sha256 "3eebc901d4e1f5d2e78a2959139efcfa9d1c500f468c046d4b473035c6dc6d48"
    end
  end

  def install
    bin.install Dir["pk-*"].first => "pk"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/pk --version 2>&1")
  end
end
