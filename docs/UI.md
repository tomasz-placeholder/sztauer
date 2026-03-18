# Interfejs — Sztauer

## Filozofia

Jedna komenda, zero plików. Otwierasz przeglądarkę — masz gotowe środowisko. Port główny wolny na Twoją aplikację.

## Quick start

```bash
docker run -d -p 420:420 --name myapp sztauer/sandbox
```

Otwórz `localhost:420/sztauer`. Gotowe.

## Adresy

```
localhost:420/sztauer          → split screen: VS Code + Claude Code CLI
localhost:420                  → Twoja aplikacja (to co Claude Code postawi)
```

## Split screen: `/sztauer`

```
┌─────────────────────────────────┬─────────────────────────────────┐
│                                 │                                 │
│  VS Code                        │  Claude Code CLI                │
│                                 │                                 │
│  - Pusty edytor (bez welcome)   │  - Dangerous mode               │
│  - Explorer: ~/                 │  - Max thinking                 │
│  - Pre-installed plugins        │  - Max research (thorough)      │
│  - Skonfigurowany theme/font    │  - Folder: ~/                   │
│                                 │                                 │
│  Edytujesz pliki,               │  Wydajesz polecenia,            │
│  przeglądasz kod                │  Claude koduje                  │
│                                 │                                 │
└─────────────────────────────────┴─────────────────────────────────┘
         50%                                   50%
```

Oba panele w tym samym katalogu (`~`). Plik stworzony przez Claude → natychmiast widoczny w VS Code.

## Pierwsze uruchomienie — logowanie

1. `docker run -d -p 420:420 --name myapp sztauer/sandbox`
2. Otwórz `localhost:420/sztauer`
3. W prawym panelu (Claude Code) → link do zalogowania
4. Kliknij link → zaloguj się kontem Claude Max
5. Gotowe — token zapamiętany w volume

Kolejne uruchomienia bez logowania (jeśli volume zachowany).

## Opcje docker run

```bash
# Podstawowe (zero config):
docker run -d -p 420:420 --name myapp sztauer/sandbox

# Z persystentnym workspace:
docker run -d -p 420:420 -v ~/myapp:/home/coder --name myapp sztauer/sandbox

# Z persystentnym tokenem Claude (przeżyje docker rm):
docker run -d -p 420:420 -v claude-token:/home/coder/.claude --name myapp sztauer/sandbox

# Git credentials z hosta:
docker run -d -p 420:420 \
  -v ~/.gitconfig:/home/coder/.gitconfig:ro \
  -v ~/.ssh:/home/coder/.ssh:ro \
  --name myapp sztauer/sandbox

# Inny port:
docker run -d -p 8080:420 --name myapp sztauer/sandbox

# GPU:
docker run -d -p 420:420 --gpus all --name myapp sztauer/sandbox
```

## Zarządzanie

```bash
docker stop myapp           # zatrzymaj
docker start myapp          # wznów (bez ponownego logowania)
docker rm -f myapp          # usuń
docker logs -f myapp        # logi
docker exec -it myapp bash  # shell
```

Albo przez Docker Desktop — play/stop/logs/shell w GUI.

## Port aplikacji: `localhost:420`

Wszystko co Claude Code postawi na wewnętrznym porcie → natychmiast widoczne pod `localhost:420`.

```
Claude: "Uruchamiam serwer Next.js na porcie 3000"
→ localhost:420 serwuje aplikację Next.js
```

Gdy żadna aplikacja nie nasłuchuje → strona placeholder z informacją.

## Docker Desktop

- **Nazwa kontenera** → `myapp` (z `--name`).
- **Healthcheck** → widoczny status.
- **Logi** → przeglądalne przez GUI.
- **Shell** → dostępny przez GUI.
- **Play/Stop** → zarządzanie przez GUI.

## Multi-project (opcjonalny)

Wiele projektów jednocześnie — różne porty:

```bash
docker run -d -p 420:420 --name project-a sztauer/sandbox
docker run -d -p 421:420 --name project-b sztauer/sandbox
```

Lub compose z subdomenami (template z README):

```bash
docker compose -f infra.yml up -d
PROJECT_NAME=myapp docker compose up -d
# → myapp.localhost/sztauer = workspace
# → myapp.localhost = aplikacja
```

## Czego NIE ma

- **Klucza API.** Logowanie przez Claude Max w przeglądarce.
- **Plików konfiguracyjnych.** docker run wystarczy.
- **Custom CLI.** Interfejsem jest Docker.
- **SSL/TLS.** `.localhost` i `localhost` po HTTP.
- **Auto-restart.** Kontener nie restartuje się po reboocie.
- **Multi-user auth.** Jeden użytkownik, wiele maszyn.
