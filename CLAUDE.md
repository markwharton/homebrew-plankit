# CLAUDE.md

IMPORTANT: Follow these rules at all times.

## Critical Rules

- NEVER take shortcuts without asking — STOP, ASK, WAIT for approval.
- NEVER force push — make a new commit to fix mistakes.
- NEVER commit secrets to version control.
- Only do what was asked — no scope creep.
- Understand existing code before changing it.
- If you don't know, say so — never guess.
- Test before and after every change.
- Surface errors clearly — no silent fallbacks.

## Project Conventions

### Project Type

- **Homebrew tap** providing two Formulas under `Formula/`:
  - `plankit.rb` — plan-driven development toolkit for Claude Code, installs the `pk` command (binaries from `markwharton/plankit` releases). Named `plankit`, not `pk`, because homebrew/core ships an unrelated `pk`.
  - `mcp-bridge.rb` — stdio-to-HTTP MCP bridge (binaries from `markwharton/mcp-bridge` releases)
- No build system — Formulas download prebuilt binaries for `darwin-arm64`, `darwin-amd64`, `linux-arm64`, `linux-amd64`.
- Tap is consumed as `brew tap markwharton/plankit` → `brew install markwharton/plankit/<formula>`.

### Bumping a Formula

- Preferred: `ruby scripts/bump-formula.rb [<formula>]` — updates `version` and the four `sha256` values from the latest upstream release (CI runs the same script daily; see CI/CD).
- Manual fallback: update both `version` and the four `sha256` values per Formula.
- Fetch checksums from the upstream release's `checksums.txt`:
  - `curl -sL https://github.com/markwharton/plankit/releases/download/vX.Y.Z/checksums.txt`
  - `curl -sL https://github.com/markwharton/mcp-bridge/releases/download/vX.Y.Z/checksums.txt`
- Each line is `<sha256>  <filename>` — map to the matching `on_macos`/`on_linux` × `on_arm`/`on_intel` block.

### Testing (Smoke)

- Symlink the working tree into Homebrew's taps dir (see CONTRIBUTING.md) so uncommitted Formula edits are visible.
- Per Formula, run: `brew install --build-from-source markwharton/plankit/<name>` → `<name> --version` → `brew test markwharton/plankit/<name>` → `brew audit --new --except=version markwharton/plankit/<name>`.
- `pk --version` and `mcp-bridge --version` write to **stderr** — Formula test blocks redirect with `2>&1` before `shell_output`.
- `brew audit --new --except=version` must pass before committing a new Formula or a bump. `--except=version` skips only the "version is redundant with version scanned from URL" check — the Formulas keep an explicit `version` that the four platform URLs interpolate (`v#{version}`), which newer Homebrew flags under `--strict` — while every other strict/new-formula audit still runs.
- Cleanup with `brew uninstall` and remove the symlink.

### Branch & Release Flow

- **Trunk flow:** one branch, `main`. Work lands on `main` and releases are cut there; there is no development branch and no merge step.
- **Release:** on `main`, `pk changelog && pk release` (or `/plankit:ship`) — `pk release` tags HEAD and pushes `main` + tag atomically. Formula bumps are released this way by `bump-formulas.yml` itself (see CI/CD); a human runs it only for other work on `main`.
- **`.pk.json`:** no `release.branch` (its absence selects trunk flow) and no `guard.branches` (a guard on `main` would block every commit). `pk status` shows an empty `release:` line; that is expected in trunk flow.
- **Dependabot PRs: always squash-merge** (`gh pr merge --squash --delete-branch`), then `git pull --rebase` before shipping. Squashing lands the PR's conventional-commit title as one commit so `pk changelog` picks it up; a regular merge commit is non-conventional and silently drops it from the changelog. There are no bump PRs any more — bumps land on `main` directly (see CI/CD).

### Commit Style

- Follow Conventional Commits (`feat:`, `fix:`, `chore:`, etc.) — matches existing history.
- `pk changelog` uses default commit types (no custom types configured).

### CI/CD

- `formulas.yml` is the registry of tracked formulas (formula name, upstream repo, asset prefix) — new formulas must be added there for CI to cover them.
- `.github/workflows/test-formulas.yml` — runs `scripts/test-formula.sh <formula>` (install → `--version` → `brew test` → `brew audit --new --except=version` → uninstall) for every registered formula on all four release platforms (macOS arm64 + Intel, Linux amd64 + arm64), for pushes/PRs touching `Formula/**` or the test tooling (`formulas.yml`, `scripts/`, the workflow itself). Also a `workflow_call` (input `ref`) so the bump workflow runs the same matrix on its candidate commit.
- `.github/workflows/bump-formulas.yml` — daily schedule, `repository_dispatch` (type `bump-formula`), or manual dispatch. One run carries an upstream release to a tap release with no human step: `bump` (serially per formula: `scripts/bump-formula.rb`, macOS smoke test, one `chore: bump <formula> to vX.Y.Z` commit each, pushed to `bump/run-<run_id>`) → `test` (the four-platform matrix on that exact commit) → `land` (fast-forward `main` to it through the refs API with `force=false`) → `release` (`pk ship` on `main`, using the linux-amd64 `pk` of the plankit release the tap now packages, verified against the sha256 the formula records) → `cleanup` (deletes the branch). Two formulas bumping in one run give two commits and one release.
- Failure semantics: anything before `land` fails leaves `main` untouched (bad or missing checksum, a failing smoke test, any platform red, or a human push to `main` in the meantime, which makes the fast-forward refuse). A `release` failure leaves the bump on `main` without a tag — recover with "Re-run failed jobs" (`gh run rerun <id> --failed`) or `pk ship` by hand. A test failure is recovered by a fresh dispatch (the branch is gone).
- Everything that workflow pushes uses `GITHUB_TOKEN`, which never triggers other workflows: the `push` trigger of `test-formulas.yml` fires only for human pushes, and nothing listens for tags. `main` has no branch protection or rulesets; adding any would block `land` unless the token may bypass it.
- `workflow_dispatch` input `break_checksum` zeros every sha256 of the bumped formula on the candidate commit (after the smoke test) so the four-platform gate must fail and nothing lands — the way to re-verify the gate after touching the workflow.
- Dependabot keeps GitHub Actions versions current (`.github/dependabot.yml`).
