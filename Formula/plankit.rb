class Plankit < Formula
  desc "Plan-driven development toolkit for Claude Code"
  homepage "https://plankit.com/pk/"
  version "1.3.0"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/markwharton/plankit/releases/download/v#{version}/pk-darwin-arm64"
      sha256 "ae579b62dd3dea05c5a2cf42c889fcaa9ba9d82e7a886989bfa0f94fc740a345"
    end
    on_intel do
      url "https://github.com/markwharton/plankit/releases/download/v#{version}/pk-darwin-amd64"
      sha256 "03be2ea368cc9c11030ca935ad396d2b6b026145b5859aea39685a929e86e951"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/markwharton/plankit/releases/download/v#{version}/pk-linux-arm64"
      sha256 "d01b0be3a5aef66e846a72bfff677dfcb20a192d11f38e9b86484cbd53594b68"
    end
    on_intel do
      url "https://github.com/markwharton/plankit/releases/download/v#{version}/pk-linux-amd64"
      sha256 "9312b708afb07708c0c4035e7df4457421511444dbb110adba4c268a38581cf6"
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
