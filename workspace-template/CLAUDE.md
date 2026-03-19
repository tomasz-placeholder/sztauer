# Sztauer Workspace

You are running inside a Sztauer Docker container.

## Environment

- **Workspace:** `~/` (this directory)
- **OS:** Debian Bookworm
- **Tools:** node, npm, python3, pip, git, curl, wget, jq, ripgrep, build-essential
- **Editor:** code-server (VS Code) — left panel
- **Terminal:** this Claude Code CLI — right panel

## App Port

Start your app on port **3000**. The reverse proxy routes `localhost:420` → port 3000 inside this container.

Example: `python3 -m http.server 3000` → visible at `localhost:420`.

## Network

This container is on the `sztauer` Docker network. Other Sztauer instances are reachable by container name:

```bash
curl http://backend:3000/api/health
```

## Firewall

Outbound traffic is default-deny with an allowlist:
- Anthropic API (claude.ai, api.anthropic.com)
- GitHub (github.com, api.github.com)
- npm registry (registry.npmjs.org)
- PyPI (pypi.org)
- Traffic within the `sztauer` network is always allowed

## Constraints

- Do not try to access domains outside the allowlist — they are blocked.
- Do not modify firewall rules.
- Files outside `~/` are ephemeral — persist important data in `~/`.
