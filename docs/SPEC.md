# Specyfikacja — Sztauer

## Użytkownik

Developer używający Claude Code. Pracuje na wielu maszynach. Chce postawić izolowane środowisko jedną komendą — `docker run` z kluczem API. Żadnych plików, żadnego builda. Opcjonalnie: wiele projektów z subdomenami przez compose.

## Faza 1 — Obraz: kontener z Claude Code

### F1.1 — Dockerfile

Obraz z Claude Code CLI, code-server i iptables firewallem. Bazowy obraz: node:20-bookworm. Multi-arch (amd64 + arm64). Publikowany na Docker Hub.

**Akceptacja:** `docker run -d -e ANTHROPIC_API_KEY -p 8080:8080 sztauer/sandbox` → kontener startuje, `localhost:8080` otwiera edytor, Claude Code działa w terminalu. Działa na x86 i arm64 bez zmian.

### F1.2 — Entrypoint z auto-detection

Entrypoint wykrywa środowisko w runtime: walidacja env vars (fail-fast), iptables firewall z allowlistą, git credentials (jeśli zamontowane), inicjalizacja workspace, start code-server.

**Akceptacja:** Kontener startuje z samym `ANTHROPIC_API_KEY`. Brak klucza → czytelny komunikat i exit 1. Git credentials zamontowane → git skonfigurowany. Nie zamontowane → kontener działa bez gita. Firewall blokuje ruch poza allowlistą.

### F1.3 — Healthcheck

Kontener raportuje stan zdrowia do Docker. Status widoczny w Docker Desktop.

**Akceptacja:** `docker ps` i Docker Desktop pokazują status healthy/unhealthy.

### F1.4 — .env.example

Dokumentuje zmienne środowiskowe (wymagane i opcjonalne). Samowystarczalna dokumentacja.

**Akceptacja:** Komentarze wyjaśniają każdą zmienną. Służy jako reference — nie jest wymagany do uruchomienia.

## Faza 2 — Routing: subdomeny (opcjonalne)

### F2.1 — infra.yml z Caddy + port-router

Caddy z caddy-docker-proxy + port-router.js. Sieć `sztauer-proxy` (external). Autodiscovery kontenerów przez Docker labels.

**Akceptacja:** `docker compose -f infra.yml up -d` startuje proxy. Automatycznie wykrywa nowe kontenery Sztauer. Brak proxy → kontenery nadal działają (dostęp przez bezpośredni port).

### F2.2 — compose.yml (template)

Parametryzowany `PROJECT_NAME`. Named volumes, bind mount workspace, labele dla Caddy i Docker Desktop. Project name `sztauer-{name}`.

**Akceptacja:** `PROJECT_NAME=myapp docker compose up -d` → `myapp.localhost` otwiera edytor. Dwa projekty jednocześnie bez kolizji.

### F2.3 — Dynamiczne porty

port-router.js parsuje hostname `{name}-{port}.localhost` i routuje do kontenera. Obsługuje HTTP i WebSocket.

**Akceptacja:** Serwis na dowolnym porcie (3000, 5173, 8000) → `{name}-{port}.localhost` routuje do niego. Bez ręcznej konfiguracji.

## Faza 3 — Publikacja i hardening

### F3.1 — CI/CD

GitHub Actions: multi-arch build (QEMU) + push na Docker Hub przy tagu. Wersjonowanie semantyczne.

**Akceptacja:** Push tagu → obraz dostępny na Docker Hub dla amd64 i arm64.

### F3.2 — GPU passthrough

compose.gpu.yml jako override file.

**Akceptacja:** `docker compose -f compose.yml -f compose.gpu.yml up -d` uruchamia z GPU. Maszyna bez GPU → czytelny błąd Dockera.

### F3.3 — README

Quick start: 1 komenda od zera do działającego środowiska. Opcjonalny setup multi-project. Auto-detection w entrypoincie.

**Akceptacja:** Nowy użytkownik potrafi uruchomić pierwsze środowisko w <1 minutę (bez czasu pobierania obrazu).

## Wymagania niefunkcjonalne

- **Czas startu:** kontener gotowy w <30 sekund (obraz już pobrany).
- **Zasoby:** <512 MB RAM w idle (bez uruchomionego Claude Code).
- **Multi-arch:** amd64 + arm64 z jednego Dockerfile.
- **Docker Desktop:** kontener czytelny w UI — nazwa, healthcheck, logi.
- **Bezpieczeństwo:** brak Docker socket. Firewall default-deny. Sekrety wyłącznie runtime.
- **Zero zależności:** poza Docker — nic na hoście.
- **Zero plików:** `docker run` z env var wystarczy. Compose opcjonalny.
