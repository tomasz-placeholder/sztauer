# Interfejs — Sztauer

## Quick start

```bash
docker run -d -p 420:420 --network sztauer --name myapp sztauer/sandbox
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
└─────────────────────────────────┴─────────────────────────────────┘
         50%                                   50%
```

## Pierwsze uruchomienie

1. `docker run -d -p 420:420 --network sztauer --name myapp sztauer/sandbox`
2. Otwórz `localhost:420/sztauer`
3. W prawym panelu (Claude Code) → link do zalogowania
4. Kliknij → zaloguj się kontem Claude Max
5. Token zapamiętany w volume

Kolejne starty bez logowania (jeśli volume zachowany).

## Opcje docker run

```bash
# Podstawowe:
docker run -d -p 420:420 --network sztauer --name myapp sztauer/sandbox

# Persystentny workspace:
docker run -d -p 420:420 --network sztauer -v ~/myapp:/home/coder --name myapp sztauer/sandbox

# Persystentny token Claude:
docker run -d -p 420:420 --network sztauer -v claude-token:/home/coder/.claude --name myapp sztauer/sandbox

# Git credentials z hosta:
docker run -d -p 420:420 --network sztauer \
  -v ~/.gitconfig:/home/coder/.gitconfig:ro \
  -v ~/.ssh:/home/coder/.ssh:ro \
  --name myapp sztauer/sandbox

# Inny port:
docker run -d -p 8080:420 --network sztauer --name myapp sztauer/sandbox

# GPU:
docker run -d -p 420:420 --network sztauer --gpus all --name myapp sztauer/sandbox
```

## Zarządzanie

```bash
docker stop myapp           # zatrzymaj
docker start myapp          # wznów
docker rm -f myapp          # usuń
docker rm -fv myapp         # usuń z volumes
docker logs -f myapp        # logi
docker exec -it myapp bash  # shell
```

Albo Docker Desktop: play/stop/logs/shell w GUI.

## Multi-project

```bash
docker run -d -p 420:420 --network sztauer --name frontend sztauer/sandbox
docker run -d -p 421:420 --network sztauer --name backend sztauer/sandbox
# frontend → curl http://backend:3000
```

Opcjonalnie: compose z subdomenami (`compose.yml` + `infra.yml` z repo).

## Czego NIE ma

- Klucza API — logowanie przez Claude Max.
- Plików konfiguracyjnych — docker run wystarczy.
- Custom CLI — interfejsem jest Docker.
- SSL/TLS — HTTP na localhost.
- Auto-restart — kontener nie restartuje się po reboocie.
