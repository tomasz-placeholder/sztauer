# Architektura — Sztauer

## Zasada naczelna

Sztauer to **gotowy obraz Docker** na Docker Hub. Jedna komenda go uruchamia. Cała inteligencja żyje w entrypoincie kontenera — auto-detection, konfiguracja, firewall. Użytkownik nie potrzebuje żadnych plików ani konfiguracji.

## Dwa tryby użycia

```
┌─────────────────────────────────────────────────────────┐
│  Tryb prosty: docker run                                │
│  Jedna komenda. Jeden kontener. Dostęp przez port.      │
│  Brak plików konfiguracyjnych.                          │
├─────────────────────────────────────────────────────────┤
│  Tryb multi-project: docker compose (opcjonalny)        │
│  compose.yml + infra.yml. Wiele kontenerów.             │
│  Subdomeny: {name}.localhost, {name}-{port}.localhost    │
└─────────────────────────────────────────────────────────┘
```

Tryb prosty jest domyślnym doświadczeniem. Tryb multi-project to opt-in dla power userów.

## Obraz

### Co zawiera

- Claude Code CLI
- code-server (edytor webowy, port 8080)
- iptables firewall (default-deny, allowlista)
- Entrypoint z auto-detection
- Narzędzia deweloperskie (git, node, python, etc.)

### Entrypoint — auto-detection

Entrypoint wykrywa co ma do dyspozycji i konfiguruje środowisko:

- **Wymagane env vars** — brak API key? → fail-fast z czytelnym komunikatem.
- **Firewall** — zawsze aktywny. Resoluje allowlistę i konfiguruje iptables.
- **Git credentials** — zamontowany `~/.gitconfig` lub credential helper? → konfiguruje git user/email.
- **SSH keys** — zamontowany `~/.ssh`? → konfiguruje SSH agent.
- **Workspace** — pusty? → inicjalizuje git repo.

Detection odbywa się w runtime, wewnątrz kontenera. Nie ma zewnętrznych skryptów, nie ma CLI wrappera. Kontener sam wie co zrobić.

## Tryb prosty: `docker run`

```bash
docker run -d -e ANTHROPIC_API_KEY -p 8080:8080 sztauer/sandbox
```

Otwierasz `localhost:8080` — edytor z Claude Code. Koniec.

Opcjonalne flagi:

```bash
# Persystentny workspace:
-v $(pwd)/myapp:/workspace

# Git credentials z hosta:
-v ~/.gitconfig:/home/coder/.gitconfig:ro

# Nazwa kontenera (czytelna w Docker Desktop):
--name myapp
```

## Tryb multi-project: `docker compose`

Wymaga dwóch plików: `compose.yml` (template projektu) i `infra.yml` (reverse proxy). Oba dostarczane jako template w repo / README.

### Infrastruktura

`infra.yml` uruchamia Caddy z caddy-docker-proxy + port-router.js. Tworzy sieć `sztauer-proxy`. Uruchamiana raz:

```bash
docker compose -f infra.yml up -d
```

### Projekty

`compose.yml` parametryzowany `PROJECT_NAME`. Kontener dołącza do sieci proxy, labele umożliwiają autodiscovery:

```bash
PROJECT_NAME=myapp docker compose up -d
```

### Routing

Caddy routuje na podstawie Docker labels:

```
{name}.localhost              → code-server (edytor)
{name}-{port}.localhost       → dowolny port w kontenerze
```

port-router.js parsuje hostname `{name}-{port}.localhost`, rozwiązuje kontener przez Docker DNS (`sztauer-{name}-workspace`), i proxuje na odpowiedni port.

## Docker Desktop

Kontenery Sztauer są zaprojektowane dla Docker Desktop:

- **Czytelne nazwy** — `myapp` lub `sztauer-myapp-workspace` (tryb compose).
- **Healthchecks** — status widoczny w UI.
- **Logi** — przeglądalne przez GUI.
- **Labels** — metadane: projekt, rola kontenera.
- **Play/Stop** — zarządzanie przez GUI.

Docker Desktop nie jest wymagany — ale gdy jest, kontenery są w nim first-class.

## Multi-machine

```
                    ┌──────────────────┐
                    │  Docker Hub:     │
                    │  sztauer/sandbox │
                    └────────┬─────────┘
                             │ docker pull (auto)
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
     ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
     │ Workstation   │ │ Laptop       │ │ RPi          │
     │               │ │              │ │              │
     │ docker run    │ │ docker run   │ │ docker run   │
     │ -e API_KEY    │ │ -e API_KEY   │ │ -e API_KEY   │
     │ -p 8080:8080  │ │ -p 8080:8080 │ │ -p 8080:8080 │
     └──────────────┘ └──────────────┘ └──────────────┘
```

Ten sam obraz (multi-arch). Ta sama komenda. Jedyne co się różni to klucz API. Entrypoint dostosowuje się do środowiska automatycznie.

## Niezmienniki

1. Kontener NIGDY nie modyfikuje plików poza workspace i swoimi volumes.
2. Firewall zawsze aktywny, default-deny.
3. Sekrety wyłącznie przez env vars w runtime — nigdy w obrazie.
4. Obraz na Docker Hub jedynym publikowanym artefaktem — użytkownik nie buduje.
5. `docker run` z kluczem API wystarczy do działającego środowiska — zero plików.

## Cykl życia (tryb prosty)

```
START   → docker run -d -e ANTHROPIC_API_KEY -p 8080:8080 sztauer/sandbox
          → Docker pobiera obraz (jeśli nie ma)
          → Entrypoint: waliduje env, firewall, git, workspace, start code-server
          → localhost:8080 → edytor gotowy

PRACA   → Przeglądarka → localhost:8080 → edytor
          → Terminal w edytorze → claude
          → Claude koduje, stawia serwery

STOP    → docker stop <name>
DESTROY → docker rm -v <name>
```

## Struktura repozytorium (kod źródłowy obrazu)

```
sztauer/
├── CLAUDE.md                   # konstytucja projektu
├── Dockerfile                  # obraz publikowany na Docker Hub
├── entrypoint.sh               # auto-detection, firewall, start
├── port-router.js              # HTTP/WS proxy: hostname → kontener:port
├── allowlist.txt               # domeny dozwolone przez firewall
├── compose.yml                 # template: multi-project (opcjonalny)
├── compose.gpu.yml             # override: GPU passthrough (opcjonalny)
├── infra.yml                   # template: reverse proxy (opcjonalny)
├── .env.example                # wzór zmiennych środowiskowych
├── .github/workflows/build.yml # CI/CD: multi-arch build + push
├── docs/
│   ├── VISION.md
│   ├── ARCHITECTURE.md
│   ├── SPEC.md
│   └── UI.md
└── tasks.md
```
