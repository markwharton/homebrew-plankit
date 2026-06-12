# Contributing

Notes for maintaining the tap. Normal users don't need any of this — they just `brew tap markwharton/plankit` and `brew install`.

## Bumping a Formula

Each release of `pk` or `mcp-bridge` needs `version` and `sha256` lines updated in the relevant `Formula/*.rb`. The easy way:

```bash
ruby scripts/bump-formula.rb              # all formulas in formulas.yml
ruby scripts/bump-formula.rb mcp-bridge   # just one
```

CI runs the same script daily and opens bump PRs (see Automation below). To do it by hand instead, fetch checksums from the tool's release:

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

## Automation

`formulas.yml` registers every formula CI tracks (formula name, upstream repo, asset prefix). Two workflows consume it:

- **`bump-formulas.yml`** — daily (and on `repository_dispatch` type `bump-formula`, or manually from the Actions tab) runs `scripts/bump-formula.rb` per formula; if upstream has a newer release it rewrites `version` + the four `sha256` values, smoke-tests on macOS, and opens a PR against `develop`.
- **`test-formulas.yml`** — runs `scripts/test-formula.sh <formula>` for every formula on macOS and Linux when `Formula/**` changes (push or PR).

Both scripts run locally too. `scripts/test-formula.sh` expects to own the tap symlink — it refuses to run while a real tap clone is installed (swap it out first, as in Local testing above), and it uninstalls the formula when done.

Auto-bump PRs are opened with the default `GITHUB_TOKEN`, which GitHub doesn't allow to trigger other workflows — the bump workflow smoke-tests before opening the PR, and the full two-OS test workflow runs when the merge pushes to `develop`. Scheduled and dispatch triggers fire from the default branch (`main`), so automation goes live once the workflows are released.

For instant bumps instead of the daily check, add a notify step at the end of an upstream repo's release workflow (requires a fine-grained PAT scoped to this repo with contents read/write, stored as `TAP_DISPATCH_TOKEN` in the upstream repo):

```yaml
- name: Notify Homebrew tap
  run: |
    curl -fsS -X POST \
      -H "Authorization: Bearer ${{ secrets.TAP_DISPATCH_TOKEN }}" \
      -H "Accept: application/vnd.github+json" \
      https://api.github.com/repos/markwharton/homebrew-plankit/dispatches \
      -d '{"event_type":"bump-formula"}'
```

## Adding a formula

Write `Formula/<name>.rb` (copy an existing one), then register it in `formulas.yml` so CI bumps and tests it.

## Notes

- `pk --version` and `mcp-bridge --version` write to stderr — Formula test blocks use `2>&1` to redirect into `shell_output`.
- `brew audit --new` is worth passing before committing a new Formula or bump.
