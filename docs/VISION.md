# Wizja — Sztauer

## Problem

Claude Code działa bezpośrednio na maszynie deweloperskiej. Nie ma izolacji, nie ma powtarzalności, nie ma prostego sposobu żeby zobaczyć efekty pracy AI w przeglądarce. Postawienie nowego środowiska to za każdym razem ręczny setup — inny na każdej maszynie, inny przy każdym projekcie.

## Przyczyna źródłowa

Brak gotowego obrazu Docker, który jedną komendą daje gotowe środowisko pracy: edytor, Claude Code CLI w przeglądarce, port na wystawianie aplikacji — bez kluczy API, bez plików, bez konfiguracji.

## Rozwiązanie

Sztauer to obraz Docker. Jedna komenda:

```bash
docker run -d -p 420:420 --name myapp sztauer/sandbox
```

Otwierasz `localhost:420/sztauer` — split screen: VS Code po lewej, Claude Code CLI po prawej. Oba w tym samym katalogu. Przy pierwszym uruchomieniu logujesz się przez Claude Max w przeglądarce — token zapamiętany, kolejne starty bez logowania.

`localhost:420` jest wolny — to port na Twoją aplikację. Cokolwiek Claude Code postawi (dashboard, API, frontend) — jest od razu dostępne pod tym adresem.

## Zasady projektowe

1. **Jedna komenda, zero konfiguracji.** `docker run -p 420:420`. Żadnych kluczy API, żadnych plików, żadnych env vars. Logowanie przez przeglądarkę przy pierwszym użyciu.

2. **Gotowe środowisko od startu.** VS Code bez ekranu powitalnego, z zainstalowanymi pluginami i ustawieniami. Claude Code w dangerous mode z maxem effortu i thinkingu. Zero ręcznej konfiguracji narzędzi.

3. **Port aplikacji wolny.** `/sztauer` to workspace. `/` to Twoja aplikacja. Claude Code stawia serwer → od razu widoczny pod `localhost:420`.

4. **Kontener wie gdzie jest.** Domyślny CLAUDE.md w workspace informuje Claude Code o środowisku: jakie narzędzia ma, gdzie jest, jakie porty są dostępne, co może a czego nie.

5. **Docker Desktop jako first-class UI.** Czytelne nazwy, healthcheck, logi, play/stop.

6. **Jeden obraz, wiele maszyn.** Ten sam obraz na workstation, laptopie i RPi (multi-arch). Token Claude Max persystowany w volume.

## Nie-cele

- **Nie wymaga klucza API.** Autentykacja przez Claude Max (OAuth w przeglądarce).
- **Nie wymaga żadnych plików.** Jedna komenda docker run.
- **Nie jest platformą zespołową.** Jeden użytkownik, wiele maszyn.
