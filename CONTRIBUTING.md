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
- **`test-formulas.yml`** — runs `scripts/test-formula.sh <formula>` for every formula when `Formula/**` or the test tooling changes (push or PR), on one runner per release artifact: macOS arm64 (`macos-latest`), macOS Intel (`macos-15-intel`), Linux amd64 (`ubuntu-latest`), and Linux arm64 (`ubuntu-24.04-arm`) — every published binary actually gets executed.

Both scripts run locally too. `scripts/test-formula.sh` expects to own the tap symlink — it refuses to run while a real tap clone is installed (swap it out first, as in Local testing above), and it uninstalls the formula when done.

Auto-bump PRs are opened with the default `GITHUB_TOKEN`, which GitHub doesn't allow to trigger other workflows — the bump workflow smoke-tests before opening the PR, and the full four-platform test workflow runs when the merge pushes to `develop`. Scheduled and dispatch triggers fire from the default branch (`main`), so automation goes live once the workflows are released.

For instant bumps instead of the daily check, upstream repos ping this repo on release. The pieces:

- **One shared fine-grained PAT** (`homebrew-plankit-dispatch`): repository access "Only select repositories" → this repo only; permissions Contents: Read and write. The token targets *this* repo, so adding a new upstream repo never requires changing the token. GitHub won't show the value again after creation — keep it in a password manager, or regenerate it and re-set the secret in every upstream repo when onboarding the next one.
- **The secret** in each upstream repo (prompts for the token; never put it on the command line or in a file):

  ```bash
  gh secret set TAP_DISPATCH_TOKEN --repo markwharton/<upstream-repo>
  ```

- **The notify step** at the end of the upstream release workflow's `release` job, after the GitHub release is created (`continue-on-error` so a failed ping never fails the release — the daily check is the fallback):

  ```yaml
  - name: Notify Homebrew tap
    continue-on-error: true
    run: |
      curl -fsS -X POST \
        -H "Authorization: Bearer ${{ secrets.TAP_DISPATCH_TOKEN }}" \
        -H "Accept: application/vnd.github+json" \
        https://api.github.com/repos/markwharton/homebrew-plankit/dispatches \
        -d '{"event_type":"bump-formula"}'
  ```

`plankit` and `mcp-bridge` are set up this way already.

### Merging bump PRs

Always **squash-merge** bump PRs (and Dependabot PRs), then rebase local work on top before shipping:

```bash
gh pr merge <number> --squash --delete-branch
git pull --rebase   # replays any unpushed local commits on top of the merge
pk changelog && pk release   # or /ship
```

Why squash: the PR title is a conventional commit (`chore: bump <formula> to vX.Y.Z`), so a squash lands exactly one changelog-ready commit on `develop`. A regular merge adds a non-conventional `Merge pull request #N` commit — `pk changelog` skips those, so mixing merge styles produces releases where some bumps appear in the changelog and some don't.

## Adding a formula

1. Write `Formula/<name>.rb` (copy an existing one).
2. Register it in `formulas.yml` (formula name, upstream repo, asset prefix) so CI bumps and tests it.
3. Optional, for instant bumps: set the `TAP_DISPATCH_TOKEN` secret in the upstream repo and add the notify step to its release workflow (see Automation above). Without this the daily check still covers it.

## Notes

- `pk --version` and `mcp-bridge --version` write to stderr — Formula test blocks use `2>&1` to redirect into `shell_output`.
- `brew audit --new` is worth passing before committing a new Formula or bump.
