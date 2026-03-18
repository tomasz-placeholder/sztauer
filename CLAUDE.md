# Sztauer

Gotowy obraz Docker dla Claude Code. Jedna komenda:

```bash
docker run -d -p 420:420 --name myapp sztauer/sandbox
```

`localhost:420/sztauer` → split screen: VS Code + Claude Code CLI. `localhost:420` → Twoja aplikacja.

Zero plików, zero kluczy API. Logowanie przez Claude Max przy pierwszym uruchomieniu.

## Użycie

```bash
# Start:
docker run -d -p 420:420 --network sztauer --name myapp sztauer/sandbox

# Stop:
docker stop myapp

# Zniszcz:
docker rm -fv myapp
```

## Struktura repo (kod źródłowy obrazu)

```
Dockerfile                          — obraz: code-server + Claude Code + terminal + firewall + proxy
entrypoint.sh                       — start serwisów, inicjalizacja workspace
config/
├── code-server/
│   ├── settings.json               — VS Code settings (no welcome, theme, font)
│   └── extensions.txt              — pluginy do pre-install
├── claude/
│   └── settings.json               — Claude Code config (dangerous mode, max effort)
├── proxy/                          — reverse proxy: /sztauer → workspace, / → app
└── firewall/
    └── allowlist.txt               — dozwolone domeny
split-screen/
└── index.html                      — strona split screen: VS Code (50%) + terminal (50%)
workspace-template/
└── CLAUDE.md                       — domyślne instrukcje dla Claude Code w instancji
compose.yml                         — template: multi-project (opcjonalny)
compose.gpu.yml                     — override: GPU (opcjonalny)
infra.yml                           — template: subdomeny multi-project (opcjonalny)
.github/workflows/build.yml         — CI/CD: multi-arch build + push Docker Hub
docs/                               — VISION, ARCHITECTURE, SPEC, UI
```

## Styl kodu

- Shell: `set -euo pipefail`. ShellCheck czysto.
- YAML compose: 2 spacje, bez tabulatorów.
- Dockerfile: multi-stage jeśli zmniejsza obraz. Jawne wersje.
- HTML: vanilla, zero frameworków. CSS grid dla layoutu.
- Komentarze: wyłącznie "dlaczego", nie "co".

## Granice

**Zawsze:**
- `docker run -p 420:420 --network sztauer` bez env vars wystarczy do startu
- `/sztauer` = workspace (split screen). `/` = aplikacja użytkownika
- Każdy kontener w sieci `sztauer` — instancje widzą się po nazwie kontenera
- Claude Code w dangerous mode z max effort/thinking od startu
- VS Code bez welcome screen, z pre-installed pluginami
- Firewall default-deny z allowlistą. Ruch w sieci `sztauer` dozwolony.
- Domyślny CLAUDE.md w każdej nowej instancji (nie nadpisuj istniejącego)
- Obraz multi-arch (amd64 + arm64)

**Zapytaj:**
- Zmiana allowlisty firewalla
- Zmiana listy pre-installed pluginów VS Code
- Zmiana domyślnych ustawień Claude Code
- Zmiana schematu routingu (ścieżki, porty)

**Nigdy:**
- ANTHROPIC_API_KEY jako wymagany env var — autentykacja przez Claude Max
- Docker socket montowany do kontenera
- `restart: always` na kontenerach projektów
- Hardkodowane sekrety w obrazie
- Custom CLI wrapper — interfejsem jest docker

## Podjęte decyzje techniczne

- **Edytor webowy:** code-server — VS Code w przeglądarce, `--auth none`
- **Bazowy obraz:** node:20-bookworm — Node.js wymagany przez Claude Code
- **Firewall:** iptables default-deny + allowlista. `cap_add: NET_ADMIN`
- **Port kontenera:** 420 (wewnętrzny i domyślny zewnętrzny)
- **Autentykacja:** Claude Max OAuth (token w `~/.claude/`)

## Decyzje do podjęcia w trakcie implementacji

- Web terminal: ttyd, xterm.js, gotty — co najprościej osadzić w iframe
- Reverse proxy wewnętrzny: Caddy, nginx — co najlżejsze dla routingu ścieżek
- Dynamiczny port aplikacji: jak wykrywać na jakim porcie nasłuchuje aplikacja użytkownika
- Lista pluginów VS Code do pre-install
- Lista ustawień VS Code (theme, font, etc.)
- Dokładna konfiguracja Claude Code CLI (flagi, env vars, settings.json)

## Kontekst

- @docs/VISION.md — dlaczego ten projekt istnieje
- @docs/ARCHITECTURE.md — routing, split screen, auth, multi-machine
- @docs/SPEC.md — fazy z kryteriami akceptacji
- @docs/UI.md — docker run, split screen, port aplikacji
- @tasks.md — plan implementacji
