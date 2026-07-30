# claude-sandbox

Run [Claude Code](https://claude.ai) in an isolated Docker container with your host config and environment.

## Quick Start

```bash
source claude-sandbox.sh
claude-sandbox --sandbox-env-settings ~/.claude/settings.json --dangerously-skip-permissions
```

## Features

- **Sandboxed** — Claude Code runs in a disposable Ubuntu container
- **Config injection** — Pass settings, credentials, skills, commands, agents, and hooks via in-memory tarball or bind mounts
- **Env passthrough** — `ANTHROPIC_*` and `CLAUDE_*` variables are forwarded automatically
- **Workspace** — Current directory is mounted at `/workspace`
- **Any args** — All non-flag arguments are forwarded to `claude` (e.g. `-v`, `--dangerously-skip-permissions`)

## Setup

See [SETUP.md](SETUP.md) for installation and configuration instructions.

## Usage

```bash
claude-sandbox [OPTIONS] [CLAUDE_ARGS...]
```

### Options

| Option | Description |
|--------|-------------|
| `--sandbox-env-settings PATH` | Inject settings.json via tarball |
| `--sandbox-env-credentials PATH` | Inject .credentials.json via tarball |
| `--sandbox-env-skills PATH` | Inject skills dir via tarball |
| `--sandbox-env-commands PATH` | Inject commands dir via tarball |
| `--sandbox-env-agents PATH` | Inject agents dir via tarball |
| `--sandbox-env-hooks PATH` | Inject hooks dir via tarball |
| `--sandbox-env-claude-dir PATH` | Inject entire ~/.claude dir via tarball |
| `--sandbox-mnt-settings PATH` | Mount settings.json (read-only) |
| `--sandbox-mnt-credentials PATH` | Mount .credentials.json (read-only) |
| `--sandbox-mnt-skills PATH` | Mount skills dir (read-only) |
| `--sandbox-mnt-commands PATH` | Mount commands dir (read-only) |
| `--sandbox-mnt-agents PATH` | Mount agents dir (read-only) |
| `--sandbox-mnt-hooks PATH` | Mount hooks dir (read-only) |
| `--sandbox-mnt-claude-dir PATH` | Mount entire ~/.claude dir (read-only) |

Mount and env options for the same resource are mutually exclusive.

### Examples

```bash
# Minimal — just pass settings
claude-sandbox --sandbox-env-settings ~/.claude/settings.json

# With credentials and skills
claude-sandbox \
  --sandbox-env-settings ~/.claude/settings.json \
  --sandbox-env-credentials ~/.claude/.credentials.json \
  --sandbox-env-skills ~/.claude/skills

# Mount config from host (read-only, no tarball)
claude-sandbox --sandbox-mnt-settings ~/.claude/settings.json

# Pass flags to claude
claude-sandbox --sandbox-env-settings ~/.claude/settings.json -v
```

## How It Works

1. The `claude-sandbox` shell function reads CLI options and builds a Docker run command
2. Config files are either serialized into a base64 tarball (`SANDBOX_CLAUDE_B64`) or mounted as volumes
3. `ANTHROPIC_*` and `CLAUDE_*` environment variables are forwarded to the container
4. The container entrypoint extracts the tarball into `~/.claude` (if present) and executes `claude`

## License

MIT
