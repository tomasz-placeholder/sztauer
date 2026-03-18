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
Dockerfile                      — obraz: Claude Code + edytor + firewall
entrypoint.sh                   — auto-detection capabilities w runtime
compose.yml                     — template dla użytkownika
infra.yml                       — reverse proxy + sieć współdzielona
.env.example                    — wymagane zmienne środowiskowe
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

## Decyzje techniczne do podjęcia w trakcie implementacji

Poniższe nie są z góry narzucone — wybierz najlepsze rozwiązanie w danym kontekście:

- Konkretny edytor webowy (code-server, OpenVSCode Server, Theia — co najlepiej pasuje)
- Porty wewnętrzne serwisów
- Konkretny reverse proxy (Traefik, Caddy, nginx — co najprościej rozwiąże routing z autodiscovery)
- Bazowy obraz Docker (node:20, debian, ubuntu — co najlepiej wspiera Claude Code)
- Mechanizm dynamicznych portów (docker labels, regex routing, sidecar)
- Jakie capabilities wykrywać w entrypoincie vs. przez compose profiles
- CI/CD do budowania i publikacji obrazu (GitHub Actions, inne)

## Kontekst

- @docs/VISION.md — dlaczego ten projekt istnieje
- @docs/ARCHITECTURE.md — entrypoint auto-detection, multi-machine, model danych
- @docs/SPEC.md — fazy z kryteriami akceptacji
- @docs/UI.md — docker compose, Docker Desktop, subdomeny, przeglądarka
- @tasks.md — plan implementacji
