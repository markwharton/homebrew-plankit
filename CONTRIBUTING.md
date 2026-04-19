# Contributing

Notes for maintaining the tap. Normal users don't need any of this — they just `brew tap markwharton/plankit` and `brew install`.

## Bumping a Formula

Each release of `pk` or `mcp-bridge` needs `version` and `sha256` lines updated in the relevant `Formula/*.rb`.

Fetch checksums from the tool's release:

```bash
curl -sL https://github.com/markwharton/plankit/releases/download/vX.Y.Z/checksums.txt
curl -sL https://github.com/markwharton/mcp-bridge/releases/download/vX.Y.Z/checksums.txt
```

Each line is `<sha256>  <filename>`. Substitute the hash for each platform into the Formula.

## Local testing (uncommitted Formulas)

`brew tap markwharton/plankit /path/to/homebrew-plankit` clones the repo — uncommitted Formula edits in your working tree won't be visible. To test against the live working tree, symlink instead:

```bash
mkdir -p /opt/homebrew/Library/Taps/markwharton
ln -s /Users/markwharton/Projects/markwharton/homebrew-plankit /opt/homebrew/Library/Taps/markwharton/homebrew-plankit
```

Then run the test loop:

```bash
brew install --build-from-source markwharton/plankit/pk
pk --version
brew test markwharton/plankit/pk
brew audit --new markwharton/plankit/pk

brew install --build-from-source markwharton/plankit/mcp-bridge
mcp-bridge --version
brew test markwharton/plankit/mcp-bridge
brew audit --new markwharton/plankit/mcp-bridge
```

Cleanup:

```bash
brew uninstall markwharton/plankit/pk markwharton/plankit/mcp-bridge
rm /opt/homebrew/Library/Taps/markwharton/homebrew-plankit
```

## Notes

- `pk --version` and `mcp-bridge --version` write to stderr — Formula test blocks use `2>&1` to redirect into `shell_output`.
- `brew audit --new` is worth passing before committing a new Formula or bump.
