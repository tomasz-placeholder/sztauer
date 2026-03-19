# Plan implementacji — Sztauer

## Zasady realizacji

- Jeden task = jeden commit z opisowym message.
- Po każdej fazie: test potwierdzający kryterium akceptacji.
- Testy od pierwszego commita — infrastruktura testowa to concern Fazy 1.
- Każdy commit przechodzi: hadolint + shellcheck + bats + container-structure-test.

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
- [ ] **T1.9** Testing infrastructure: hadolint, shellcheck, bats-core, container-structure-test, trivy w CI
- [ ] **T1.10** `tests/structure-test.yaml`: weryfikacja obrazu (pakiety, ścieżki, uprawnienia, porty, user)
- [ ] **T1.11** `tests/entrypoint.bats`: unit testy entrypoint (workspace init, CLAUDE.md copy, fail-fast)
- [ ] **T1.12** `tests/firewall.bats`: testy firewalla (allowlista pass, deny reszta, sieć sztauer pass)
- [ ] **T1.13** `tests/network.sh`: spinuj 2 kontenery, sprawdź komunikację po nazwie, sprawdź izolację od zewnątrz
- [ ] **T1.14** `tests/smoke.sh`: start → healthcheck → sprawdź porty → stop. Quick sanity check.
- [ ] **T1.15** `.github/workflows/test.yml`: CI pipeline — lint → build → structure-test → bats → trivy → smoke
- [ ] **T1.16** Test integracyjny: `docker run -d -p 420:420 --network sztauer sztauer` → kontener startuje, healthcheck przechodzi, widoczny w sieci

**Kamień milowy:** Kontener działa. Serwisy startują. Firewall aktywny. Pełna infrastruktura testowa w CI.

---

## Faza 2 — Split screen i routing

- [ ] **T2.1** Reverse proxy wewnętrzny: `/sztauer*` → workspace serwisy, `/` → port aplikacji
- [ ] **T2.2** Strona split screen (`/sztauer`): HTML + CSS grid 50/50. Lewy iframe: code-server. Prawy iframe: ttyd.
- [ ] **T2.3** code-server pod `/sztauer/editor` — poprawne base URL, assets, WebSocket
- [ ] **T2.4** ttyd pod `/sztauer/terminal` — uruchamia `claude --dangerously-skip-permissions`
- [ ] **T2.5** Port aplikacji: `/` → wewnętrzny port (np. 3000). Placeholder gdy nic nie nasłuchuje.
- [ ] **T2.6** `tests/routing.sh`: curl testy — `/sztauer` → 200, `/sztauer/editor` → code-server, `/sztauer/terminal` → ttyd, `/` → placeholder (502/200 zależnie od app)
- [ ] **T2.7** `tests/e2e/splitscreen.spec.ts`: Playwright — oba iframe'y renderują, poprawne wymiary 50/50, WebSocket connectivity
- [ ] **T2.8** Test integracyjny: split screen działa, port aplikacji routowany, Claude Code stawia serwer → `localhost:420` serwuje

**Kamień milowy:** Split screen działa. VS Code i Claude Code obok siebie. Port aplikacji wolny. Testy routing + E2E w CI.

---

## Faza 3 — Domyślne instrukcje + auth

- [ ] **T3.1** `workspace-template/CLAUDE.md`: informacje o środowisku, narzędziach, portach, firewallu
- [ ] **T3.2** Entrypoint: kopiuje CLAUDE.md do `~` jeśli nie istnieje
- [ ] **T3.3** Persystencja tokenu Claude Max: volume na `~/.claude/`
- [ ] **T3.4** Test: nowy kontener → `~/CLAUDE.md` obecny. Claude Code go czyta. Login → token zachowany po restart.

**Kamień milowy:** Każda instancja ma instrukcje. Claude Max login działa i persystuje.

---

## Faza 4 — Publikacja

- [x] **T4.1** CI/CD: GitHub Actions multi-arch build + push Docker Hub. Pipeline: lint → build → test → trivy → push.
- [x] **T4.2** Trivy security scan: fail build na CRITICAL CVE. Raport w CI artifacts + SARIF w GitHub Security tab.
- [x] **T4.3** README: `docker run -d -p 420:420 --network sztauer sztauer` → `localhost:420/sztauer` → login → praca
- [x] **T4.4** Smoke test end-to-end: docker run → split screen → app port routing → aplikacja pod `localhost:420`.

**Kamień milowy:** Obraz na Docker Hub. CI z pełnym pipeline testów. Security scan na każdym buildzie.

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

## Faza 11 — Inter-instance Protocol

- [ ] **T11.1** Format wiadomości JSON: `{from, to, type, payload, timestamp}`. Typy: request, response, event, broadcast.
- [ ] **T11.2** Event broadcasting: instancja rozgłasza eventy (file-created, service-started) do sieci sztauer
- [ ] **T11.3** Request/Response: HTTP API na każdej instancji (`POST :420/api/msg`). Timeout + retry.
- [ ] **T11.4** Test: instancja A wysyła request do B → B odpowiada → A widzi odpowiedź w kontekście Claude Code

**Kamień milowy:** Instancje mogą się komunikować. Prymityw do budowania zespołów.

---

## Faza 12 — Shared State

- [ ] **T12.1** Volume `sztauer-shared` montowany w `~/shared/` we wszystkich instancjach
- [ ] **T12.2** Współdzielone repo git w `~/shared/repo/` (bare repo jako volume)
- [ ] **T12.3** Lock protocol: `~/shared/.locks/` — blokowanie plików, automatyczny unlock po timeout
- [ ] **T12.4** Test: instancja A zapisuje plik → instancja B widzi go natychmiast. Dwie instancje nie nadpisują tego samego pliku jednocześnie.

**Kamień milowy:** Instancje współdzielą stan. Fundament koordynacji.

---

## Faza 13 — Autonomous Teams

- [ ] **T13.1** Role: `ROLE=architect|frontend|backend|tester|reviewer` → specjalizowany CLAUDE.md per rola
- [ ] **T13.2** Shared board: `~/shared/board.json` — zadania, statusy, kontrakty, decyzje (lock protocol z F12)
- [ ] **T13.3** Contract-driven dev: Architect → kontrakty w `~/shared/contracts/`. Inne instancje implementują.
- [ ] **T13.4** Human-as-architect: użytkownik ↔ Architect. Architect deleguje reszcie.
- [ ] **T13.5** Test end-to-end: opis app → Architect → Backend/Frontend → Tester → Reviewer → PR. Bez interwencji.

**Kamień milowy:** Autonomiczny zespół AI.

---

## Faza 14 — Team Analytics

- [ ] **T14.1** Metryki per instancja: czas na task, iteracje, testy pass/fail, rozmiar zmian. Logi w `~/shared/metrics/`
- [ ] **T14.2** Bottleneck detection: identyfikacja wąskich gardeł w pipeline zespołu
- [ ] **T14.3** Quality scoring: automatyczny scoring jakości per rola (coverage, lint, review iterations)
- [ ] **T14.4** Test: dashboard wizualizuje metryki 3 instancji. Bottleneck wykryty i zasygnalizowany Architectowi.

**Kamień milowy:** Zespół mierzalny. Architect podejmuje decyzje na danych.

---

## Faza 15 — Playbooks & Recipes

- [ ] **T15.1** Format playbook: markdown w `~/shared/playbooks/`. Opis sprawdzonego wzorca (np. "jak budujemy REST API")
- [ ] **T15.2** Auto-generowanie: po udanym projekcie → system generuje playbook z historii board + git
- [ ] **T15.3** Playbook library: wbudowane (rest-api, nextjs-app, cli-tool) + community z GitHub
- [ ] **T15.4** Test: Architect przypisuje playbook do zadania → instancja wykonawcza czyta i stosuje wzorzec

**Kamień milowy:** Wiedza zespołowa zakodowana w reusable recipes.

---

## Faza 16 — Self-Improving Platform

- [ ] **T16.1** Rola `platform-engineer`: monitoruje repo Sztauer, proponuje PR-y z ulepszeniami
- [ ] **T16.2** Auto-tuning: metryki (F14) → rekomendacje (pakiety, defaults, allowlista)
- [ ] **T16.3** Template + playbook generation z realnych projektów
- [ ] **T16.4** Test: platform-engineer otwiera PR z uzasadnioną zmianą. Zmiana przechodzi review.

**Kamień milowy:** Platforma ulepsza samą siebie.

---

## Faza 17 — Build Cache & Artifacts

- [ ] **T17.1** Współdzielony cache: npm, pip, Docker layers w volume `sztauer-cache`
- [ ] **T17.2** Lokalny artifact registry w sieci sztauer. Instancje publikują/pobierają artefakty.
- [ ] **T17.3** Incremental builds: cache-aware, tylko affected testy i buildy po zmianie
- [ ] **T17.4** Test: drugie `npm install` tego samego pakietu → instant. Build po zmianie 1 pliku → tylko affected.

**Kamień milowy:** Zero redundancji. Buildy szybkie jak pamięć cache pozwala.

---

## Faza 18 — Resource Awareness

- [ ] **T18.1** Resource reporting: CPU, RAM, GPU, disk I/O per instancja. Dane w API lub shared volume.
- [ ] **T18.2** Resource requests: instancja deklaruje potrzeby. System alokuje lub kolejkuje.
- [ ] **T18.3** Graceful degradation: proaktywne zarządzanie przed OOM. Compaction, cleanup, warning.
- [ ] **T18.4** Test: instancja bliska limitu RAM → automatyczna reakcja zamiast OOM-kill.

**Kamień milowy:** Instancje świadome swoich zasobów. Fundament distributed compute.

---

## Faza 19 — Distributed Compute

- [ ] **T19.1** mDNS/Bonjour discovery maszyn w sieci lokalnej
- [ ] **T19.2** Resource pooling: łączne zasoby klastra. Dashboard pokazuje klaster jako całość.
- [ ] **T19.3** Routing zadań: GPU-heavy → workstation, lekkie → wolna maszyna
- [ ] **T19.4** Work migration: instancja deleguje build do maszyny z lepszymi zasobami
- [ ] **T19.5** Test: laptop + workstation. GPU build na laptopie → delegowany do workstationa.

**Kamień milowy:** Klaster domowych maszyn. Praca podąża za zasobami.

---

## Faza 20 — Session Recording

- [ ] **T20.1** Zapis sesji Claude Code: prompty, odpowiedzi, komendy, wyniki. JSONL w `~/.sztauer/recordings/`
- [ ] **T20.2** Annotacje: użytkownik/Reviewer ocenia decyzje ("dobra", "zła", "lepiej byłoby...")
- [ ] **T20.3** Pattern extraction: analiza nagrań → powtarzające się wzorce → kandydaci na playbooki
- [ ] **T20.4** Test: 10 nagranych sesji → system identyfikuje 3 powtarzające się wzorce

**Kamień milowy:** Surowy materiał do uczenia. Każda sesja to data point.

---

## Faza 21 — Context Handoff

- [ ] **T21.1** Session summary: instancja generuje markdown podsumowanie (co zrobiła, decyzje, TODO, problemy)
- [ ] **T21.2** Seamless handoff: A kończy → generuje handoff → B startuje z handoffem jako kontekstem
- [ ] **T21.3** Cross-role handoff: Backend → Tester ("zaimplementowałem X, oto edge cases do sprawdzenia")
- [ ] **T21.4** Test: handoff z Backendu do Testera → Tester pisze testy bez odpytywania Backendu

**Kamień milowy:** Czyste przekazywanie pałeczki. Zero utraconej wiedzy.

---

## Faza 22 — Persistent AI Memory

- [ ] **T22.1** Cross-project knowledge: embeddingi w `~/.sztauer/memory/`. Nowy Next.js → patterns z poprzednich.
- [ ] **T22.2** Personal coding style: preferencje użytkownika (naming, architektura). Nowa instancja zna styl.
- [ ] **T22.3** Organizational knowledge base: współdzielona baza (API patterns, deployment, troubleshooting)
- [ ] **T22.4** Test: nowy projekt w znanym stacku → Claude stosuje poznane wzorce bez instrukcji

**Kamień milowy:** AI z pamięcią. Każdy projekt korzysta z wiedzy poprzednich.

---

## Faza 23 — Deployment Pipeline

- [ ] **T23.1** Staging: Claude tworzy Dockerfile + compose → deploy → `staging-{name}.localhost`. Auto-cleanup 24h.
- [ ] **T23.2** Preview deploys: każdy PR → automatyczny preview. Reviewer widzi działającą app.
- [ ] **T23.3** Rollback: one-command przywrócenie poprzedniej wersji. Historia deployów.
- [ ] **T23.4** Test: PR → preview deploy → Reviewer testuje w przeglądarce → merge → staging update

**Kamień milowy:** Kod → działająca aplikacja automatycznie. Reviewer testuje produkt, nie diff.

---

## Faza 24 — Feedback Integration

- [ ] **T24.1** Bug reporting: użytkownik zgłasza bug → task na board. Claude dostaje kontekst (opis, logi, screenshot).
- [ ] **T24.2** Usage analytics: staging zbiera metryki użytkowania. Dane jako kontekst dla instancji.
- [ ] **T24.3** Autonomous fix loop: bug → reprodukcja → fix → review → deploy → weryfikacja. Bez interwencji poza weryfikacją.
- [ ] **T24.4** Test: bug report → fix deployed na staging w <1h bez ludzkiej interwencji

**Kamień milowy:** Feedback loop zamknięty. Bugi fixują się (prawie) same.

---

## Faza 25 — Full Product Lifecycle

- [ ] **T25.1** Idea → Production: jedno zdanie → team topology → architektura → implementacja → testy → staging
- [ ] **T25.2** Continuous autonomous iteration: monitoring → bugi → fix → deploy. Cykl bez interwencji (z opcją veto).
- [ ] **T25.3** Multi-product management: portfel produktów w dashboardzie. Użytkownik = CEO.
- [ ] **T25.4** Test: "Zbuduj SaaS do faktur" → 24h → działająca app z auth, CRUD, dashboard, testy, CI/CD.

**Kamień milowy:** Od pomysłu do produktu bez pisania kodu. Użytkownik zarządza portfelem.
