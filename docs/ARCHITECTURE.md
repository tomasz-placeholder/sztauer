# Architektura — Sztauer

## Zasada naczelna

Sztauer to **gotowy obraz Docker** publikowany na Docker Hub. Użytkownik nie buduje, nie klonuje, nie instaluje — pobiera obraz i uruchamia kontener. Cała inteligencja (auto-detection, konfiguracja, firewall) żyje w entrypoincie kontenera. Interfejsem jest standardowe `docker compose` i Docker Desktop.

## Dwie warstwy

```
┌─────────────────────────────────────────────────────────┐
│  Docker Compose / Docker Desktop                        │
│  compose.yml: projekt-kontener. infra.yml: proxy.       │
│  Użytkownik operuje standardowymi komendami Dockera.    │
├─────────────────────────────────────────────────────────┤
│  Obraz Sztauer (Docker Hub)                             │
│  Claude Code + edytor + firewall + entrypoint.          │
│  Entrypoint wykrywa środowisko i konfiguruje kontener.  │
└─────────────────────────────────────────────────────────┘
```

## Obraz

### Co zawiera

- Claude Code CLI
- Edytor webowy
- Firewall (default-deny, allowlista)
- Entrypoint z auto-detection
- Narzędzia deweloperskie (git, node, python, etc.)

### Entrypoint — auto-detection

Entrypoint kontenera wykrywa co ma do dyspozycji i konfiguruje środowisko:

- **Git credentials** — zamontowany `~/.gitconfig` lub credential helper? → konfiguruje git user/email.
- **SSH keys** — zamontowany `~/.ssh`? → konfiguruje SSH agent.
- **Firewall** — zawsze aktywny, allowlista z env vars.
- **Workspace** — pusty? → inicjalizuje git repo.
- **Wymagane env vars** — brak API key? → fail-fast z czytelnym komunikatem.

Detection odbywa się w runtime, wewnątrz kontenera. Nie ma zewnętrznych skryptów, nie ma CLI wrappera. Kontener sam wie co zrobić.

### Compose profiles (opcjonalne)

Capabilities wymagające zmian na poziomie compose (nie entrypointa) używają Docker Compose profiles:

```bash
# Standardowe uruchomienie (90% przypadków):
PROJECT_NAME=myapp docker compose up -d

# Z GPU passthrough:
PROJECT_NAME=myapp docker compose --profile gpu up -d
```

Profiles to jedyny przypadek, gdzie użytkownik musi coś jawnie aktywować. Wszystko co da się wykryć w runtime — wykrywa entrypoint automatycznie.

## Infrastruktura

### Reverse proxy

Współdzielony reverse proxy z automatycznym discovery kontenerów. Osobny compose (`infra.yml`), niezależny od projektów. Uruchamiany raz — potem działa w tle.

```bash
docker compose -f infra.yml up -d
```

Proxy wykrywa nowe kontenery Sztauer przez Docker labels i automatycznie routuje ruch. Brak proxy → kontenery nadal działają, dostęp przez bezpośrednie porty.

### Sieć

Sieć proxy jest zewnętrzna (`external: true`). Tworzona raz (przez `infra.yml`), współdzielona przez wszystkie projekty. Kontenery projektów dołączają do niej automatycznie.

## Docker Desktop

Projekty Sztauer są zaprojektowane tak, żeby dobrze wyglądały i działały w Docker Desktop:

- **Compose project name** `sztauer-{nazwa}` — grupuje kontenery, volumes i sieci projektu.
- **Labels** — czytelne metadane: nazwa projektu, rola kontenera. Widoczne w Docker Desktop UI.
- **Named volumes** z prefixem `sztauer-{nazwa}-` — łatwe do identyfikacji i zarządzania.
- **Healthchecks** — status widoczny w Docker Desktop bez komend CLI.
- **Logi** — przeglądalne przez Docker Desktop.

Docker Desktop nie jest wymagany — wszystko działa z samym Docker Engine. Ale gdy jest dostępny, projekty są w nim czytelne.

## Multi-machine

### Model

```
                    ┌──────────────────┐
                    │  Docker Hub:     │
                    │  sztauer/sandbox │
                    └────────┬─────────┘
                             │ docker pull
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
     ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
     │ Workstation   │ │ Laptop       │ │ RPi          │
     │ ten sam obraz │ │ ten sam obraz│ │ ten sam obraz│
     │               │ │              │ │              │
     │ .env (local)  │ │ .env (local) │ │ .env (local) │
     │ compose.yml   │ │ compose.yml  │ │ compose.yml  │
     └──────────────┘ └──────────────┘ └──────────────┘
```

Ten sam obraz (multi-arch), ten sam `compose.yml`. Jedyne co się różni to `.env` (sekrety). Entrypoint automatycznie dostosowuje się do środowiska — nie ma konfiguracji maszynowej.

### Setup nowej maszyny

1. Skopiuj `compose.yml`, `infra.yml`, `.env` (lub stwórz z `.env.example`)
2. `docker compose -f infra.yml up -d`
3. `PROJECT_NAME=myapp docker compose up -d`

Trzy kroki. Żadnego klonowania repo, żadnego builda.

## Model danych

System nie ma bazy danych. Stan wyrażony jest przez:

- **Docker containers** — aktywne projekty
- **Docker volumes** — persystentne dane (konfiguracja edytora, sesje Claude Code)
- **Bind mounts** — kod źródłowy na hoście (`projects/{name}/`)
- **Docker labels** — metadane do discovery (filtrowanie, routing, Docker Desktop)
- **Pliki lokalne** — `.env` (sekrety), `compose.yml`, `infra.yml`

## Niezmienniki

1. Kontener projektowy NIGDY nie modyfikuje plików poza workspace i swoimi volumes.
2. Reverse proxy nie eksponuje portów bez jawnej konfiguracji w labelach.
3. Plik `.env` jest jedynym źródłem sekretów. Nie ma env vars hardkodowanych w compose ani Dockerfile.
4. Sieć proxy jest zewnętrzna (`external: true`) — tworzona raz, współdzielona.
5. Obraz na Docker Hub jest jedynym artefaktem publikowanym — użytkownik nie buduje lokalnie.
6. Zero custom CLI — interfejsem jest `docker compose` i Docker Desktop.

## Cykl życia projektu

```
START   → docker compose up -d
          → Docker pobiera obraz (jeśli nie ma)
          → Tworzy volumes (jeśli nie istnieją)
          → Kontener startuje, entrypoint:
            - waliduje env vars
            - konfiguruje firewall
            - wykrywa git credentials
            - inicjalizuje workspace
            - startuje edytor webowy
          → Reverse proxy wykrywa labele, routuje ruch

PRACA   → Przeglądarka → subdomena → edytor webowy
          → Terminal w edytorze → Claude Code CLI
          → Claude tworzy serwis → dostępny pod osobną subdomeną
          → Docker Desktop → logi, status, volumes

STOP    → docker compose down → kontener usunięty, volumes zachowane

DESTROY → docker compose down -v → kontener + volumes usunięte, kod na hoście pozostaje
```

## Struktura repozytorium (kod źródłowy obrazu)

```
sztauer/
├── CLAUDE.md                   # konstytucja projektu
├── Dockerfile                  # obraz publikowany na Docker Hub
├── entrypoint.sh               # auto-detection, setup, start
├── compose.yml                 # template: jak użyć obrazu
├── infra.yml                   # template: reverse proxy
├── .env.example                # wzór sekretów
├── docs/
│   ├── VISION.md
│   ├── ARCHITECTURE.md
│   ├── SPEC.md
│   └── UI.md
├── tasks.md
└── projects/                   # lokalne testowanie (gitignored)
```
