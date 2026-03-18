# Plan implementacji — Sztauer

## Zasady realizacji

- Jeden task = jeden commit z opisowym message.
- Po każdej fazie: test potwierdzający kryterium akceptacji.
- Decyzje techniczne (wybór edytora, proxy, portów) podejmowane w momencie implementacji — nie z góry.

## Decyzje techniczne

- **Edytor webowy:** code-server (port 8080) — prosty install, aktywny development, VS Code w przeglądarce
- **Reverse proxy:** Caddy z caddy-docker-proxy — autodiscovery przez Docker labele, zero konfiguracji per-projekt
- **Bazowy obraz:** node:20-bookworm — Node.js potrzebny dla Claude Code, Debian dobrze wspierany
- **Firewall:** iptables default-deny + allowlista resolowana w entrypoincie. Wymaga `cap_add: NET_ADMIN`
- **Dynamiczne porty:** globalny port-router.js w infra.yml. Caddy catch-all → port-router → Docker DNS (`sztauer-{name}-workspace:{port}`)
- **GPU:** compose override file (`compose.gpu.yml`) zamiast profili — czystsze niż dwa serwisy

---

## Faza 1 — Obraz: kontener z Claude Code

- [x] **T1.1** Dockerfile: Claude Code CLI + code-server + iptables firewall. Multi-arch (amd64 + arm64).
- [x] **T1.2** Entrypoint: walidacja env vars (fail-fast), firewall setup, auto-detection git credentials, inicjalizacja workspace, start edytora
- [x] **T1.3** compose.yml (template dla użytkownika): parametryzowany `PROJECT_NAME`, named volumes `sztauer-{name}-*`, bind mount workspace, project name `sztauer-{name}`, labele dla Docker Desktop
- [x] **T1.4** .env.example z dokumentacją wymaganych zmiennych
- [x] **T1.5** Healthcheck: kontener raportuje stan do Dockera
- [x] **T1.6** Test: `PROJECT_NAME=myapp docker compose up -d` → kontener startuje, Claude Code działa, edytor dostępny, firewall blokuje niedozwolony ruch. Projekt czytelny w Docker Desktop.

**Kamień milowy:** Gotowy obraz. Jedno polecenie stawia działający kontener z Claude Code i edytorem. Brak routingu — dostęp przez bezpośredni port.

---

## Faza 2 — Routing: subdomeny

- [x] **T2.1** infra.yml z Caddy docker-proxy + port-router: sieć `external`, autodiscovery przez labele
- [x] **T2.2** Labele routingu w compose.yml: subdomena edytora `{name}.localhost`
- [x] **T2.3** Subdomena aplikacji: `{name}-app.localhost` → port-router → port HTTP w kontenerze
- [x] **T2.4** Dynamiczne porty: `{name}-{port}.localhost` → port-router → dowolny port
- [x] **T2.5** Test wieloprojektowy: dwa kontenery jednocześnie, oba pod swoimi subdomenami, oba czytelne w Docker Desktop

**Kamień milowy:** Projekty dostępne w przeglądarce pod przewidywalnymi adresami. Wiele projektów jednocześnie. Docker Desktop jako panel zarządzania.

---

## Faza 3 — Publikacja i hardening

- [x] **T3.1** CI/CD: GitHub Actions multi-arch build + push na Docker Hub przy tagu
- [x] **T3.2** GPU passthrough: compose.gpu.yml override file
- [ ] **T3.3** Test na arm64 (RPi lub QEMU) — ten sam obraz, entrypoint dostosowuje się do środowiska
- [ ] **T3.4** Test multi-machine: ta sama para compose.yml + .env na dwóch maszynach → identyczne doświadczenie
- [x] **T3.5** README: quick start, auto-detection w entrypoincie
- [x] **T3.6** Smoke test end-to-end: `docker compose -f infra.yml up -d` → `PROJECT_NAME=myapp docker compose up -d` → edytor w przeglądarce → Claude Code działa → serwis pod subdomeną. <3 minuty (bez pull).

**Kamień milowy:** Obraz na Docker Hub. Multi-arch. Zero buildu dla użytkownika. Setup nowej maszyny = 3 pliki + 2 komendy.
