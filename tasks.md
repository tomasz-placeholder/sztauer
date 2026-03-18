# Plan implementacji — Sztauer

## Zasady realizacji

- Jeden task = jeden commit z opisowym message.
- Po każdej fazie: test potwierdzający kryterium akceptacji.

## Podjęte decyzje techniczne

- **Edytor:** code-server (port wewnętrzny) — VS Code w przeglądarce
- **Bazowy obraz:** node:20-bookworm
- **Firewall:** iptables default-deny + allowlista
- **Port kontenera:** 420
- **Auth:** Claude Max OAuth (nie API key)

---

## Faza 1 — Obraz bazowy

- [ ] **T1.1** Dockerfile: node:20-bookworm + Claude Code CLI + code-server + web terminal + reverse proxy + iptables
- [ ] **T1.2** Entrypoint: start firewall → proxy → code-server → web terminal → workspace init
- [ ] **T1.3** Konfiguracja code-server: `--auth none`, `--disable-getting-started-override`, workspace = `~`, pre-installed pluginy, settings.json
- [ ] **T1.4** Konfiguracja Claude Code: dangerous mode, max thinking budget, max research effort
- [ ] **T1.5** Konfiguracja firewall: iptables default-deny + allowlista (Anthropic, npm, PyPI, GitHub, etc.). Ruch w sieci `sztauer` dozwolony.
- [ ] **T1.6** Healthcheck: sprawdza code-server + web terminal
- [ ] **T1.7** Sieć `sztauer`: entrypoint tworzy sieć jeśli nie istnieje, kontener dołącza automatycznie
- [ ] **T1.8** Test: `docker run -d -p 420:420 --network sztauer sztauer/sandbox` → kontener startuje, healthcheck przechodzi, widoczny w sieci dla innych instancji

**Kamień milowy:** Kontener działa. Serwisy startują. Firewall aktywny. Jeszcze bez split screen i routingu.

---

## Faza 2 — Split screen i routing

- [ ] **T2.1** Reverse proxy wewnętrzny: `/sztauer*` → workspace serwisy, `/` → port aplikacji
- [ ] **T2.2** Strona split screen (`/sztauer`): HTML + CSS grid 50/50. Lewy iframe: code-server. Prawy iframe: web terminal.
- [ ] **T2.3** code-server pod `/sztauer/editor` — poprawne base URL, assets, WebSocket
- [ ] **T2.4** Web terminal pod `/sztauer/terminal` — uruchamia `claude --dangerously-skip-permissions`
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
- [ ] **T4.2** README: `docker run -d -p 420:420 sztauer/sandbox` → `localhost:420/sztauer` → login → praca
- [ ] **T4.3** Smoke test end-to-end: docker run → split screen → login → Claude koduje → aplikacja pod `localhost:420`. <2 minuty.

**Kamień milowy:** Obraz na Docker Hub. Jedna komenda od zera do gotowego środowiska.

---

## Opcjonalnie — Multi-project

- [ ] **T5.1** compose.yml: parametryzowany PROJECT_NAME, labele, named volumes
- [ ] **T5.2** infra.yml: reverse proxy z subdomenami `{name}.localhost`
- [ ] **T5.3** compose.gpu.yml: GPU override
- [ ] **T5.4** Test: dwa projekty jednocześnie pod subdomenami

**Kamień milowy:** Wiele projektów jednocześnie z subdomenami. Opcjonalne — tryb prosty jest domyślny.
