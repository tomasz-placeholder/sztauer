# Sztauer

Gotowy obraz Docker dla Claude Code. Podajesz klucz API, uruchamiasz kontener — dostajesz izolowane środowisko z edytorem webowym, firewallem i Claude Code CLI, dostępne w przeglądarce pod przewidywalną subdomeną.

Obraz publikowany na Docker Hub. Użytkownik nie klonuje repo — pobiera obraz i tworzy minimalny `compose.yml` + `.env`.

## Użycie

```bash
# Infrastruktura (raz):
docker compose -f infra.yml up -d

# Nowy projekt:
PROJECT_NAME=myapp docker compose up -d

# Stop:
PROJECT_NAME=myapp docker compose down

# Zniszcz (z volumes):
PROJECT_NAME=myapp docker compose down -v
```

## Struktura repo (kod źródłowy obrazu)

```
Dockerfile                      — obraz: code-server + Claude Code + iptables firewall
entrypoint.sh                   — walidacja env, firewall, git detection, start edytora
port-router.js                  — globalny HTTP/WS proxy: {name}-{port}.localhost → kontener
allowlist.txt                   — domeny dozwolone przez firewall
compose.yml                     — template dla użytkownika (parametryzowany PROJECT_NAME)
compose.gpu.yml                 — override: GPU passthrough
infra.yml                       — Caddy docker-proxy + port-router + sieć współdzielona
.env.example                    — wymagane zmienne środowiskowe
.github/workflows/build.yml     — CI/CD: multi-arch build + push Docker Hub
docs/                           — VISION, ARCHITECTURE, SPEC, UI
```

## Styl kodu

- Shell: `set -euo pipefail` na górze każdego skryptu. ShellCheck czysto.
- YAML compose: bez tabulatorów, 2 spacje. Serwisy w kolejności zależności.
- Dockerfile: multi-stage jeśli to zmniejsza obraz. Jawne wersje bazowych obrazów.
- Komentarze: wyłącznie "dlaczego", nie "co".

## Granice

**Zawsze:**
- Waliduj wymagane env vars w entrypoincie (fail-fast z czytelnym komunikatem)
- Auto-detection w entrypoincie: git, firewall, dostępne narzędzia — bez ręcznych flag
- Compose project name `sztauer-{nazwa}` — czytelne w Docker Desktop
- Volumes named z przewidywalnym prefixem `sztauer-{nazwa}-`
- Labele na kontenerach dla Docker Desktop, filtrowania i proxy discovery
- Sieć proxy jako external
- Obraz multi-arch (amd64 + arm64)

**Zapytaj:**
- Zmiana allowlisty firewalla
- Modyfikacja entrypointa
- Zmiana schematu subdomen
- Dodanie nowej zmiennej środowiskowej do interfejsu publicznego

**Nigdy:**
- Docker socket montowany do kontenera projektu
- `restart: always` na kontenerach projektów (tylko na infrastrukturze)
- Hardkodowane sekrety w Dockerfile lub compose
- Custom CLI wrapper — interfejsem jest `docker compose`
- Build wymagany od użytkownika — obraz gotowy na Docker Hub

## Podjęte decyzje techniczne

- **Edytor webowy:** code-server (port 8080) — prosty install, VS Code w przeglądarce
- **Reverse proxy:** Caddy z caddy-docker-proxy — autodiscovery przez Docker labele, zero konfiguracji
- **Bazowy obraz:** node:20-bookworm — Node.js wymagany przez Claude Code
- **Firewall:** iptables default-deny + DNS resolution allowlisty w entrypoincie. `cap_add: NET_ADMIN`
- **Dynamiczne porty:** globalny port-router.js w infra.yml. Caddy catch-all `http://:80` → port-router. Port-router parsuje hostname i routuje do kontenera przez Docker DNS (`sztauer-{name}-workspace:{port}`)
- **GPU:** compose override (`compose.gpu.yml`) zamiast profili
- **CI/CD:** GitHub Actions z docker/build-push-action, multi-arch via QEMU

## Kontekst

- @docs/VISION.md — dlaczego ten projekt istnieje
- @docs/ARCHITECTURE.md — entrypoint auto-detection, multi-machine, model danych
- @docs/SPEC.md — fazy z kryteriami akceptacji
- @docs/UI.md — docker compose, Docker Desktop, subdomeny, przeglądarka
- @tasks.md — plan implementacji
