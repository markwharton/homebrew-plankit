# Automate the bump-to-release path in homebrew-plankit

## Context

Today an upstream release (plankit or mcp-bridge) reaches the tap automatically only as far as a PR. `bump-formulas.yml` bumps the formula, smoke-tests it on macOS arm64, and opens a PR with `GITHUB_TOKEN`. Because GitHub never starts workflows from events that token creates, the PR's "Test formulas" check never runs, and a person has to squash-merge, wait for the four-platform test on `main`, and run `pk ship`. For plankit v1.2.0 (2026-09-20) that was PR #19, then `chore: release v0.2.23`.

Goal: an upstream release ends with a tap release and nobody typing anything, and a failure on any platform lands nothing on `main`.

## Findings from the checks you asked for

- **Branch protection:** none. `gh api .../branches/main/protection` → 404 "Branch not protected"; `.../rulesets` → `[]`. A `GITHUB_TOKEN` with `contents: write` can push to `main`. (If protection is ever added, the land step needs a bypass; noted in docs.)
- **Two formulas in one run:** the matrix is the problem, not the fix. Recommendation: **drop the matrix and bump serially in one job**, one conventional commit per updated formula on one branch, one four-platform test of that branch (the test script already loops over every formula), one fast-forward, **one tap release per run**. The rare both-bump run costs ~1 extra minute of macOS smoke test and produces a changelog listing both bumps, which is what a human doing it by hand would produce.
- **`pk ship` in CI** (read from `internal/release/release.go`, `internal/changelog/changelog.go` in the local plankit v1.2.0 checkout). It needs:
  - a checked-out **branch** named `main` (not detached HEAD) — `actions/checkout` with `ref: main` gives that;
  - **full history and tags** — `pk changelog` lists `v*` tags locally and refuses with "no version tags found locally" on a shallow clone → `fetch-depth: 0`;
  - **git identity** for the `chore: release vX.Y.Z` commit → set `user.name`/`user.email` to `github-actions[bot]`;
  - `origin` reachable with credentials for `ls-remote --symref origin HEAD` (trunk-flow default-branch check), `ls-remote --heads`, `fetch`, and the final `git push --atomic origin main <tag>` → `actions/checkout`'s default `persist-credentials: true` plus `contents: write` covers all of it;
  - clean tree, HEAD not behind `origin/main` — true immediately after landing.
  - Nothing else: no `guard.branches`, no `release.branch`, no hooks in `.pk.json`. `pk ship --dry-run` first, then `pk ship`, exactly as you asked. When nothing is pending, `pk ship` prints "No new conventional commits found." and exits 0, so a rerun is harmless.
- **Tag push from `GITHUB_TOKEN`:** nothing here listens for tags, and nothing needs to. Note for the docs: `GITHUB_TOKEN` pushes never trigger workflows, so `test-formulas.yml`'s `push: main` trigger will *not* fire for the automated bump or release commits (it still fires for human pushes). That is fine because the same matrix already ran inside the bump run. Any future "react to a tag" behaviour has to live inside this workflow.
- **The failed PR check** you saw as `action_required` shows in the API as a run with `conclusion: failure` and zero jobs (run 35506909226): confirms it never executed.

## Recommendation: build the one-workflow design

Build your first option. Reasons over the PR + PAT + auto-merge alternative:

- **One token.** A fine-grained PAT expires unless deliberately set otherwise, and expiry fails silently at the worst time; the alternative needs it at *every* hop (PR creation, so the check runs; auto-merge push, so the release workflow runs). The first design uses only `GITHUB_TOKEN`.
- **One run to read.** bump → test → land → release is one run with one log. The alternative chains three workflows through GitHub events, plus branch protection and repo auto-merge settings that live outside the repo.
- **Same gate.** In-run test on the exact commit that lands gives the same guarantee the PR check was meant to give.

Cost to be honest about: no PR as a review surface (the run log and the conventional commits on `main` are the record), and a stranded state if the release half fails after landing (recovery below is one click).

## Design

Single workflow `.github/workflows/bump-formulas.yml` (file name kept — the upstream dispatch is by event type, and CLAUDE.md/CONTRIBUTING references stay stable; display name becomes "Bump and release formulas"). Triggers unchanged: schedule, `repository_dispatch: bump-formula`, `workflow_dispatch` (plus one dispatch input, below). `permissions: contents: write` only (`pull-requests: write` removed). `concurrency: bump-formulas, cancel-in-progress: false` unchanged — it serialises runs so two upstream releases minutes apart queue rather than race.

Jobs:

1. **bump** (`macos-latest`, so the smoke test can run as now). Checkout `main`; set git identity (`github-actions[bot]`). Loop over `formulas.yml` in file order; for each formula: `env -u GITHUB_OUTPUT ruby scripts/bump-formula.rb <f>` (unset so the script's per-call `updated=`/`version=` outputs don't pile up; `GITHUB_TOKEN` stays in env for the API rate limit, as today); if `git diff --quiet -- Formula/<f>.rb` shows a change: `scripts/test-formula.sh <f>` then `git commit -m "chore: bump <f> to v<version>"` (version read back from the formula's `version "…"` line, the same regex the bump script uses). No script changes: `bump-formula.rb` and `test-formula.sh` are used exactly as they are. If any commit was made: push `HEAD:refs/heads/bump/run-${{ github.run_id }}` and output `updated=true`, `sha=<HEAD>`. Otherwise `updated=false` and the rest of the run is skipped (daily no-op stays green, as today).
   - A bump-script failure (missing release, missing asset, malformed `checksums.txt`) fails this job → nothing is pushed anywhere.
2. **test** (`needs: bump`, `if: needs.bump.outputs.updated == 'true'`): `uses: ./.github/workflows/test-formulas.yml` with `ref: ${{ needs.bump.outputs.sha }}`. The SHA, not the branch name, so what was tested is exactly what lands.
3. **land** (`needs: [bump, test]`, `ubuntu-latest`, no checkout): server-side fast-forward of `main` to the tested SHA via the Git refs API: `gh api -X PATCH repos/<repo>/git/refs/heads/main -f sha=<sha> -F force=false` with `GH_TOKEN: ${{ github.token }}`. `force=false` makes GitHub refuse anything that is not a fast-forward, so if a human pushed to `main` between bump and land the call fails, nothing lands, and the next scheduled run redoes the bump on top of the new `main`. (A clone-and-push variant would need a checkout of the SHA, not of `main`; the API call needs no repo on disk.)
4. **release** (`needs: land`, `ubuntu-latest`): checkout `main` with `fetch-depth: 0` (all history and tags); set git identity; install `pk` (below); `pk ship --dry-run --plain` then `pk ship --plain`. `pk release` tags HEAD and pushes `main` + tag atomically, as it does from a laptop. A failure after the local changelog commit leaves nothing on origin, so a rerun starts clean.
   - **Getting `pk`:** read `version` and the `linux-amd64` `sha256` from `Formula/plankit.rb`; `curl` `pk-linux-amd64` from `github.com/markwharton/plankit/releases/download/v<version>/`; `sha256sum -c`; `chmod +x`. The formula's sha256 *is* the `checksums.txt` line the bump copied, so this is the same verification with no second fetch, and the tap releases itself with the exact `pk` it ships. Mismatch fails the job before anything is tagged.
5. **cleanup** (`needs: [bump, test, land, release]`, `if: !cancelled() && needs.bump.outputs.updated == 'true'`): delete `bump/run-<id>` if `git ls-remote --exit-code --heads` still finds it, else report "already gone". The idempotence matters: "Re-run failed jobs" re-runs dependents, so cleanup runs again after a `release`-only rerun. The branch is scratch; the test log and the commits on `main` are the record.

`test-formulas.yml` gains `on: workflow_call: inputs: ref: {type: string, required: false}` and its checkout step gets `ref: ${{ inputs.ref }}` (empty for push/PR/dispatch events, which keeps today's behaviour). Everything else in it is unchanged; `push: main` and `pull_request` triggers stay for human edits and Dependabot PRs.

**Failure semantics (what you asked for):**

| Failure | Result |
|---|---|
| bump script (bad/missing checksum, missing asset) | bump job red; no branch, nothing on main |
| macOS smoke in bump | bump job red; no branch |
| any of the four platforms in test | test red, land/release skipped; branch deleted; nothing on main |
| non-fast-forward at land (human pushed meanwhile) | land red; nothing on main; next run redoes it |
| `pk` download / sha mismatch, or `pk ship` pre-flight | release red; bump is on main, no tag |

Recovery for the last row only: "Re-run failed jobs" (`gh run rerun <id> --failed`) re-runs `release` (and cleanup); `pk ship` picks up the pending commits. Or a human runs `pk ship` as today. A *test* failure is not re-runnable that way (cleanup has deleted the branch); recover with a fresh dispatch, or wait for the daily run.

**Rehearsing the gate on demand:** one `workflow_dispatch` input, `break_checksum` (boolean, default false; step guarded by `if: inputs.break_checksum == true`, which is false/empty on schedule and dispatch events). When set, after the loop and the smoke test the bump job overwrites one `sha256` in the first bumped formula with 64 zeros (`ruby -i -pe`, since macOS `sed -i` differs; exactly 64 hex chars so Homebrew reports "SHA256 mismatch" rather than a formula parse error) in an extra commit `chore: rehearse the test gate (bad checksum)`. The four-platform test then fails on `brew install` (after the script's 3×10s retries), land is skipped, cleanup deletes the branch. It exists only on manual dispatch and is the documented way to re-verify the gate after touching the workflow. **Decision for you:** keep it (my recommendation, it is one guarded step) or remove it in a follow-up commit after the demonstration.

## Rehearsal plan (after the code lands on `main`)

With everything at v1.2.0 a dispatch finds nothing to bump and skips, which proves only the no-op path. To exercise the full path against the current release I propose one real, labelled commit on `main` that sets `Formula/plankit.rb` back to v1.1.0 (version + four sha256s from the v1.1.0 `checksums.txt`): `chore: rehearse automated bump (plankit back to v1.1.0)`. Then:

1. **Must-fail case first:** `gh workflow run bump-formulas.yml -f break_checksum=true`. Expect: bump green (smoke passes before the corruption), test red on all four platforms with SHA256 mismatch, land/release skipped, cleanup green, `main` unchanged (still v1.1.0), no `bump/run-*` branch left.
2. **Happy path:** `gh workflow run bump-formulas.yml`. Expect: bump → test (4 green) → land (`chore: bump plankit to v1.2.0` on main) → release. The release is cut by the workflow itself and contains the `ci:`/`docs:` commits of this work, the rehearsal commit, and the bump: one tap release (v0.2.24), proof that the path works end to end, no extra release just for the rehearsal.
3. Show both runs (`gh run view`), the resulting `main` log, tag, and CHANGELOG section.

**Decided (2026-09-22):** the v1.1.0 rehearsal commit is approved. It is the only way to demonstrate land+release now rather than at the next upstream release.

Known side effects of the rehearsal, so they are not surprises:

- **The tap advertises plankit 1.1.0** from the downgrade push until the happy-path land (two ~5-minute runs plus queueing). `brew install plankit` in that window installs 1.1.0. I will run the two dispatches back to back. If the daily cron (05:23 UTC) fired inside the window it would simply do the real bump itself; harmless.
- **v0.2.24's changelog** will list, under Maintenance: `automate bump-to-release in one workflow`, `describe the automated bump-to-release path` (under Documentation), `rehearse automated bump (plankit back to v1.1.0)`, and `bump plankit to v1.2.0`. CI runs plain `pk ship`, so nothing is excluded.
- **Extra `test-formulas.yml` runs:** the `ci:` commit (touches the workflow file, which is in its own `paths` filter) and the rehearsal commit (touches `Formula/**`) are human pushes, so each triggers a four-platform run. The second tests the v1.1.0 formula and should pass. Both are noise, not gates.
- The v1.1.0 `checksums.txt` is still published (verified: four platform lines present), so the downgrade is exact.

## Files

- `.github/workflows/bump-formulas.yml` — rewritten as described (jobs bump/test/land/release/cleanup; `peter-evans/create-pull-request` and `pull-requests: write` removed; `discover` job folded into `bump`).
- `.github/workflows/test-formulas.yml` — add `workflow_call` with `ref` input; checkout uses it.
- `CLAUDE.md` — Branch & Release Flow: bumps land and release automatically; the squash-merge rule now applies to Dependabot PRs only; `pk ship` by hand remains for human commits. CI/CD: describe the new job chain, the `GITHUB_TOKEN`-does-not-trigger note (push trigger covers human pushes only), the `break_checksum` rehearsal input, recovery via re-run failed jobs, and that `main` must stay unprotected (or get a bypass) for the land push.
- `CONTRIBUTING.md` — Automation: same, in more detail (how `pk` is obtained and verified, the branch naming, cleanup); Releasing: human `pk ship` is for non-bump work; "Merging bump PRs" becomes "Merging Dependabot PRs". PAT/dispatch section unchanged (still correct).
- No changes to `scripts/`, `formulas.yml`, `.pk.json`, or the upstream repos.

## Commit plan

Conventional commits on `main`, trunk flow, no release by hand:

1. `ci: automate bump-to-release in one workflow` (both workflow files).
2. `docs: describe the automated bump-to-release path` (CLAUDE.md, CONTRIBUTING.md).
3. `chore: rehearse automated bump (plankit back to v1.1.0)` — if approved.
4. Dispatch the must-fail run, then the happy-path run; the latter cuts the release.

The plan itself is preserved first: `/plankit:preserve` after approval (preserve mode is manual).

## Verification

- `actionlint` is not installed locally (checked); I will validate YAML with `ruby -ryaml` and rely on the dispatched runs. Say so if you want me to `brew install actionlint` first.
- The design was reviewed by a second pass for GitHub Actions semantics and the `pk` pre-flight code; its fixes are folded in above (API fast-forward for land, identity in both jobs, idempotent cleanup, `break_checksum` details, rehearsal side effects).
- Local: `pk ship --dry-run` already passes on this tree; `scripts/test-formula.sh plankit` locally before pushing the workflow (the tap symlink flow from CONTRIBUTING).
- CI: the two dispatched runs above are the end-to-end verification; success criteria are in the rehearsal section.
