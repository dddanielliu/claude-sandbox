# Setup

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) with Compose V2
- [Claude Code](https://claude.ai) installed on the host (for `~/.claude/settings.json`)

## Installation

### 1. Clone or copy the project

```bash
git clone <repo-url> ~/Others/programs/claude-sandbox
# or copy the files manually
```

### 2. Build the Docker image

```bash
cd ~/Others/programs/claude-sandbox
source claude-sandbox.sh
```

The image is built automatically on first run. To force a rebuild:

```bash
docker compose build claude-sandbox
```

### 3. Source the shell function

```bash
source ~/Others/programs/claude-sandbox/claude-sandbox.sh
```

Add to your `~/.zshrc` or `~/.bashrc` to make it permanent:

```bash
echo 'source ~/Others/programs/claude-sandbox/claude-sandbox.sh' >> ~/.zshrc
```

## Configuration

### settings.json

Create `~/.claude/settings.json` on your host. Example:

```json
{
  "model": "claude-sonnet-4-20250514",
  "attribution": {
    "commit": "",
    "pr": ""
  },
  "skipDangerousModePermissionPrompt": true
}
```

### Environment Variables

`ANTHROPIC_*` and `CLAUDE_*` variables are forwarded automatically. Common ones:

| Variable | Purpose |
|----------|---------|
| `ANTHROPIC_BASE_URL` | API base URL for providers |
| `ANTHROPIC_AUTH_TOKEN` | Authentication token |
| `ANTHROPIC_API_KEY` | API key |

### Full config directory

If you have a complete `~/.claude/` directory with settings, credentials, skills, commands, agents, and hooks, you can pass it all at once:

```bash
claude-sandbox --sandbox-env-claude-dir ~/.claude
```

Or mount it directly (slower but live-updates):

```bash
claude-sandbox --sandbox-mnt-claude-dir ~/.claude
```

## Usage

```bash
# Basic — with settings file
claude-sandbox --sandbox-env-settings ~/.claude/settings.json

# With credentials
claude-sandbox \
  --sandbox-env-settings ~/.claude/settings.json \
  --sandbox-env-credentials ~/.claude/.credentials.json

# Print version
claude-sandbox --sandbox-env-settings ~/.claude/settings.json -v

# Skip permission prompt
claude-sandbox --sandbox-env-settings ~/.claude/settings.json --dangerously-skip-permissions

# Inject entire .claude directory
claude-sandbox --sandbox-env-claude-dir ~/.claude
```

## Architecture

```
Host                          Docker Container
────                          ────────────────
claude-sandbox.sh  ───docker──▶  entrypoint.sh
  │                              │
  ├── Configs tar ──► b64 ──────▶├── Extract to ~/.claude
  ├── ENV vars ─────────────────▶├── Already set in env
  ├── cmd_args ─────────────────▶├── exec claude <args>
  └── . (cwd) ──────► /workspace └── Work directory
```
