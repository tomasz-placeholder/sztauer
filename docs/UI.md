# Interfejs — Sztauer

## Filozofia

Trzy punkty kontaktu: **Docker Desktop** (wizualny przegląd), **terminal** (standardowe komendy Docker), **przeglądarka** (praca). Zero custom tooling — interfejsem jest Docker i Docker Desktop.

## Tryb prosty: docker run

### Quick start

```bash
docker run -d -e ANTHROPIC_API_KEY -p 8080:8080 --name myapp sztauer/sandbox
```

Otwórz `localhost:8080` — edytor z Claude Code. Gotowe.

### Opcje

```bash
# Persystentny workspace:
docker run -d -e ANTHROPIC_API_KEY -p 8080:8080 \
  -v $(pwd)/myapp:/workspace --name myapp sztauer/sandbox

# Git credentials z hosta:
docker run -d -e ANTHROPIC_API_KEY -p 8080:8080 \
  -v ~/.gitconfig:/home/coder/.gitconfig:ro \
  -v ~/.ssh:/home/coder/.ssh:ro \
  -v $(pwd)/myapp:/workspace --name myapp sztauer/sandbox

# Drugi projekt na innym porcie:
docker run -d -e ANTHROPIC_API_KEY -p 8081:8080 \
  -v $(pwd)/other:/workspace --name other sztauer/sandbox
```

### Zarządzanie

```bash
docker stop myapp           # zatrzymaj
docker start myapp          # wznów
docker rm -f myapp          # usuń kontener
docker rm -fv myapp         # usuń kontener + volumes
docker logs -f myapp        # logi
docker exec -it myapp bash  # shell
```

Standardowe komendy Docker. Nic nowego do nauki.

## Tryb multi-project: docker compose (opcjonalny)

Dla wielu projektów z subdomenami. Wymaga `compose.yml` + `infra.yml` (template z repo/README).

### Komendy

```bash
# Infrastruktura (raz):
docker compose -f infra.yml up -d

# Nowy projekt:
PROJECT_NAME=myapp docker compose up -d

# Stop:
PROJECT_NAME=myapp docker compose down

# Zniszcz:
PROJECT_NAME=myapp docker compose down -v
```

### Subdomeny

```
{nazwa}.localhost              → code-server (edytor)
{nazwa}-{port}.localhost       → dowolny port w kontenerze
```

Wymagają działającej infrastruktury (`infra.yml`). Bez niej → tryb prosty z bezpośrednim portem.

### Przepływ pracy

```
1. PROJECT_NAME=myapp docker compose up -d
2. Otwórz myapp.localhost → edytor
3. Terminal w edytorze → claude
4. Claude koduje, stawia serwer → myapp-3000.localhost
5. Iteruj: Claude → przeglądarka → Claude
6. git push (gdy gotowe)
7. PROJECT_NAME=myapp docker compose down
```

## Docker Desktop

Kontenery Sztauer wyglądają czytelnie w Docker Desktop:

- Czytelna **nazwa** kontenera (--name lub compose project name).
- **Healthcheck status** widoczny bez CLI.
- **Logi** przeglądalne przez GUI.
- **Shell** dostępny przez GUI (terminal w Docker Desktop).
- **Start/Stop** przez GUI — play/stop button.

Docker Desktop nie jest wymagany, ale gdy jest — kontenery są w nim first-class.

## Setup nowej maszyny

### Tryb prosty (zero plików)

```bash
docker run -d -e ANTHROPIC_API_KEY=sk-... -p 8080:8080 sztauer/sandbox
```

Jedna komenda. Gotowe.

### Tryb multi-project (dwa pliki)

```
1. Skopiuj compose.yml i infra.yml (z README lub repo)
2. docker compose -f infra.yml up -d
3. PROJECT_NAME=myapp docker compose up -d
```

## Czego NIE ma

- **Custom CLI.** Interfejsem jest Docker i Docker Desktop.
- **Plików konfiguracyjnych.** docker run z env var wystarczy.
- **Dashboard projektów.** `docker ps`, Docker Desktop wystarczają.
- **Auto-restart po reboocie.** Kontenery projektów nie restartują się automatycznie.
- **SSL/TLS.** `.localhost` działa po HTTP.
- **Multi-user auth.** Jeden użytkownik, wiele maszyn.
- **Build wymagany od użytkownika.** Obraz gotowy na Docker Hub.
