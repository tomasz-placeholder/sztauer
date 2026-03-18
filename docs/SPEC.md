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

## Faza 11 — Inter-instance Protocol

### F11.1 Format wiadomości
**Akceptacja:** Standardowy JSON format wiadomości między instancjami: `{from, to, type, payload, timestamp}`. Typy: `request`, `response`, `event`, `broadcast`. Wysyłanie przez HTTP w sieci `sztauer`.

### F11.2 Event broadcasting
**Akceptacja:** Instancja rozgłasza eventy (`file-created`, `service-started`, `test-passed`) do wszystkich instancji w sieci. Odbiór opcjonalny — instancja subskrybuje typy eventów które ją interesują.

### F11.3 Request/Response
**Akceptacja:** Instancja A wysyła request do instancji B (`POST http://backend:420/api/msg`). B odpowiada. Claude Code w A widzi odpowiedź jako kontekst. Timeout + retry przy braku odpowiedzi.

## Faza 12 — Shared State

### F12.1 Współdzielony volume
**Akceptacja:** Volume `sztauer-shared` montowany w `~/shared/` we wszystkich instancjach. Pliki widoczne natychmiast we wszystkich instancjach. Conflict resolution: last-write-wins z logiem zmian.

### F12.2 Współdzielone repo git
**Akceptacja:** `~/shared/repo/` to bare git repo zamontowane jako volume. Instancje commitują i pullują. Claude Code w każdej instancji widzi historię zmian innych instancji.

### F12.3 Lock protocol
**Akceptacja:** Instancja może zablokować plik w shared (`~/shared/.locks/`). Inne instancje widzą lock i czekają lub pracują nad czymś innym. Automatyczny unlock po timeout.

## Faza 13 — Autonomous Teams

### F13.1 Rola instancji
**Akceptacja:** Env var `ROLE=architect|frontend|backend|tester|reviewer`. Każda rola dostaje specjalizowany CLAUDE.md z instrukcjami odpowiednimi do roli. Architect planuje i dzieli zadania. Frontend/Backend implementują. Tester pisze i uruchamia testy. Reviewer robi code review.

### F13.2 Shared project board
**Akceptacja:** `~/shared/board.json` — zadania, statusy, kontrakty API, decyzje architektoniczne. Każda instancja czyta i aktualizuje board przez lock protocol (F12.3).

### F13.3 Contract-driven development
**Akceptacja:** Architect definiuje kontrakty API (OpenAPI, protobuf, TypeScript types) w `~/shared/contracts/`. Inne instancje implementują swoje strony kontraktu. Tester weryfikuje zgodność.

### F13.4 Human-as-architect
**Akceptacja:** Użytkownik rozmawia wyłącznie z Architect. Definiuje wizję i priorytety. Architect deleguje. Użytkownik reviewuje rezultaty, nie pisze kodu.

## Faza 14 — Team Analytics

### F14.1 Metryki zespołu
**Akceptacja:** Każda instancja loguje: czas na task, ilość iteracji, testy pass/fail, rozmiar zmian. Logi w `~/shared/metrics/`. Dashboard (F9) wizualizuje.

### F14.2 Bottleneck detection
**Akceptacja:** System identyfikuje wąskie gardła: "Reviewer blokuje pipeline — 3 PR-y czekają >1h". Architect dostaje alert i może przeorganizować.

### F14.3 Quality scoring
**Akceptacja:** Automatyczny scoring jakości per instancja: test coverage, lint warnings, review iterations. Architect widzi kto potrzebuje lepszych instrukcji.

## Faza 15 — Playbooks & Recipes

### F15.1 Playbook jako template
**Akceptacja:** `~/shared/playbooks/rest-api.md` opisuje sprawdzony wzorzec: "jak budujemy REST API". Architect przypisuje playbook do zadania → instancja wykonawcza czyta go jako kontekst.

### F15.2 Auto-generowanie playbooks
**Akceptacja:** Po udanym projekcie → system analizuje board, kontrakty, historię git → generuje playbook opisujący co zadziałało. Playbooki ewoluują z realnych doświadczeń.

### F15.3 Playbook library
**Akceptacja:** Katalog `playbooks/` w repo Sztauer. Wbudowane playbooki: `rest-api`, `nextjs-app`, `cli-tool`, `monorepo`. Community playbooks z GitHub.

## Faza 16 — Self-Improving Platform

### F16.1 Dogfooding
**Akceptacja:** Instancja `ROLE=platform-engineer` monitoruje repo Sztauer, proponuje ulepszenia Dockerfile, entrypointa, konfiguracji. Otwiera PR-y — reviewed przez użytkownika.

### F16.2 Auto-tuning
**Akceptacja:** Platform-engineer analizuje metryki (F14) wszystkich instancji. Wykrywa: najczęściej doinstalowywane pakiety → dodaje do obrazu. Najczęstsze błędy firewalla → rozszerza allowlistę. Najczęstsze zmiany settings → nowe defaults.

### F16.3 Template generation
**Akceptacja:** Po zakończeniu projektu → platform-engineer analizuje workspace i generuje nowy template + playbook. Szablony ewoluują z realnych projektów.

## Faza 17 — Build Cache & Artifacts

### F17.1 Współdzielony cache
**Akceptacja:** npm cache, pip cache, Docker layer cache współdzielone między instancjami (volume `sztauer-cache`). Drugie `npm install` tego samego pakietu → instant, bez pobierania.

### F17.2 Artifact registry
**Akceptacja:** Instancja builduje artefakt (Docker image, npm package, binary) → publikuje w lokalnym registry (sieć `sztauer`). Inne instancje pobierają bez rebuildu.

### F17.3 Incremental builds
**Akceptacja:** Zmiana w jednym pliku → tylko affected testy i buildy się uruchamiają. Cache-aware build system wykrywa co się zmieniło i pomija resztę.

## Faza 18 — Resource Awareness

### F18.1 Resource reporting
**Akceptacja:** Każda instancja raportuje swoje zasoby: CPU usage, RAM usage, GPU availability, disk I/O. Dane w `~/shared/resources/` lub przez API.

### F18.2 Resource requests
**Akceptacja:** Instancja może zadeklarować: "potrzebuję 8GB RAM do tego builda". Architect/system sprawdza dostępność i alokuje lub kolejkuje.

### F18.3 Graceful degradation
**Akceptacja:** Instancja bliska limitu RAM → automatyczne compaction, zamknięcie nieużywanych serwisów, ostrzeżenie. Brak OOM-kill — proaktywne zarządzanie.

## Faza 19 — Distributed Compute

### F19.1 Multi-machine orchestration
**Akceptacja:** Instancje na różnych maszynach (workstation, laptop, RPi) w sieci lokalnej tworzą klaster. GPU tasks → workstation. Lekkie tasks → dowolna wolna maszyna.

### F19.2 Work migration
**Akceptacja:** Laptop wykrywa workstation w sieci → deleguje ciężkie buildy automatycznie. Discovery przez mDNS/Bonjour. Zero konfiguracji.

### F19.3 Resource pooling
**Akceptacja:** Klaster raportuje łączne zasoby. Architect podejmuje decyzje o alokacji. Dashboard pokazuje klaster jako całość.

## Faza 20 — Session Recording

### F20.1 Zapis sesji
**Akceptacja:** Każda sesja Claude Code nagrywana: prompty, odpowiedzi, komendy, wyniki, decyzje. Format: JSONL w `~/.sztauer/recordings/`. Replay możliwy.

### F20.2 Annotacje
**Akceptacja:** Użytkownik lub Reviewer mogą annotować nagranie: "ta decyzja była dobra", "tu powinien był użyć innego podejścia". Annotacje jako materiał treningowy.

### F20.3 Pattern extraction
**Akceptacja:** System analizuje nagrania i wyciąga powtarzające się wzorce: "za każdym razem gdy budujesz API, zaczynasz od route handlers". Wzorce stają się kandydatami na playbooki (F15).

## Faza 21 — Context Handoff

### F21.1 Session summary
**Akceptacja:** Instancja generuje podsumowanie swojej sesji: co zrobiła, jakie decyzje podjęła, co zostało do zrobienia, jakie problemy napotkała. Format: markdown w `~/shared/handoffs/`.

### F21.2 Seamless handoff
**Akceptacja:** Instancja A kończy pracę → generuje handoff → instancja B startuje z handoffem jako kontekstem. B kontynuuje pracę A bez utraty wiedzy. Zero ręcznego briefingu.

### F21.3 Cross-role handoff
**Akceptacja:** Backend kończy implementację → generuje handoff dla Tester: "zaimplementowałem X, oto kontrakty, oto edge cases do sprawdzenia". Tester czyta handoff i pisze testy bez odpytywania Backendu.

## Faza 22 — Persistent AI Memory

### F22.1 Cross-project knowledge
**Akceptacja:** Nowa instancja Next.js → automatycznie ładuje learned patterns z poprzednich projektów Next.js. Wiedza w `~/.sztauer/memory/` jako indeksowane embeddingi.

### F22.2 Personal coding style
**Akceptacja:** System uczy się preferencji użytkownika: naming, architektura, narzędzia. Nowa instancja zna styl bez CLAUDE.md.

### F22.3 Organizational knowledge base
**Akceptacja:** Współdzielona baza wiedzy między instancjami: API patterns, deployment procedures, troubleshooting. Claude Code może odpytać: "jak deployowaliśmy serwis X?".

## Faza 23 — Deployment Pipeline

### F23.1 Staging environment
**Akceptacja:** Claude Code w instancji tworzy Dockerfile + compose → `sztauer deploy staging` → aplikacja dostępna pod `staging-{name}.localhost`. Auto-cleanup po 24h.

### F23.2 Preview deploys
**Akceptacja:** Każdy PR od instancji → automatyczny preview deploy. Reviewer widzi działającą aplikację, nie tylko diff kodu.

### F23.3 Rollback
**Akceptacja:** `sztauer rollback {name}` → przywraca poprzednią wersję stagingu. Historia deployów zachowana. One-command recovery.

## Faza 24 — Feedback Integration

### F24.1 Bug reporting
**Akceptacja:** Użytkownik zgłasza bug na staging → trafia jako task na shared board (F13.2). Architect priorytetyzuje i deleguje. Claude Code dostaje kontekst: opis buga, logi, screenshot.

### F24.2 Usage analytics
**Akceptacja:** Staging zbiera metryki użytkowania: jakie strony odwiedzane, jakie akcje wykonywane, jakie błędy w konsoli. Dane dostępne dla instancji jako kontekst do optymalizacji.

### F24.3 Autonomous fix loop
**Akceptacja:** Bug report → Tester reprodukuje → Backend fixuje → Reviewer sprawdza → auto-deploy na staging → użytkownik weryfikuje. Cykl bez ręcznej interwencji poza weryfikacją.

## Faza 25 — Full Product Lifecycle

### F25.1 Idea → Production
**Akceptacja:** Użytkownik opisuje produkt w jednym zdaniu. System spinuje team topology, projektuje architekturę, implementuje, testuje, deployuje na staging. Użytkownik widzi działającą aplikację i iteruje feedbackiem.

### F25.2 Continuous autonomous iteration
**Akceptacja:** Tester monitoruje staging → wykrywa bugi → issue → fix → review → auto-deploy. Cykl bez interwencji (z opcją veto).

### F25.3 Multi-product management
**Akceptacja:** Użytkownik zarządza portfelem produktów. Każdy produkt to osobny team topology. Dashboard z widokiem portfela. Użytkownik jest CEO swoich produktów, nie programistą.
