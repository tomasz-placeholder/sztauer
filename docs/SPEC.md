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

## Opcjonalnie — Multi-project

### F5.1 compose.yml + infra.yml
**Akceptacja:** Dwa projekty jednocześnie. Subdomeny `{name}.localhost`. Nie wymagane — tryb `docker run` jest domyślny.
