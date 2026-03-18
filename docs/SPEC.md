# Specyfikacja — Sztauer

## Użytkownik

Developer używający Claude Code jako głównego narzędzia kodowania. Pracuje na wielu maszynach. Chce postawić izolowane środowisko jedną komendą: `PROJECT_NAME=myapp docker compose up -d`. Efekty pracy Claude'a widoczne w przeglądarce. Zarządzanie przez Docker Desktop lub docker compose — oba równorzędne. Nie klonuje repo, nie buduje obrazu — pobiera gotowy z Docker Hub.

## Faza 1 — Obraz: kontener z Claude Code

### F1.1 — Dockerfile

Obraz z Claude Code CLI, edytorem webowym i firewallem. Multi-arch (amd64 + arm64). Publikowany na Docker Hub.

**Akceptacja:** `docker pull sztauer/sandbox` pobiera obraz. Działa na x86 i arm64 bez zmian.

### F1.2 — Entrypoint z auto-detection

Entrypoint wykrywa środowisko w runtime i konfiguruje kontener: walidacja env vars (fail-fast), firewall setup, git credentials (jeśli zamontowane), inicjalizacja workspace, start edytora.

**Akceptacja:** Kontener startuje z samym `ANTHROPIC_API_KEY`. Brak klucza → czytelny komunikat i exit. Git credentials zamontowane → git skonfigurowany automatycznie. Nie zamontowane → kontener działa bez gita.

### F1.3 — compose.yml (template dla użytkownika)

Minimalny compose.yml, który użytkownik kopiuje i używa. Parametryzowany `PROJECT_NAME`. Named volumes, bind mount na workspace, labele dla Docker Desktop.

**Akceptacja:** Użytkownik z `compose.yml` + `.env` uruchamia projekt jedną komendą. Dwa projekty o różnych nazwach działają jednocześnie bez kolizji. Oba widoczne w Docker Desktop jako osobne grupy.

### F1.4 — Healthcheck

Kontener raportuje stan zdrowia do Docker i reverse proxy. Status widoczny w Docker Desktop.

**Akceptacja:** Docker Desktop pokazuje status healthy/unhealthy. Reverse proxy nie routuje do niezdrowego kontenera.

### F1.5 — .env.example

Dokumentuje wymagane i opcjonalne zmienne środowiskowe. Samowystarczalna dokumentacja — nowy użytkownik wie co wypełnić.

**Akceptacja:** `.env.example` zawiera komentarze wyjaśniające każdą zmienną. Skopiowanie do `.env` i uzupełnienie klucza API wystarczy do uruchomienia.

## Faza 2 — Routing: subdomeny w przeglądarce

### F2.1 — infra.yml z reverse proxy

Współdzielony reverse proxy z automatycznym discovery kontenerów. Oddzielny compose (`infra.yml`), niezależny od projektów.

**Akceptacja:** `docker compose -f infra.yml up -d` startuje proxy. Proxy automatycznie wykrywa nowe kontenery Sztauer. Brak proxy → kontenery nadal działają (dostęp przez bezpośredni port).

### F2.2 — Subdomena edytora

Każdy projekt dostępny pod `{nazwa}.localhost` → edytor webowy z widokiem na workspace.

**Akceptacja:** `PROJECT_NAME=myapp docker compose up -d` → `myapp.localhost` w przeglądarce otwiera edytor.

### F2.3 — Subdomena aplikacji

Serwis HTTP uruchomiony przez Claude Code w kontenerze dostępny pod osobną subdomeną.

**Akceptacja:** `python3 -m http.server` wewnątrz kontenera → odpowiednia subdomena serwuje odpowiedź. Bez ręcznej konfiguracji.

### F2.4 — Dynamiczne porty

Dowolny port w kontenerze dostępny pod przewidywalną subdomeną.

**Akceptacja:** Serwis na dowolnym porcie (3000, 5173, 8000) → odpowiednia subdomena routuje do niego.

## Faza 3 — CI/CD i publikacja

### F3.1 — Automatyczny build i push

CI/CD buduje obraz multi-arch i publikuje na Docker Hub przy każdym tagu/releaseie.

**Akceptacja:** Push tagu → obraz dostępny na Docker Hub dla amd64 i arm64. Wersjonowanie semantyczne.

### F3.2 — Compose profiles

Capabilities wymagające zmian na poziomie compose (GPU passthrough) dostępne przez Docker Compose profiles.

**Akceptacja:** `docker compose --profile gpu up -d` uruchamia z GPU. Bez profilu → standardowy kontener. Profil na maszynie bez GPU → czytelny błąd Dockera.

### F3.3 — Dokumentacja

README z quick start: 3 komendy od zera do działającego projektu. Opis auto-detection, FAQ.

**Akceptacja:** Nowy użytkownik potrafi postawić pierwszy projekt w <3 minuty (bez czasu pobierania obrazu).

## Wymagania niefunkcjonalne

- **Czas startu:** kontener gotowy w <30 sekund (obraz już pobrany).
- **Zasoby:** kontener <512 MB RAM w idle (bez uruchomionego Claude Code).
- **Multi-arch:** amd64 + arm64 z jednego Dockerfile.
- **Docker Desktop:** projekty czytelne w UI — zgrupowane, z labelami, z healthcheck statusem.
- **Bezpieczeństwo:** brak Docker socket w kontenerze. Firewall default-deny. Sekrety wyłącznie runtime.
- **Zero zależności:** poza Docker — nic więcej na hoście.
- **Zero buildu:** użytkownik nie buduje obrazu. Gotowy na Docker Hub.
- **Zero konfiguracji:** `PROJECT_NAME=myapp docker compose up -d` bez dodatkowych flag.
