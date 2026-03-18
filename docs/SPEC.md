# Specyfikacja — Sztauer

Fazy implementacji z kryteriami akceptacji. Szczegóły techniczne → @docs/ARCHITECTURE.md.

## Faza 1 — Obraz bazowy

### F1.1 Dockerfile
**Akceptacja:** `docker build -t sztauer .` buduje obraz. Zawiera: Claude Code CLI, code-server, web terminal, reverse proxy, iptables, git, node, python.

### F1.2 Entrypoint
**Akceptacja:** Kontener startuje. Firewall aktywny. code-server nasłuchuje. Web terminal nasłuchuje. `~/CLAUDE.md` obecny (jeśli wcześniej nie istniał). Logi czytelne.

### F1.3 Autentykacja Claude Max
**Akceptacja:** Pierwszy start → Claude prosi o login → użytkownik loguje się → token w `~/.claude/`. Restart → Claude działa bez logowania (volume zachowany).

### F1.4 Firewall
**Akceptacja:** `curl https://google.com` → zablokowane. `curl https://api.anthropic.com` → przepuszczone. `curl http://inny-kontener:3000` (sieć sztauer) → przepuszczone.

### F1.5 Healthcheck
**Akceptacja:** `docker ps` pokazuje healthy. Docker Desktop pokazuje status.

### F1.6 Sieć sztauer
**Akceptacja:** `docker run --network sztauer --name a` + `docker run --network sztauer --name b` → kontener `b` odpowiada na `curl http://b:port` z kontenera `a`.

### F1.7 Test integracyjny
**Akceptacja:** `docker run -d -p 420:420 --network sztauer --name test sztauer` → kontener startuje, healthcheck przechodzi w <30s.

## Faza 2 — Split screen i routing

### F2.1 Reverse proxy
**Akceptacja:** Port 420: `/sztauer` → workspace. `/` → port aplikacji lub placeholder.

### F2.2 Split screen
**Akceptacja:** `localhost:420/sztauer` → dwa panele 50/50. Lewy: code-server. Prawy: web terminal z Claude Code. Responsywne.

### F2.3 code-server
**Akceptacja:** Lewy panel → VS Code. Brak welcome screen. Explorer: `~/`. Pluginy zainstalowane. Settings skonfigurowane.

### F2.4 Web terminal z Claude Code
**Akceptacja:** Prawy panel → terminal z uruchomionym `claude`. Dangerous mode aktywny. Thinking budget max. Research thorough. Folder = `~/`.

### F2.5 Wspólny workspace
**Akceptacja:** Claude tworzy plik → widoczny w VS Code bez refresha. Edycja w VS Code → Claude widzi.

### F2.6 Port aplikacji
**Akceptacja:** `python3 -m http.server 3000` wewnątrz kontenera → `localhost:420` serwuje. Przed uruchomieniem → placeholder.

## Faza 3 — Domyślne instrukcje

### F3.1 workspace-template/CLAUDE.md
**Akceptacja:** Nowy kontener → `~/CLAUDE.md` obecny. Claude Code czyta go. Zawiera: lokalizację, narzędzia, port, sieć, firewall. Kontener z istniejącym `~/CLAUDE.md` → nie nadpisany.

## Faza 4 — Publikacja

### F4.1 CI/CD
**Akceptacja:** Push tagu → obraz na Docker Hub. amd64 + arm64.

### F4.2 README
**Akceptacja:** Nowy użytkownik: docker run → localhost:420/sztauer → login → praca. <2 minuty.

### F4.3 Smoke test
**Akceptacja:** docker run → split screen → Claude koduje → aplikacja pod localhost:420.

## Faza 5 — Multi-project

### F5.1 compose.yml + infra.yml
**Akceptacja:** Dwa projekty jednocześnie. Subdomeny `{name}.localhost`. Nie wymagane — tryb `docker run` jest domyślny.

## Faza 6 — Snapshot & Restore

### F6.1 Snapshot instancji
**Akceptacja:** `docker commit myapp sztauer-myapp:snapshot` + metadata o stanie Claude session, zainstalowanych pakietach, running services. Snapshot przenosimy na inną maszynę → `docker run` odtwarza stan.

### F6.2 Named snapshots
**Akceptacja:** Label `sztauer.snapshot=<name>` na commitowanym obrazie. Listowanie snapshotów: `docker images --filter label=sztauer.snapshot`.

## Faza 7 — Project Templates

### F7.1 Parametr `TEMPLATE`
**Akceptacja:** `docker run -e TEMPLATE=nextjs ... sztauer` → workspace zainicjalizowany z szablonem Next.js (package.json, CLAUDE.md z instrukcjami dla stacku, .gitignore). Brak `TEMPLATE` → pusty workspace jak dotychczas.

### F7.2 Repozytorium szablonów
**Akceptacja:** Katalog `templates/` w repo. Każdy template = folder z plikami workspace + CLAUDE.md. Dodanie nowego template = dodanie folderu. Entrypoint kopiuje zawartość template do `~/` jeśli workspace pusty.

### F7.3 Custom templates
**Akceptacja:** `docker run -e TEMPLATE=https://github.com/user/template ... sztauer` → klonuje repo jako template. Działa z dowolnym publicznym repo.

## Faza 8 — Service Discovery

### F8.1 Rejestracja serwisów
**Akceptacja:** Każda instancja Sztauer rozgłasza swoje serwisy przez Docker labels: `sztauer.services=api:3000,ws:8080`. Inne instancje czytają labels przez Docker API (read-only).

### F8.2 Instrukcje w CLAUDE.md
**Akceptacja:** Domyślny CLAUDE.md w instancji zawiera automatycznie generowaną listę serwisów dostępnych w sieci `sztauer` (na podstawie labels innych kontenerów). Claude Code wie jakie API są dostępne bez ręcznego informowania.

### F8.3 Health-aware routing
**Akceptacja:** Serwis w innym kontenerze przechodzi na unhealthy → instancja widzi to w `sztauer.services` listing. Claude Code informowany o niedostępności.

## Faza 9 — Observability

### F9.1 Instancja meta
**Akceptacja:** `docker run -p 420:420 --network sztauer --name sztauer-dashboard sztauer` z `TEMPLATE=dashboard` → dashboard na `localhost:420` pokazujący: aktywne instancje, ich healthcheck, resource usage (CPU/RAM), aktywne serwisy, ostatnią aktywność.

### F9.2 Activity feed
**Akceptacja:** Dashboard wyświetla feed: jakie pliki Claude modyfikuje w każdej instancji, jakie komendy uruchamia, jakie serwisy startuje. Real-time przez WebSocket.

### F9.3 Resource limits
**Akceptacja:** Dashboard pozwala zobaczyć i ustawić limity CPU/RAM per instancja. `docker update` pod spodem.

## Faza 10 — Plugin System

### F10.1 Struktura pluginu
**Akceptacja:** Katalog `plugins/` w repo. Plugin = folder z: `manifest.json` (nazwa, opis, hooki), opcjonalne pliki (CLAUDE.md fragment, settings, extensions, firewall rules). Plugin aktywuje się przez env var: `-e PLUGINS=typescript,docker`.

### F10.2 Pluginy stackowe
**Akceptacja:** Plugin `typescript` dodaje: VS Code extensions (ESLint, Prettier, TypeScript), fragment CLAUDE.md z konwencjami TS, tsconfig.json template. Plugin `python` dodaje: pylint, black, Python extensions, fragment CLAUDE.md z konwencjami Python.

### F10.3 Community plugins
**Akceptacja:** Plugin może być repozytorium Git: `-e PLUGINS=github.com/user/sztauer-plugin-rust`. Entrypoint klonuje i aktywuje. Struktura identyczna jak lokalne pluginy.

### F10.4 Plugin hooks
**Akceptacja:** Plugin może definiować hooki: `on-start.sh` (po starcie kontenera), `on-file-change.sh` (po modyfikacji pliku), `on-service-start.sh` (po uruchomieniu serwisu). Hooki uruchamiane przez entrypoint.

## Faza 11 — Autonomous Teams (horyzont 5-letni)

### F11.1 Rola instancji
**Akceptacja:** Env var `ROLE=architect|frontend|backend|tester|reviewer`. Każda rola dostaje specjalizowany CLAUDE.md z instrukcjami odpowiednimi do roli. Architect planuje, dzieli zadania na konktrakty. Frontend/Backend implementują. Tester pisze i uruchamia testy. Reviewer robi code review.

### F11.2 Shared project board
**Akceptacja:** Plik `~/shared/board.json` zamontowany jako volume współdzielony między instancjami. Zawiera: lista zadań, statusy, kontrakty API, decyzje architektoniczne. Każda instancja czyta i aktualizuje board.

### F11.3 Inter-instance messaging
**Akceptacja:** Instancje komunikują się przez lekki message broker (w sieci `sztauer`). Architect wysyła task → Backend odbiera, implementuje, raportuje. Reviewer dostaje PR, komentuje. Wiadomości pojawiają się w Claude Code CLI jako kontekst.

### F11.4 Contract-driven development
**Akceptacja:** Architect definiuje kontrakty API (OpenAPI, protobuf, TypeScript types) w `~/shared/contracts/`. Inne instancje implementują swoje strony kontraktu. CI w instancji tester weryfikuje zgodność implementacji z kontraktem.

### F11.5 Human-as-architect
**Akceptacja:** Użytkownik rozmawia wyłącznie z instancją Architect (lub dashboardem). Definiuje wizję i priorytety. Architect deleguje do specjalistów. Użytkownik reviewuje rezultaty, nie pisze kodu. Pull requesty od poszczególnych instancji trafiają do reviewer instancji, potem do użytkownika.

## Faza 12 — Self-Improving Platform

### F12.1 Dogfooding
**Akceptacja:** Dedykowana instancja Sztauer (`ROLE=platform-engineer`) monitoruje repo Sztauer, proponuje ulepszenia Dockerfile, entrypointa, konfiguracji. Otwiera PR-y do repo Sztauer — reviewed przez użytkownika.

### F12.2 Auto-tuning
**Akceptacja:** Platform-engineer instancja analizuje logi i metryki wszystkich instancji. Wykrywa: najczęściej doinstalowywane pakiety → proponuje dodanie do bazowego obrazu. Najczęściej zmieniane settings → proponuje nowe defaults. Powtarzające się błędy firewalla → proponuje rozszerzenie allowlisty.

### F12.3 Template generation
**Akceptacja:** Po zakończeniu projektu w instancji → platform-engineer analizuje finalny stan workspace i generuje nowy template (`TEMPLATE=`) z tego projektu. Szablony ewoluują na podstawie realnych projektów, nie są pisane ręcznie.

## Faza 13 — Distributed Compute

### F13.1 Multi-machine orchestration
**Akceptacja:** Instancje na różnych fizycznych maszynach (workstation, laptop, RPi) w tej samej sieci lokalnej tworzą klaster. Zadania wymagające GPU automatycznie routowane do maszyny z GPU. Lekkie zadania (lint, testy) → dowolna wolna maszyna.

### F13.2 Work migration
**Akceptacja:** Przenosisz laptopa z kawiarni do domu → instancja na laptopie deleguje ciężkie buildy do workstationa w domu automatycznie (po wykryciu sieci). Zero ręcznej konfiguracji — discovery przez mDNS/Bonjour.

### F13.3 Resource pooling
**Akceptacja:** Klaster raportuje łączne zasoby (CPU/RAM/GPU). Architect instancja podejmuje decyzje o alokacji: "ten build wymaga 16GB RAM → uruchom na workstationie". Dashboard (F9) pokazuje klaster jako całość, nie poszczególne maszyny.

## Faza 14 — Persistent AI Memory

### F14.1 Cross-project knowledge
**Akceptacja:** Nowa instancja dla projektu Next.js → automatycznie ładuje learned patterns z poprzednich projektów Next.js (architektura, najczęstsze problemy, preferowane biblioteki). Wiedza przechowywana w `~/.sztauer/memory/` jako indeksowane embeddingi.

### F14.2 Personal coding style
**Akceptacja:** System uczy się preferencji użytkownika: naming conventions, architektura, code review patterns, preferowane narzędzia. Nowa instancja od startu zna styl użytkownika bez CLAUDE.md — bo pamięta z poprzednich sesji.

### F14.3 Organizational knowledge base
**Akceptacja:** Wiele instancji w ramach jednego użytkownika buduje współdzieloną bazę wiedzy: API patterns, deployment procedures, troubleshooting guides. Claude Code w dowolnej instancji może odpytać bazę: "jak deployowaliśmy serwis X ostatnio?".

## Faza 15 — Full Product Lifecycle

### F15.1 Idea → Production
**Akceptacja:** Użytkownik opisuje produkt w jednym zdaniu. System: spinuje team topology (F11), projektuje architekturę, implementuje, pisze testy, deployuje na staging (Dockerfile + compose w repo), uruchamia smoke testy. Użytkownik widzi działającą aplikację i iteruje feedbackiem.

### F15.2 Continuous autonomous iteration
**Akceptacja:** Po deployu na staging → Tester instancja monitoruje logi i metryki. Wykrywa bugi i regresje. Otwiera issue → Architect priorytetyzuje → Backend/Frontend fixuje → Reviewer sprawdza → auto-deploy. Cykl bez ludzkiej interwencji (z opcją veto).

### F15.3 Multi-product management
**Akceptacja:** Użytkownik zarządza portfelem produktów. Każdy produkt to osobny team topology. Dashboard (F9) rozszerzony o widok portfela: statusy produktów, metryki, aktywne prace. Użytkownik jest CEO swoich produktów, nie programistą.
