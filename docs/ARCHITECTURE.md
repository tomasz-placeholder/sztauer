# Architektura — Sztauer

## Zasada naczelna

Jedna komenda. Zero konfiguracji. Otwierasz przeglądarkę — masz gotowe środowisko pracy z Claude Code. Port główny wolny na Twoją aplikację.

## Routing wewnątrz kontenera

```
localhost:420
├── /sztauer          → split screen: VS Code + Claude Code CLI
├── /sztauer/editor   → code-server (wewnętrzny)
├── /sztauer/terminal → web terminal z Claude Code (wewnętrzny)
└── /                 → wolny — to co Claude Code postawi (app, API, dashboard)
```

Wewnętrzny reverse proxy (np. Caddy/nginx) nasłuchuje na porcie 420 i routuje:
- `/sztauer*` → workspace UI (split screen, code-server, terminal)
- Wszystko inne → port aplikacji wewnątrz kontenera (np. 3000, 5173, 8000 — konfigurowalne)

## Obraz

### Co zawiera

- **Claude Code CLI** — zainstalowany, skonfigurowany na dangerous mode + max effort/thinking
- **code-server** — VS Code w przeglądarce, bez welcome screen, pre-konfigurowany
- **Web terminal** — przeglądarkowy terminal z uruchomionym Claude Code
- **Firewall** — iptables default-deny, allowlista domen
- **Reverse proxy** — routing ścieżek wewnątrz kontenera
- **Narzędzia** — git, node, python, etc.
- **Domyślny CLAUDE.md** — instrukcje dla Claude Code o środowisku

### Autentykacja — Claude Max

Sztauer nie używa ANTHROPIC_API_KEY. Autentykacja przez Claude Max:

1. Użytkownik uruchamia kontener (`docker run`).
2. Otwiera `localhost:420/sztauer` — split screen.
3. W terminalu (prawa kolumna) Claude Code prosi o zalogowanie.
4. Użytkownik klika link, loguje się w przeglądarce.
5. Token zapisywany w volume → kolejne uruchomienia bez logowania.

Volume na token: `~/.claude/` wewnątrz kontenera → named volume lub bind mount.

### Entrypoint

Entrypoint startuje wszystkie serwisy:

1. **Firewall** — konfiguruje iptables z allowlistą.
2. **Reverse proxy** — startuje routing wewnętrzny.
3. **code-server** — startuje na wewnętrznym porcie, workspace = domowy katalog.
4. **Web terminal** — startuje na wewnętrznym porcie, uruchamia Claude Code CLI.
5. **Workspace init** — jeśli brak CLAUDE.md → tworzy domyślny z informacjami o środowisku.

Nie waliduje API key (bo go nie ma). Fail-fast tylko na brakujących zależnościach wewnętrznych.

## Split screen: `/sztauer`

```
┌─────────────────────────────────┬─────────────────────────────────┐
│                                 │                                 │
│  VS Code (code-server)          │  Claude Code CLI (web terminal) │
│                                 │                                 │
│  - Bez welcome screen           │  - Dangerous mode               │
│  - Folder: ~/                   │  - Max thinking budget          │
│  - Pre-installed plugins        │  - Max effort                   │
│  - Pre-configured settings      │  - Max research                 │
│  - Gotowy do pracy              │  - Folder: ~/                   │
│                                 │                                 │
└─────────────────────────────────┴─────────────────────────────────┘
         50%                                   50%
```

Strona HTML z CSS grid. Dwa iframe'y (lub embedy) obok siebie. Oba operują na tym samym katalogu domowym.

### code-server — konfiguracja

- `--auth none` — brak hasła (dostęp lokalny)
- `--disable-getting-started-override` — bez welcome
- Workspace: katalog domowy (`~`)
- Pre-installed extensions (lista w Dockerfile)
- Pre-configured `settings.json` (theme, font, minimap off, etc.)

### Web terminal — konfiguracja

- Terminal webowy (ttyd, xterm.js, lub podobny)
- Automatycznie uruchamia: `claude --dangerously-skip-permissions`
- Konfiguracja Claude Code:
  - Thinking budget: max
  - Research effort: max (thorough)
  - Verbose mode
- Folder roboczy: katalog domowy (`~`) — ten sam co code-server

## Port aplikacji

`localhost:420/` (root) jest wolny. Reverse proxy domyślnie proxuje root do wewnętrznego portu aplikacji (np. 3000). Gdy Claude Code postawi serwer — jest natychmiast widoczny.

Logika: reverse proxy sprawdza czy port aplikacji nasłuchuje. Jeśli tak → proxy. Jeśli nie → strona informacyjna ("Twoja aplikacja tu się pojawi").

## Domyślny CLAUDE.md

Każda nowa instancja dostaje `~/CLAUDE.md` z informacjami:

- Gdzie jesteś: kontener Docker Sztauer
- Twój workspace: `~/` (katalog domowy)
- Dostępne narzędzia: node, python, git, etc.
- Port aplikacji: wszystko co wystawisz na wewnętrznym porcie będzie widoczne pod `localhost:420`
- Firewall: default-deny, allowlista (lista domen)
- Persystencja: `/workspace` lub `~/` zamontowane jako volume

## Docker Desktop

- **Czytelna nazwa** — `--name myapp` → widoczne w Docker Desktop.
- **Healthcheck** — sprawdza czy code-server i terminal działają.
- **Logi** — przeglądalne przez GUI.
- **Play/Stop** — zarządzanie przez GUI. Token Claude Max persystowany.

## Multi-machine

```
                    ┌──────────────────┐
                    │  Docker Hub:     │
                    │  sztauer/sandbox │
                    └────────┬─────────┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
     ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
     │ Workstation   │ │ Laptop       │ │ RPi          │
     │               │ │              │ │              │
     │ docker run    │ │ docker run   │ │ docker run   │
     │ -p 420:420    │ │ -p 420:420   │ │ -p 420:420   │
     │               │ │              │ │              │
     │ Login raz     │ │ Login raz    │ │ Login raz    │
     │ Token w vol   │ │ Token w vol  │ │ Token w vol  │
     └──────────────┘ └──────────────┘ └──────────────┘
```

Ten sam obraz. Ta sama komenda. Logowanie przez przeglądarkę na każdej maszynie (raz). Token persystowany w Docker volume.

## Niezmienniki

1. `docker run -p 420:420` wystarczy do działającego środowiska — zero plików, zero env vars.
2. `/sztauer` to workspace. `/` to aplikacja użytkownika. Nigdy odwrotnie.
3. Firewall zawsze aktywny, default-deny.
4. Claude Code zawsze w dangerous mode z max effort/thinking.
5. Kontener nie modyfikuje plików poza workspace i swoimi volumes.
6. Obraz na Docker Hub — użytkownik nie buduje.

## Struktura repozytorium (kod źródłowy obrazu)

```
sztauer/
├── CLAUDE.md                       # konstytucja projektu
├── Dockerfile                      # obraz publikowany na Docker Hub
├── entrypoint.sh                   # start serwisów
├── workspace-template/
│   └── CLAUDE.md                   # domyślne instrukcje dla Claude Code
├── config/
│   ├── code-server/
│   │   ├── settings.json           # VS Code settings
│   │   └── extensions.txt          # lista pluginów do pre-install
│   ├── claude/
│   │   └── settings.json           # Claude Code config (dangerous, max effort)
│   ├── proxy/                      # reverse proxy config (routing ścieżek)
│   └── firewall/
│       └── allowlist.txt           # dozwolone domeny
├── split-screen/
│   └── index.html                  # strona split screen (/sztauer)
├── compose.yml                     # template: multi-project (opcjonalny)
├── compose.gpu.yml                 # override: GPU (opcjonalny)
├── infra.yml                       # template: reverse proxy multi-project (opcjonalny)
├── .github/workflows/build.yml     # CI/CD
├── docs/
│   ├── VISION.md
│   ├── ARCHITECTURE.md
│   ├── SPEC.md
│   └── UI.md
└── tasks.md
```
