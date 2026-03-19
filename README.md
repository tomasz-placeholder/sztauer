# Sztauer

Docker image for Claude Code. One command, zero config.

```bash
docker run -d -p 420:420 --cap-add NET_ADMIN --network sztauer --name myapp sztauer/sztauer
```

Open [`localhost:420/sztauer`](http://localhost:420/sztauer). Done.

> **First run?** Create the network once: `docker network create sztauer`

## What you get

```
localhost:420/sztauer → split screen: VS Code + Claude Code CLI
localhost:420         → your app (whatever Claude builds)
```

```
┌─────────────────────────────┬─────────────────────────────┐
│  VS Code                    │  Claude Code CLI             │
│  - No welcome screen        │  - Dangerous mode            │
│  - Explorer: ~/             │  - Max thinking budget       │
│  - Pre-installed plugins    │  - Folder: ~/                │
│                             │                              │
└─────────────────────────────┴─────────────────────────────┘
         50%                           50%
```

Claude Code starts a server inside the container → it appears at `localhost:420` instantly.

## First run (< 2 minutes)

1. Run the `docker run` command above
2. Open `localhost:420/sztauer`
3. In the right panel, Claude Code shows a login link
4. Click → log in with your **Claude Max** account
5. Token saved — next starts skip login

No API key. No env vars. No config files.

## Persist your work

```bash
# Workspace
docker run -d -p 420:420 --cap-add NET_ADMIN --network sztauer \
  -v ~/myapp:/home/coder \
  --name myapp sztauer/sztauer

# Claude token only (survives container removal)
docker run -d -p 420:420 --cap-add NET_ADMIN --network sztauer \
  -v claude-token:/home/coder/.claude \
  --name myapp sztauer/sztauer

# Git credentials from host
docker run -d -p 420:420 --cap-add NET_ADMIN --network sztauer \
  -v ~/.gitconfig:/home/coder/.gitconfig:ro \
  -v ~/.ssh:/home/coder/.ssh:ro \
  --name myapp sztauer/sztauer
```

## Multi-project

Containers on the `sztauer` network see each other by name:

```bash
docker run -d -p 420:420 --cap-add NET_ADMIN --network sztauer --name frontend sztauer/sztauer
docker run -d -p 421:420 --cap-add NET_ADMIN --network sztauer --name backend sztauer/sztauer
# frontend can reach backend: curl http://backend:3000
```

## GPU

```bash
docker run -d -p 420:420 --cap-add NET_ADMIN --network sztauer --gpus all --name myapp sztauer/sztauer
```

## Manage

```bash
docker stop myapp       # pause
docker start myapp      # resume
docker rm -f myapp      # remove
docker rm -fv myapp     # remove + delete volumes
docker logs -f myapp    # tail logs
docker exec -it myapp bash  # shell into container
```

Or use Docker Desktop — play/stop/logs/shell in the GUI.

## Architecture

```
port 420 (only exposed port)
├── /sztauer          → split screen HTML (VS Code + Claude CLI)
├── /sztauer/editor   → code-server (VS Code in browser)
├── /sztauer/terminal → ttyd (web terminal running Claude Code)
└── /*                → app port 3000 inside container | placeholder
```

Internal reverse proxy (Caddy) on port 420. Routes `/sztauer*` to workspace services. Everything else → your app.

## Firewall

Outbound traffic is **default-deny**. Allowed destinations:

| Service | Domains |
|---------|---------|
| Anthropic | api.anthropic.com, claude.ai, auth.anthropic.com |
| GitHub | github.com, api.github.com, raw.githubusercontent.com |
| npm | registry.npmjs.org |
| PyPI | pypi.org, files.pythonhosted.org |

All traffic within the `sztauer` Docker network is allowed. Requires `--cap-add NET_ADMIN` (optional — container works without it, just no firewall).

## What's inside

| Tool | Version | Purpose |
|------|---------|---------|
| code-server | 4.96.4 | VS Code in browser |
| ttyd | 1.7.7 | Web terminal |
| Caddy | 2.9.1 | Reverse proxy |
| Claude Code | latest | AI coding assistant |
| Node.js | 22 LTS | Runtime |
| Python | 3 | Runtime |
| git, curl, jq, ripgrep, build-essential | — | Dev tools |

Base image: `debian:bookworm-slim`. Multi-arch: `amd64` + `arm64`.

## Requirements

- Docker
- Claude Max account (free tier won't work — OAuth login required)

## License

MIT
