# Sztauer

Gotowy obraz Docker dla Claude Code. Podajesz klucz API, uruchamiasz kontener — dostajesz izolowane środowisko z edytorem webowym, firewallem i Claude Code CLI w przeglądarce.

## Quick start

```bash
# 1. Pobierz pliki (compose.yml, infra.yml, .env.example)
#    lub skopiuj je z tego repozytorium.

# 2. Utwórz .env z kluczem API:
cp .env.example .env
# Uzupełnij ANTHROPIC_API_KEY w .env

# 3. Uruchom infrastrukturę (raz):
docker compose -f infra.yml up -d

# 4. Uruchom projekt:
PROJECT_NAME=myapp docker compose up -d

# 5. Otwórz w przeglądarce:
#    myapp.localhost → edytor webowy
#    Terminal w edytorze → claude → Claude Code CLI
```

## Subdomeny

| Adres | Co |
|---|---|
| `myapp.localhost` | Edytor webowy (code-server) |
| `myapp-app.localhost` | Główny serwis HTTP (port 8000) |
| `myapp-3000.localhost` | Dowolny port w kontenerze |

Subdomeny wymagają infrastruktury reverse proxy (`infra.yml`). Bez niej — dostęp przez port mapowany przez Docker (`docker compose port workspace 8080`).

## Komendy

```bash
# Nowy projekt:
PROJECT_NAME=myapp docker compose up -d

# Status:
docker ps --filter "label=sztauer"

# Logi:
PROJECT_NAME=myapp docker compose logs -f

# Shell:
docker exec -it sztauer-myapp-workspace bash

# Stop (dane zachowane):
PROJECT_NAME=myapp docker compose down

# Zniszcz (z volumes):
PROJECT_NAME=myapp docker compose down -v
```

## Wiele projektów

Każdy projekt to osobna instancja z własną nazwą:

```bash
PROJECT_NAME=frontend docker compose up -d
PROJECT_NAME=backend docker compose up -d
# frontend.localhost, backend.localhost — działają równocześnie
```

## Git

Odkomentuj w `compose.yml` aby zamontować credentials:

```yaml
volumes:
  - ~/.gitconfig:/root/.gitconfig:ro
  - ~/.ssh:/root/.ssh:ro
```

Entrypoint automatycznie wykryje i skonfiguruje git/SSH.

## Firewall

Kontener działa z firewallem default-deny. Domyślna allowlista:
- Anthropic API
- GitHub
- npm registry
- PyPI

Dodatkowe domeny przez zmienną `FIREWALL_ALLOW` w `.env`:

```env
FIREWALL_ALLOW=custom-api.example.com,deb.debian.org
```

## GPU (opcjonalnie)

```bash
PROJECT_NAME=myapp docker compose -f compose.yml -f compose.gpu.yml up -d
```

## Setup nowej maszyny

1. Skopiuj `compose.yml`, `infra.yml`, `.env`
2. Uzupełnij `ANTHROPIC_API_KEY` w `.env`
3. `docker compose -f infra.yml up -d`
4. `PROJECT_NAME=myapp docker compose up -d`

Trzy pliki + dwie komendy. Żadnego klonowania repo, żadnego builda.

## Auto-detection

Entrypoint kontenera automatycznie wykrywa:
- **Git credentials** — zamontowany `.gitconfig` lub `.ssh` → konfiguruje git/SSH
- **Workspace** — pusty → inicjalizuje git repo
- **Firewall** — zawsze aktywny z allowlistą
- **Env vars** — brak `ANTHROPIC_API_KEY` → czytelny błąd i exit

## Architektura

```
┌──────────────────────────────────────────────────┐
│  Traefik (infra.yml)                             │
│  *.localhost → kontenery Sztauer                 │
├──────────────────────────────────────────────────┤
│  sztauer/sandbox (Docker Hub)                    │
│  code-server + Claude Code + firewall            │
│  entrypoint z auto-detection                     │
└──────────────────────────────────────────────────┘
```

Obraz multi-arch (amd64 + arm64). Ten sam obraz na workstation, laptopie i RPi.
