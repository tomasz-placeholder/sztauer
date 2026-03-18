# Interfejs — Sztauer

## Filozofia

Trzy punkty kontaktu: **Docker Desktop** (wizualny przegląd), **terminal** (standardowe komendy Docker), **przeglądarka** (praca). Zero custom tooling — interfejsem jest Docker Compose i Docker Desktop.

## Terminal

### Komendy

```bash
# Infrastruktura (raz):
docker compose -f infra.yml up -d

# Nowy projekt:
PROJECT_NAME=myapp docker compose up -d

# Status:
docker ps --filter "label=sztauer"

# Logi:
PROJECT_NAME=myapp docker compose logs -f

# Stop (zachowaj dane):
PROJECT_NAME=myapp docker compose down

# Zniszcz (usuń volumes):
PROJECT_NAME=myapp docker compose down -v

# Shell do kontenera:
docker exec -it sztauer-myapp-workspace-1 bash
```

Standardowe komendy Docker Compose. Jedyny parametr to `PROJECT_NAME`.

### Compose profiles (opcjonalne)

```bash
# GPU passthrough:
PROJECT_NAME=myapp docker compose --profile gpu up -d
```

Profiles to jedyny przypadek wymagający dodatkowej flagi. Reszta capabilities wykrywana automatycznie w entrypoincie.

## Docker Desktop

Projekty Sztauer wyglądają czytelnie w Docker Desktop:

- Każdy projekt to osobna **grupa** (Compose project `sztauer-myapp`).
- Kontenery, volumes i sieci projektu zgrupowane razem.
- **Healthcheck status** widoczny bez komend CLI.
- **Logi** przeglądalne przez GUI.
- **Labels** z metadanymi: nazwa projektu, rola kontenera.
- Projekty **startowane i zatrzymywane** przez GUI — play/stop w Docker Desktop.

Docker Desktop nie jest wymagany, ale gdy jest — projekty są w nim first-class citizens.

## Przeglądarka

### Subdomeny

```
{nazwa}.localhost              → edytor webowy (workspace projektu)
{nazwa}-app.localhost          → główny serwis HTTP w kontenerze
{nazwa}-{port}.localhost       → dowolny port w kontenerze
```

Schemat subdomen wymaga infrastruktury reverse proxy (`infra.yml`). Bez proxy → dostęp przez bezpośrednie porty.

### Przepływ pracy

```
1. PROJECT_NAME=myapp docker compose up -d
2. Otwórz myapp.localhost → edytor z widokiem na workspace
3. Terminal w edytorze → claude
4. Claude czyta CLAUDE.md, koduje
5. Claude stawia serwer → myapp-app.localhost
6. Iteruj: Claude → przeglądarka → Claude
7. git push (gdy gotowe)
8. PROJECT_NAME=myapp docker compose down
```

## Setup nowej maszyny

```
1. Skopiuj compose.yml, infra.yml, .env (lub stwórz z .env.example)
2. Uzupełnij ANTHROPIC_API_KEY w .env
3. docker compose -f infra.yml up -d
4. PROJECT_NAME=myapp docker compose up -d
```

Trzy pliki + dwie komendy. Żadnego klonowania repo, żadnego builda, żadnej instalacji.

## Czego NIE ma

- **Custom CLI.** Interfejsem jest Docker Compose i Docker Desktop.
- **Dashboard projektów.** `docker ps`, Docker Desktop wystarczają.
- **Auto-restart po reboocie.** Kontenery projektów nie restartują się automatycznie. Infrastruktura (proxy) — tak.
- **SSL/TLS.** `.localhost` działa po HTTP. HTTPS to potencjalny przyszły feature.
- **Hot-reload konfiguracji.** Zmiana `.env` wymaga restart kontenera.
- **Multi-user auth.** Jeden użytkownik, wiele maszyn.
- **Build wymagany od użytkownika.** Obraz gotowy na Docker Hub.
