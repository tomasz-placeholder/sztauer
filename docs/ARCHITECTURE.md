# Architektura — Sztauer

## Routing wewnątrz kontenera

```
port 420 (jedyny eksponowany)
├── /sztauer          → split-screen/index.html
├── /sztauer/editor   → code-server (wewnętrzny port)
├── /sztauer/terminal → ttyd (wewnętrzny port)
└── /*                → port aplikacji użytkownika (jeśli nasłuchuje) | placeholder
```

Wewnętrzny reverse proxy nasłuchuje na 420. Routuje `/sztauer*` do workspace. Wszystko inne → port aplikacji. Jeśli nic nie nasłuchuje → statyczny placeholder.

## Split screen: `/sztauer`

```
┌────────────────────────────┬────────────────────────────┐
│  code-server               │  ttyd                      │
│  --auth none               │  claude --dangerously-     │
│  --disable-getting-        │    skip-permissions        │
│    started-override        │                            │
│  workspace: ~/             │  thinking: max             │
│  pre-installed extensions  │  research: thorough        │
│  pre-configured settings   │  folder: ~/                │
│                            │                            │
└────────────────────────────┴────────────────────────────┘
              50%                         50%
```

HTML + CSS grid. Dwa iframe'y. Oba operują na `~` (katalog domowy).

## Autentykacja

Claude Max OAuth — nie ANTHROPIC_API_KEY.

1. Kontener startuje → ttyd uruchamia `claude --dangerously-skip-permissions`.
2. Claude CLI wyświetla link OAuth.
3. Użytkownik klika, loguje się w przeglądarce.
4. Token zapisany w `~/.claude/` → kolejne starty bez logowania.
5. Persystencja: named volume lub bind mount na `~/.claude/`.

## Entrypoint — sekwencja startowa

```
1. Firewall    → iptables default-deny + allowlista + ruch w sieci sztauer
2. Sieć        → docker network create sztauer (jeśli nie istnieje)
3. Proxy       → reverse proxy na porcie 420
4. code-server → wewnętrzny port, workspace = ~/
5. ttyd        → wewnętrzny port, uruchamia claude CLI
6. Workspace   → jeśli brak ~/CLAUDE.md → kopiuje z template
```

Fail-fast na brakujących zależnościach. Nie waliduje API key (bo go nie ma).

## Sieć `sztauer`

Każdy kontener dołącza do sieci `sztauer` (bridge, `--attachable`). Docker DNS umożliwia komunikację po nazwie kontenera:

```
┌─────────── sieć: sztauer ────────────┐
│                                       │
│  myapp ←→ backend ←→ database         │
│  curl http://backend:3000             │
│                                       │
└───────────────────────────────────────┘
```

Entrypoint tworzy sieć jeśli nie istnieje: `docker network create sztauer 2>/dev/null || true`

## Port aplikacji: `/`

Root (`localhost:420`) jest wolny. Reverse proxy sprawdza wewnętrzny port aplikacji. Jeśli nasłuchuje → proxy. Jeśli nie → placeholder ("Twoja aplikacja tu się pojawi").

Claude Code stawia `python3 -m http.server 3000` → natychmiast widoczne pod `localhost:420`.

## Domyślny CLAUDE.md (w instancji)

`workspace-template/CLAUDE.md` kopiowany do `~/` przy pierwszym starcie (nie nadpisuje istniejącego). Zawiera:

- Lokalizacja: kontener Docker Sztauer, workspace = `~/`
- Narzędzia: node, python, git, build-essential
- Port aplikacji: wystawiasz na dowolnym porcie → widoczne pod `localhost:420`
- Sieć: `sztauer`, inne instancje dostępne po `--name` (np. `curl http://backend:3000`)
- Firewall: default-deny, allowlista. Ruch w sieci `sztauer` dozwolony.

## Obraz — strategia lekkości

Multi-stage build:
- **Stage 1 (builder):** pełny toolchain — kompilacja ttyd, instalacja code-server, build extensions
- **Stage 2 (final):** `debian:bookworm-slim` — kopiuje gotowe binarki, minimalne runtime deps

Claude Code: natywny installer (`curl -fsSL https://claude.ai/install.sh | bash`).
Znany risk: segfault na AMD64 Bookworm (issue #12044). Fallback: `npm install -g @anthropic-ai/claude-code`.

Node.js: instalowany osobno (nodesource) — potrzebny dla code-server i projektów użytkownika, nie jako zależność Claude Code.

## Multi-machine

Ten sam obraz (multi-arch). Ta sama komenda. Logowanie na każdej maszynie raz. Token w volume.

## Niezmienniki

1. `docker run -p 420:420 --network sztauer` — zero plików, zero env vars.
2. `/sztauer` = workspace. `/` = aplikacja. Nigdy odwrotnie.
3. Firewall default-deny. Ruch w sieci `sztauer` dozwolony.
4. Claude Code: dangerous mode, max effort/thinking.
5. Kontener nie modyfikuje plików poza `~/` i swoimi volumes.
6. Każdy kontener w sieci `sztauer`.
