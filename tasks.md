# Plan implementacji — Sztauer

## Zasady realizacji

- Jeden task = jeden commit z opisowym message.
- Po każdej fazie: test potwierdzający kryterium akceptacji.

## Podjęte decyzje techniczne

- **Edytor:** code-server (port wewnętrzny) — VS Code w przeglądarce
- **Bazowy obraz:** debian:bookworm-slim — Claude Code przez natywny installer, Node osobno
- **Web terminal:** ttyd — binarny C, zero deps runtime, xterm.js frontend
- **Firewall:** iptables default-deny + allowlista
- **Port kontenera:** 420
- **Auth:** Claude Max OAuth (nie API key)
- **Dockerfile:** multi-stage build (builder → slim final)

---

## Faza 1 — Obraz bazowy

- [ ] **T1.1** Dockerfile multi-stage: builder (kompilacja ttyd, code-server, extensions) → final (debian:bookworm-slim + runtime deps)
- [ ] **T1.2** Claude Code CLI: natywny installer. Jeśli segfault na AMD64 (#12044) → fallback npm install.
- [ ] **T1.3** Entrypoint: start firewall → proxy → code-server → ttyd → workspace init
- [ ] **T1.4** Konfiguracja code-server: `--auth none`, `--disable-getting-started-override`, workspace = `~`, pre-installed pluginy, settings.json
- [ ] **T1.5** Konfiguracja Claude Code: dangerous mode, max thinking budget, max research effort
- [ ] **T1.6** Konfiguracja firewall: iptables default-deny + allowlista (Anthropic, npm, PyPI, GitHub, etc.). Ruch w sieci `sztauer` dozwolony.
- [ ] **T1.7** Healthcheck: sprawdza code-server + ttyd
- [ ] **T1.8** Sieć `sztauer`: entrypoint tworzy sieć jeśli nie istnieje, kontener dołącza automatycznie
- [ ] **T1.9** Test: `docker run -d -p 420:420 --network sztauer sztauer` → kontener startuje, healthcheck przechodzi, widoczny w sieci dla innych instancji

**Kamień milowy:** Kontener działa. Serwisy startują. Firewall aktywny. Jeszcze bez split screen i routingu.

---

## Faza 2 — Split screen i routing

- [ ] **T2.1** Reverse proxy wewnętrzny: `/sztauer*` → workspace serwisy, `/` → port aplikacji
- [ ] **T2.2** Strona split screen (`/sztauer`): HTML + CSS grid 50/50. Lewy iframe: code-server. Prawy iframe: ttyd.
- [ ] **T2.3** code-server pod `/sztauer/editor` — poprawne base URL, assets, WebSocket
- [ ] **T2.4** ttyd pod `/sztauer/terminal` — uruchamia `claude --dangerously-skip-permissions`
- [ ] **T2.5** Port aplikacji: `/` → wewnętrzny port (np. 3000). Placeholder gdy nic nie nasłuchuje.
- [ ] **T2.6** Test: `localhost:420/sztauer` → split screen działa. `localhost:420` → placeholder. Claude Code stawia serwer → `localhost:420` serwuje aplikację.

**Kamień milowy:** Split screen działa. VS Code i Claude Code obok siebie. Port aplikacji wolny i routowany.

---

## Faza 3 — Domyślne instrukcje + auth

- [ ] **T3.1** `workspace-template/CLAUDE.md`: informacje o środowisku, narzędziach, portach, firewallu
- [ ] **T3.2** Entrypoint: kopiuje CLAUDE.md do `~` jeśli nie istnieje
- [ ] **T3.3** Persystencja tokenu Claude Max: volume na `~/.claude/`
- [ ] **T3.4** Test: nowy kontener → `~/CLAUDE.md` obecny. Claude Code go czyta. Login → token zachowany po restart.

**Kamień milowy:** Każda instancja ma instrukcje. Claude Max login działa i persystuje.

---

## Faza 4 — Publikacja

- [ ] **T4.1** CI/CD: GitHub Actions multi-arch build + push Docker Hub
- [ ] **T4.2** README: `docker run -d -p 420:420 --network sztauer sztauer` → `localhost:420/sztauer` → login → praca
- [ ] **T4.3** Smoke test end-to-end: docker run → split screen → login → Claude koduje → aplikacja pod `localhost:420`. <2 minuty.

**Kamień milowy:** Obraz na Docker Hub. Jedna komenda od zera do gotowego środowiska.

---

## Faza 5 — Multi-project

- [ ] **T5.1** compose.yml: parametryzowany PROJECT_NAME, labele, named volumes
- [ ] **T5.2** infra.yml: reverse proxy z subdomenami `{name}.localhost`
- [ ] **T5.3** compose.gpu.yml: GPU override
- [ ] **T5.4** Test: dwa projekty jednocześnie pod subdomenami

**Kamień milowy:** Wiele projektów jednocześnie z subdomenami. Opcjonalne — tryb prosty jest domyślny.

---

## Faza 6 — Snapshot & Restore

- [ ] **T6.1** Skrypt/instrukcja snapshot: `docker commit` + metadata labels (services, packages, claude session state)
- [ ] **T6.2** Named snapshots z labelami `sztauer.snapshot=<name>`
- [ ] **T6.3** Test: snapshot na maszynie A → transfer → restore na maszynie B → identyczny stan

**Kamień milowy:** Przenośne środowiska. Snapshot pracy z laptopa → kontynuacja na workstationie.

---

## Faza 7 — Project Templates

- [ ] **T7.1** Katalog `templates/` w repo: nextjs, python-api, fullstack, etc. Każdy template = pliki workspace + CLAUDE.md ze stack-specific instrukcjami
- [ ] **T7.2** Env var `TEMPLATE=<name>`: entrypoint kopiuje template do `~/` jeśli workspace pusty
- [ ] **T7.3** Custom template z URL: `TEMPLATE=https://github.com/user/template` → klonuje repo
- [ ] **T7.4** Test: `docker run -e TEMPLATE=nextjs ... sztauer` → workspace z gotowym Next.js scaffoldem, Claude Code czyta stack-specific CLAUDE.md

**Kamień milowy:** Nowy projekt w znanym stacku gotowy do pracy w sekundy.

---

## Faza 8 — Service Discovery

- [ ] **T8.1** Labele serwisów: `sztauer.services=api:3000,ws:8080` na kontenerach
- [ ] **T8.2** Entrypoint: auto-generuje sekcję w `~/CLAUDE.md` z listą dostępnych serwisów w sieci (Docker API read-only)
- [ ] **T8.3** Health-aware: serwisy z unhealthy kontenerów oznaczone jako niedostępne
- [ ] **T8.4** Test: instancja A rozgłasza `api:3000` → instancja B widzi to w swoim CLAUDE.md → Claude Code w B wie jak dotrzeć do API

**Kamień milowy:** Instancje świadome siebie nawzajem. Claude Code w każdej instancji wie jakie serwisy są dostępne.

---

## Faza 9 — Observability

- [ ] **T9.1** Template `dashboard`: Sztauer instancja-meta. HTML dashboard na `/` pokazujący aktywne instancje, health, resources, serwisy.
- [ ] **T9.2** Activity feed: WebSocket stream zmian plików, komend, startów serwisów z każdej instancji
- [ ] **T9.3** Resource monitoring: CPU/RAM per instancja (Docker stats API)
- [ ] **T9.4** Test: dashboard widzi 3 instancje, ich serwisy, resource usage w real-time

**Kamień milowy:** Widok z lotu ptaka na wszystkie instancje. Monitoring bez wchodzenia do poszczególnych kontenerów.

---

## Faza 10 — Plugin System

- [ ] **T10.1** Struktura pluginu: `plugins/<name>/manifest.json` + pliki (CLAUDE.md fragment, VS Code extensions, firewall rules, hooki)
- [ ] **T10.2** Aktywacja: `-e PLUGINS=typescript,docker` → entrypoint merguje pluginy do workspace
- [ ] **T10.3** Pluginy stackowe: typescript, python, rust, go — extensions + CLAUDE.md + config
- [ ] **T10.4** Community plugins: `-e PLUGINS=github.com/user/plugin` → klonuje i aktywuje
- [ ] **T10.5** Plugin hooks: `on-start.sh`, `on-file-change.sh`, `on-service-start.sh`
- [ ] **T10.6** Test: plugin `typescript` dodaje ESLint/Prettier extensions, CLAUDE.md fragment z TS konwencjami, tsconfig template

**Kamień milowy:** Rozszerzalne środowisko. Społeczność tworzy i dzieli się pluginami.

---

## Faza 11 — Autonomous Teams (horyzont 5-letni)

- [ ] **T11.1** Role instancji: `ROLE=architect|frontend|backend|tester|reviewer` → specjalizowany CLAUDE.md per rola
- [ ] **T11.2** Shared board: `~/shared/board.json` (volume współdzielony) — zadania, statusy, kontrakty API, decyzje
- [ ] **T11.3** Message broker: lekki serwis w sieci `sztauer`. Instancje wysyłają/odbierają taski i updates.
- [ ] **T11.4** Contract-driven dev: Architect definiuje kontrakty (OpenAPI/protobuf) w `~/shared/contracts/`. Inne instancje implementują swoje strony.
- [ ] **T11.5** Human-as-architect: użytkownik rozmawia z Architect instancją, definiuje wizję. Architect deleguje, koordynuje, eskaluje. Użytkownik reviewuje, nie koduje.
- [ ] **T11.6** Test end-to-end: użytkownik opisuje app → Architect dzieli na taski → Backend/Frontend implementują → Tester weryfikuje → Reviewer sprawdza → PR do usera. Cały flow bez ludzkiej interwencji poza ostatecznym review.

**Kamień milowy:** Autonomiczny zespół AI. Użytkownik definiuje wizję, maszyny dostarczają produkt.

---

## Faza 12 — Self-Improving Platform

- [ ] **T12.1** Rola `platform-engineer`: instancja monitorująca repo Sztauer, proponująca ulepszenia (PR-y z optymalizacjami Dockerfile, entrypoint, defaults)
- [ ] **T12.2** Auto-tuning: analiza logów i metryk → rekomendacje (pakiety do bazowego obrazu, settings defaults, allowlista)
- [ ] **T12.3** Auto-generowanie templates: po zakończeniu projektu → platform-engineer tworzy template z finalnego stanu workspace
- [ ] **T12.4** Test: platform-engineer instancja otwiera PR do repo Sztauer z uzasadnioną zmianą. Zmiana przechodzi review.

**Kamień milowy:** Platforma ulepsza samą siebie. Szablony ewoluują z realnych projektów.

---

## Faza 13 — Distributed Compute

- [ ] **T13.1** Discovery maszyn w sieci lokalnej (mDNS/Bonjour). Maszyny z Sztauer widzą się automatycznie.
- [ ] **T13.2** Resource pooling: łączne zasoby klastra (CPU/RAM/GPU). Dashboard pokazuje klaster jako całość.
- [ ] **T13.3** Routing zadań: GPU-heavy → workstation, lekkie → dowolna wolna maszyna. Automatyczne, bez konfiguracji.
- [ ] **T13.4** Work migration: instancja deleguje build do innej maszyny po wykryciu lepszych zasobów w sieci.
- [ ] **T13.5** Test: laptop + workstation w jednej sieci. Build z GPU uruchomiony na laptopie → automatycznie zdelegowany do workstationa.

**Kamień milowy:** Klaster domowych maszyn jako jeden pool zasobów. Praca podąża za zasobami.

---

## Faza 14 — Persistent AI Memory

- [ ] **T14.1** Cross-project knowledge: indeksowane embeddingi z poprzednich projektów w `~/.sztauer/memory/`. Nowy projekt Next.js → automatycznie ładuje patterns z poprzednich.
- [ ] **T14.2** Personal coding style: system uczy się preferencji (naming, architektura, narzędzia). Nowa instancja zna styl bez CLAUDE.md.
- [ ] **T14.3** Organizational knowledge base: współdzielona baza wiedzy między instancjami (API patterns, deployment procedures, troubleshooting).
- [ ] **T14.4** Test: nowy projekt w stacku, w którym użytkownik pracował wcześniej → Claude Code od startu stosuje poznane wzorce bez ręcznych instrukcji.

**Kamień milowy:** AI z pamięcią długoterminową. Każdy następny projekt korzysta z wiedzy poprzednich.

---

## Faza 15 — Full Product Lifecycle

- [ ] **T15.1** Idea → Production: jedno zdanie → team topology → architektura → implementacja → testy → staging deploy. Użytkownik widzi działającą aplikację.
- [ ] **T15.2** Continuous autonomous iteration: Tester monitoruje staging → wykrywa bugi → issue → fix → review → auto-deploy. Cykl bez interwencji (z opcją veto).
- [ ] **T15.3** Multi-product management: portfel produktów w dashboardzie. Statusy, metryki, aktywne prace. Użytkownik = CEO, nie programista.
- [ ] **T15.4** Test end-to-end: "Zbuduj mi SaaS do zarządzania fakturami" → po 24h działająca aplikacja na staging z auth, CRUD, dashboardem, testami, CI/CD.

**Kamień milowy:** Od pomysłu do działającego produktu bez pisania kodu. Użytkownik zarządza portfelem produktów.
