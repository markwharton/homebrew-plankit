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
  - `pk.rb` — plan-driven development toolkit for Claude Code (binaries from `markwharton/plankit` releases)
  - `mcp-bridge.rb` — stdio-to-HTTP MCP bridge (binaries from `markwharton/mcp-bridge` releases)
- No build system — Formulas download prebuilt binaries for `darwin-arm64`, `darwin-amd64`, `linux-arm64`, `linux-amd64`.
- Tap is consumed as `brew tap markwharton/plankit` → `brew install markwharton/plankit/<formula>`.

### Bumping a Formula

- Update both `version` and the four `sha256` values per Formula.
- Fetch checksums from the upstream release's `checksums.txt`:
  - `curl -sL https://github.com/markwharton/plankit/releases/download/vX.Y.Z/checksums.txt`
  - `curl -sL https://github.com/markwharton/mcp-bridge/releases/download/vX.Y.Z/checksums.txt`
- Each line is `<sha256>  <filename>` — map to the matching `on_macos`/`on_linux` × `on_arm`/`on_intel` block.

### Testing (Smoke)

- Symlink the working tree into Homebrew's taps dir (see CONTRIBUTING.md) so uncommitted Formula edits are visible.
- Per Formula, run: `brew install --build-from-source markwharton/plankit/<name>` → `<name> --version` → `brew test markwharton/plankit/<name>` → `brew audit --new markwharton/plankit/<name>`.
- `pk --version` and `mcp-bridge --version` write to **stderr** — Formula test blocks redirect with `2>&1` before `shell_output`.
- `brew audit --new` must pass before committing a new Formula or a bump.
- Cleanup with `brew uninstall` and remove the symlink.

### Branch & Release Flow

- **Development branch:** `develop`.
- **Protected branch:** `main` — `pk guard` blocks direct commits. Never commit directly to `main`.
- **Release:** `pk release` merges `develop` into `main` before pushing.

### Commit Style

- Follow Conventional Commits (`feat:`, `fix:`, `chore:`, etc.) — matches existing history.
- `pk changelog` uses default commit types (no custom types configured).

### CI/CD

- No `.github/workflows/` present — all verification is local via `brew install --build-from-source` + `brew test` + `brew audit --new`.
- No Dependabot configuration (no Actions to update).
