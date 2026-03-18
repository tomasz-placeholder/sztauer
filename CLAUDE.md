# Sztauer

Gotowy obraz Docker dla Claude Code. Jedna komenda:

```bash
docker run -d -p 420:420 --network sztauer --name myapp sztauer
```

`localhost:420/sztauer` → split screen: VS Code + Claude Code CLI. `localhost:420` → Twoja aplikacja.

Zero plików, zero kluczy API. Logowanie przez Claude Max przy pierwszym uruchomieniu.

## Styl kodu

- Shell: `set -euo pipefail`. ShellCheck czysto.
- YAML compose: 2 spacje, bez tabulatorów.
- Dockerfile: multi-stage jeśli zmniejsza obraz. Jawne wersje.
- HTML: vanilla, zero frameworków. CSS grid dla layoutu.
- Komentarze: wyłącznie "dlaczego", nie "co".

## Testowanie

Projekt rośnie do dużych rozmiarów — testowanie od pierwszego commita, nie jako afterthought.

**Narzędzia (zainstalowane w CI):**
- **Hadolint** — lint Dockerfile
- **ShellCheck** — lint shell scripts
- **bats-core** — unit testy bash (entrypoint, firewall, workspace init)
- **container-structure-test** (Google) — weryfikacja obrazu: pakiety, ścieżki, uprawnienia, porty
- **Trivy** — security scan obrazu (CVE)
- **Playwright** — E2E testy UI (split screen, routing, WebSocket)
- **curl + jq** — integration testy HTTP (routing, healthcheck, firewall)

**Zasady:**
- Każdy commit przechodzi: hadolint + shellcheck + bats + container-structure-test
- Każda faza ma swoje testy akceptacyjne (patrz @docs/SPEC.md)
- Testy sieciowe spinują ≥2 kontenery i weryfikują komunikację
- Testy firewalla: pozytywne (allowlista) i negatywne (reszta zablokowana)
- E2E testy UI: uruchamiane po buildzie obrazu, headless Playwright
- Security scan: Trivy na każdym buildzie, fail na CRITICAL CVE

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
- **Bazowy obraz:** debian:bookworm-slim — lekki. Claude Code przez natywny installer, Node osobno dla projektów użytkownika
- **Firewall:** iptables default-deny + allowlista. `cap_add: NET_ADMIN`
- **Port kontenera:** 420 (wewnętrzny i domyślny zewnętrzny)
- **Autentykacja:** Claude Max OAuth (token w `~/.claude/`)
- **Web terminal:** ttyd — mały binarny C, zero zależności runtime, xterm.js frontend
- **Dockerfile:** multi-stage build — build tools w pierwszym stage, lekki finalny obraz

## Decyzje do podjęcia w trakcie implementacji

- Reverse proxy wewnętrzny: Caddy, nginx — co najlżejsze dla routingu ścieżek
- Dynamiczny port aplikacji: jak wykrywać na jakim porcie nasłuchuje aplikacja użytkownika
- Lista pluginów VS Code do pre-install
- Lista ustawień VS Code (theme, font, etc.)
- Dokładna konfiguracja Claude Code CLI (flagi, env vars, settings.json)
- Natywny installer Claude Code: znany segfault na AMD64 Debian Bookworm (github.com/anthropics/claude-code/issues/12044). Fallback: npm install.

## Kontekst

- @docs/VISION.md — dlaczego ten projekt istnieje
- @docs/ARCHITECTURE.md — routing, split screen, auth, multi-machine
- @docs/SPEC.md — fazy z kryteriami akceptacji
- @docs/UI.md — docker run, split screen, port aplikacji
- @tasks.md — plan implementacji
