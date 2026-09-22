# Contributing

Notes for maintaining the tap. Normal users don't need any of this — they just `brew tap markwharton/plankit` and `brew install`.

## Bumping a Formula

Each release of `pk` or `mcp-bridge` needs `version` and `sha256` lines updated in the relevant `Formula/*.rb`. The easy way:

```bash
ruby scripts/bump-formula.rb              # all formulas in formulas.yml
ruby scripts/bump-formula.rb mcp-bridge   # just one
```

CI runs the same script daily and, when upstream has a new release, tests and releases the result on its own (see Automation below). To do it by hand instead, fetch checksums from the tool's release:

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
brew install --build-from-source markwharton/plankit/plankit
pk --version
brew test markwharton/plankit/plankit
brew audit --new --except=version markwharton/plankit/plankit

brew install --build-from-source markwharton/plankit/mcp-bridge
mcp-bridge --version
brew test markwharton/plankit/mcp-bridge
brew audit --new --except=version markwharton/plankit/mcp-bridge
```

Cleanup:

```bash
brew uninstall markwharton/plankit/plankit markwharton/plankit/mcp-bridge
rm /opt/homebrew/Library/Taps/markwharton/homebrew-plankit
```

## Automation

`formulas.yml` registers every formula CI tracks (formula name, upstream repo, asset prefix). Two workflows consume it:

- **`test-formulas.yml`** — runs `scripts/test-formula.sh <formula>` for every formula when `Formula/**` or the test tooling changes (push or PR), on one runner per release artifact: macOS arm64 (`macos-latest`), macOS Intel (`macos-15-intel`), Linux amd64 (`ubuntu-latest`), and Linux arm64 (`ubuntu-24.04-arm`) — every published binary actually gets executed. It is also a `workflow_call` with a `ref` input, which is how the bump workflow runs the same matrix on its candidate commit.
- **`bump-formulas.yml`** — daily (and on `repository_dispatch` type `bump-formula`, or manually from the Actions tab) carries an upstream release all the way to a tap release. Jobs, in order:
  1. `bump` (macOS): for each formula in `formulas.yml`, run `scripts/bump-formula.rb`; if the file changed, run `scripts/test-formula.sh` and commit `chore: bump <formula> to vX.Y.Z`. Push the result to `bump/run-<run_id>`. Nothing new → the run stops here, green.
  2. `test`: `test-formulas.yml` on that exact commit, all four platforms.
  3. `land`: fast-forward `main` to the tested commit via the Git refs API with `force=false`, so a human push to `main` in the meantime makes it refuse and nothing lands.
  4. `release`: check out `main`, fetch the linux-amd64 `pk` from the plankit release the formula now names, check it against the sha256 the formula records for it (the same line the bump copied from that release's `checksums.txt`), then `pk ship --dry-run` and `pk ship`. The tap releases itself with the exact `pk` it ships.
  5. `cleanup`: delete the branch (idempotent, so re-runs stay green).

Both scripts run locally too. `scripts/test-formula.sh` expects to own the tap symlink — it refuses to run while a real tap clone is installed (swap it out first, as in Local testing above), and it uninstalls the formula when done.

What fails where: a bad or missing checksum or a failing smoke test stops `bump`; a red platform stops `test`; either way `main` is untouched and the branch is removed. A `release` failure leaves the bump on `main` without a tag — "Re-run failed jobs" (`gh run rerun <id> --failed`) re-runs `release` alone and `pk ship` picks the pending commits up, or run `pk ship` by hand. A `test` failure is recovered by a fresh dispatch (or the next daily run), not by re-running, because the branch is gone.

Every push the workflow makes uses the default `GITHUB_TOKEN`, which GitHub never lets trigger another workflow. So the `push` trigger of `test-formulas.yml` fires only for human pushes, and nothing needs to listen for tags. `main` has no branch protection or rulesets; adding any would block `land` unless the token may bypass it. Two formulas bumping in the same run produce two commits and one release.

To re-verify the gate after touching the workflow, dispatch it with `break_checksum` set (`gh workflow run bump-formulas.yml -f break_checksum=true`): after the smoke test it overwrites every `sha256` in the bumped formula with zeros, so every platform's `brew install` must fail and nothing may land. It needs an actual bump to carry, so with every formula up to date it stops at `bump` like any other no-op run.

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

## Releasing

The tap uses trunk flow: one branch, `main`, and releases are cut where the work lands. There is no working branch and no merge step. Formula bumps are released by `bump-formulas.yml` itself (see Automation). To release other work by hand, on `main` with a clean tree run `pk changelog && pk release` (or `/plankit:ship` in Claude Code): `pk changelog` computes the version and writes the release commit, `pk release` tags HEAD and pushes `main` + tag atomically. `.pk.json` deliberately has no `release.branch` (its absence is what selects trunk flow) and no `guard.branches` (a branch guard on `main` would block every commit on the only branch).

### Merging Dependabot PRs

Always **squash-merge** Dependabot PRs, then rebase local work on top before shipping:

```bash
gh pr merge <number> --squash --delete-branch
git pull --rebase   # replays any unpushed local commits on top of the merge
pk changelog && pk release   # or /plankit:ship
```

Why squash: the PR title is a conventional commit (`chore(deps): bump …`), so a squash lands exactly one changelog-ready commit on `main`. A regular merge adds a non-conventional `Merge pull request #N` commit — `pk changelog` skips those, so mixing merge styles produces releases where some changes appear in the changelog and some don't. Formula bumps no longer arrive as PRs; they land on `main` directly.

## Adding a formula

1. Write `Formula/<name>.rb` (copy an existing one).
2. Register it in `formulas.yml` (formula name, upstream repo, asset prefix) so CI bumps and tests it.
3. Optional, for instant bumps: set the `TAP_DISPATCH_TOKEN` secret in the upstream repo and add the notify step to its release workflow (see Automation above). Without this the daily check still covers it.

## Notes

- `pk --version` and `mcp-bridge --version` write to stderr — Formula test blocks use `2>&1` to redirect into `shell_output`.
- `brew audit --new --except=version` is worth passing before committing a new Formula or bump. `--except=version` skips only the "version is redundant with version scanned from URL" check — the Formulas intentionally keep an explicit `version` that the platform URLs interpolate — while every other strict/new-formula audit still runs.
