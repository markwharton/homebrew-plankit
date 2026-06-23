#!/usr/bin/env bash
# Smoke-test a Formula from this working tree (the CONTRIBUTING.md loop):
# install --build-from-source -> --version -> brew test -> brew audit --new,
# then uninstall. Symlinks the working tree into Homebrew's taps dir so
# uncommitted Formula edits are visible; refuses to clobber an existing tap
# checkout that isn't that symlink.
#
# Usage: scripts/test-formula.sh <formula>
set -euo pipefail

formula="${1:?usage: scripts/test-formula.sh <formula>}"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"

# The installed command is the formula's asset_prefix, not the formula name:
# each formula does `bin.install Dir["<asset_prefix>-*"].first => "<asset_prefix>"`.
# They diverge for `plankit`, which installs the `pk` command.
command="$(FORMULA="$formula" ruby -ryaml -e '
  entry = YAML.load_file(ARGV[0]).fetch("formulas").find { |e| e["formula"] == ENV["FORMULA"] }
  abort "unknown formula: #{ENV["FORMULA"]}" unless entry
  print entry.fetch("asset_prefix")
' "$repo_root/formulas.yml")"

# GitHub's ubuntu runners ship without brew on PATH when installed fresh.
if ! command -v brew >/dev/null 2>&1; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

tap_dir="$(brew --repository)/Library/Taps/markwharton/homebrew-plankit"
if [ -e "$tap_dir" ] && [ "$(readlink "$tap_dir" || true)" != "$repo_root" ]; then
  echo "error: $tap_dir exists and is not a symlink to $repo_root" >&2
  echo "       (a real tap clone is installed — swap it out first, see CONTRIBUTING.md)" >&2
  exit 1
fi
mkdir -p "$(dirname "$tap_dir")"
[ -e "$tap_dir" ] || ln -s "$repo_root" "$tap_dir"

export HOMEBREW_NO_REQUIRE_TAP_TRUST=1
export HOMEBREW_NO_AUTO_UPDATE=1
export HOMEBREW_NO_INSTALL_CLEANUP=1
export HOMEBREW_NO_ENV_HINTS=1

# Downloads drop occasionally on CI runners (broken pipe mid-fetch) —
# retry the network-bound step; everything after it is local.
for attempt in 1 2 3; do
  if brew install --build-from-source "markwharton/plankit/$formula"; then
    break
  fi
  if [ "$attempt" -eq 3 ]; then
    echo "error: brew install failed after 3 attempts" >&2
    exit 1
  fi
  echo "brew install attempt $attempt failed; retrying in 10s..." >&2
  sleep 10
done
"$command" --version 2>&1
brew test "markwharton/plankit/$formula"
brew audit --new "markwharton/plankit/$formula"
brew uninstall "markwharton/plankit/$formula"
