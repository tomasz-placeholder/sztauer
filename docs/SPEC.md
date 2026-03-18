# Specyfikacja — Sztauer

## Użytkownik

Developer z subskrypcją Claude Max. Chce odpalić izolowane środowisko jedną komendą docker run — bez kluczy API, bez plików, bez konfiguracji. Otwiera przeglądarkę, loguje się raz, pracuje. Efekty pracy Claude'a widoczne pod `localhost:420`.

## Faza 1 — Obraz: kontener z Claude Code

### F1.1 — Dockerfile

Obraz z Claude Code CLI, code-server, web terminal, reverse proxy i firewallem. Bazowy obraz: node:20-bookworm. Multi-arch (amd64 + arm64).

**Akceptacja:** `docker run -d -p 420:420 --network sztauer --name myapp sztauer/sandbox` → kontener startuje. `localhost:420/sztauer` otwiera split screen. Kontener widoczny dla innych instancji po nazwie.

### F1.2 — Entrypoint

Start serwisów: firewall, reverse proxy, code-server, web terminal. Inicjalizacja workspace (domyślny CLAUDE.md jeśli brak).

**Akceptacja:** Po starcie wszystkie serwisy działają. Healthcheck przechodzi. Logi czytelne w Docker Desktop.

### F1.3 — Autentykacja Claude Max

Claude Code CLI uruchamia się w web terminalu. Przy pierwszym użyciu wymaga logowania przez przeglądarkę (OAuth). Token persystowany w Docker volume.

**Akceptacja:** Pierwsze uruchomienie → Claude prosi o login → użytkownik loguje się → token zapamiętany. Restart kontenera → Claude działa bez ponownego logowania (jeśli volume zachowany).

### F1.4 — Firewall

iptables default-deny z allowlistą domen. `cap_add: NET_ADMIN` (lub odpowiednik w docker run).

**Akceptacja:** Ruch do domen poza allowlistą blokowany. Ruch do allowlisty (Anthropic, npm, PyPI, GitHub) przepuszczany. Ruch wewnątrz sieci `sztauer` dozwolony.

### F1.5 — Healthcheck

Kontener sprawdza czy code-server i web terminal działają.

**Akceptacja:** `docker ps` i Docker Desktop pokazują healthy/unhealthy.

## Faza 2 — Split screen: `/sztauer`

### F2.1 — Strona split screen

Strona HTML pod `/sztauer`. CSS grid 50/50. Lewa kolumna: code-server. Prawa kolumna: web terminal z Claude Code.

**Akceptacja:** `localhost:420/sztauer` wyświetla dwa panele obok siebie, każdy zajmuje 50% szerokości. Responsywne — działa na różnych rozdzielczościach.

### F2.2 — code-server (lewa kolumna)

VS Code w przeglądarce. Bez welcome screen. Workspace: katalog domowy. Pre-installed pluginy. Pre-configured settings.

**Akceptacja:** Po otwarciu → pusty edytor gotowy do pracy. Brak ekranu powitalnego. Explorer widzi pliki w `~`. Pluginy zainstalowane (ESLint, Prettier, GitLens — lub inne ustalone w implementacji). Theme, font size, minimap — skonfigurowane.

### F2.3 — Claude Code CLI (prawa kolumna)

Web terminal z uruchomionym Claude Code. Dangerous mode. Max thinking budget. Max research effort.

**Akceptacja:** Po otwarciu → terminal z działającym `claude`. Dangerous mode aktywny (bez pytania o uprawnienia). Thinking budget na max. Research na thorough. Folder roboczy = `~` (ten sam co code-server).

### F2.4 — Wspólny workspace

Oba panele operują na tym samym katalogu domowym (`~`). Pliki tworzone przez Claude Code widoczne natychmiast w VS Code (i odwrotnie).

**Akceptacja:** Claude tworzy plik → widoczny w VS Code bez refresha. Edycja pliku w VS Code → Claude widzi zmiany.

## Faza 3 — Port aplikacji

### F3.1 — Routing wewnętrzny

Reverse proxy na porcie 420. `/sztauer*` → serwisy workspace. `/` → port aplikacji wewnątrz kontenera.

**Akceptacja:** Claude Code uruchamia `python3 -m http.server 3000` → `localhost:420` serwuje odpowiedź. `localhost:420/sztauer` nadal działa jako workspace.

### F3.2 — Domyślna strona

Gdy żadna aplikacja nie nasłuchuje → `/` pokazuje stronę informacyjną ("Twoja aplikacja tu się pojawi" + instrukcje).

**Akceptacja:** Przed uruchomieniem jakiejkolwiek aplikacji → `localhost:420` pokazuje placeholder. Po uruchomieniu serwera → placeholder zastąpiony przez aplikację.

## Faza 4 — Domyślne instrukcje

### F4.1 — Domyślny CLAUDE.md

Każda nowa instancja dostaje `~/CLAUDE.md` z informacjami o środowisku: lokalizacja, dostępne narzędzia, porty, firewall, persystencja.

**Akceptacja:** Nowy kontener z pustym workspace → `~/CLAUDE.md` obecny. Claude Code czyta go automatycznie. Informacje aktualne i przydatne. Jeśli workspace ma już CLAUDE.md → nie nadpisywany.

## Faza 5 — Publikacja

### F5.1 — CI/CD

GitHub Actions: multi-arch build + push na Docker Hub przy tagu.

**Akceptacja:** Push tagu → obraz na Docker Hub dla amd64 i arm64.

### F5.2 — README

Quick start: 1 komenda. Opis co daje. Opis split screen. FAQ (logowanie, persystencja, GPU).

**Akceptacja:** Nowy użytkownik: `docker run` → `localhost:420/sztauer` → login → praca. <2 minuty (bez pull).

## Opcjonalne rozszerzenia (multi-project)

### Compose z subdomenami

Dla wielu projektów jednocześnie — opcjonalny `compose.yml` + `infra.yml`. Subdomeny: `{name}.localhost` → split screen projektu. `{name}-app.localhost` → aplikacja projektu.

Nie jest wymagany. Tryb prosty (`docker run`) jest domyślnym doświadczeniem.

## Wymagania niefunkcjonalne

- **Czas startu:** kontener gotowy w <30 sekund (obraz pobrany).
- **Zero konfiguracji:** `docker run -p 420:420` wystarczy. Brak env vars, brak plików.
- **Multi-arch:** amd64 + arm64.
- **Docker Desktop:** czytelna nazwa, healthcheck, logi.
- **Bezpieczeństwo:** firewall default-deny. Brak Docker socket.
- **Persystencja:** token Claude Max w volume. Workspace opcjonalnie w bind mount.
