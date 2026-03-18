# Plan implementacji — Sztauer

## Zasady realizacji

- Jeden task = jeden commit z opisowym message.
- Po każdej fazie: test potwierdzający kryterium akceptacji.
- Decyzje techniczne (wybór edytora, proxy, portów) podejmowane w momencie implementacji — nie z góry.

---

## Faza 1 — Obraz: kontener z Claude Code

- [ ] **T1.1** Dockerfile: Claude Code CLI + edytor webowy + firewall (allowlista Anthropic). Multi-arch (amd64 + arm64).
- [ ] **T1.2** Entrypoint: walidacja env vars (fail-fast), firewall setup, auto-detection git credentials, inicjalizacja workspace, start edytora
- [ ] **T1.3** compose.yml (template dla użytkownika): parametryzowany `PROJECT_NAME`, named volumes `sztauer-{name}-*`, bind mount workspace, project name `sztauer-{name}`, labele dla Docker Desktop
- [ ] **T1.4** .env.example z dokumentacją wymaganych zmiennych
- [ ] **T1.5** Healthcheck: kontener raportuje stan do Dockera
- [ ] **T1.6** Test: `PROJECT_NAME=myapp docker compose up -d` → kontener startuje, Claude Code działa, edytor dostępny, firewall blokuje niedozwolony ruch. Projekt czytelny w Docker Desktop.

**Kamień milowy:** Gotowy obraz. Jedno polecenie stawia działający kontener z Claude Code i edytorem. Brak routingu — dostęp przez bezpośredni port.

---

## Faza 2 — Routing: subdomeny

- [ ] **T2.1** infra.yml z reverse proxy: sieć `external`, autodiscovery kontenerów przez Docker labels
- [ ] **T2.2** Labele routingu w compose.yml: subdomena edytora `{name}.localhost`
- [ ] **T2.3** Subdomena aplikacji: `{name}-app.localhost` → port HTTP w kontenerze
- [ ] **T2.4** Dynamiczne porty: `{name}-{port}.localhost` → dowolny port
- [ ] **T2.5** Test wieloprojektowy: dwa kontenery jednocześnie, oba pod swoimi subdomenami, oba czytelne w Docker Desktop

**Kamień milowy:** Projekty dostępne w przeglądarce pod przewidywalnymi adresami. Wiele projektów jednocześnie. Docker Desktop jako panel zarządzania.

---

## Faza 3 — Publikacja i hardening

- [ ] **T3.1** CI/CD: automatyczny build multi-arch + push na Docker Hub przy tagu
- [ ] **T3.2** Compose profiles: GPU passthrough jako opcjonalny profil
- [ ] **T3.3** Test na arm64 (RPi lub QEMU) — ten sam obraz, entrypoint dostosowuje się do środowiska
- [ ] **T3.4** Test multi-machine: ta sama para compose.yml + .env na dwóch maszynach → identyczne doświadczenie
- [ ] **T3.5** README: quick start (3 komendy), auto-detection w entrypoincie, FAQ
- [ ] **T3.6** Smoke test end-to-end: `docker compose -f infra.yml up -d` → `PROJECT_NAME=myapp docker compose up -d` → edytor w przeglądarce → Claude Code działa → serwis pod subdomeną. <3 minuty (bez pull).

**Kamień milowy:** Obraz na Docker Hub. Multi-arch. Zero buildu dla użytkownika. Setup nowej maszyny = 3 pliki + 2 komendy.
