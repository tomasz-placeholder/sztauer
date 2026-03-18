# Wizja — Sztauer

## Problem

Claude Code działa bezpośrednio na maszynie deweloperskiej. Nie ma izolacji, nie ma powtarzalności, nie ma prostego sposobu żeby zobaczyć efekty pracy AI w przeglądarce. Postawienie nowego środowiska to za każdym razem ręczny setup — inny na każdej maszynie, inny przy każdym projekcie.

Przy kilku maszynach (workstation, laptop, RPi) problem się mnoży: konfiguracja dryfuje, setup trzeba powtarzać, nie ma jednego źródła prawdy o tym jak wygląda środowisko.

## Przyczyna źródłowa

Brak gotowego, samowystarczalnego obrazu Docker, który łączy sandbox wykonawczy, edytor webowy, routing i konfigurację AI w jedną jednostkę — uruchamianą jedną komendą, konfigurującą się automatycznie, identyczną na każdej maszynie.

## Rozwiązanie

Sztauer to gotowy obraz Docker z Claude Code. Użytkownik pobiera obraz z Docker Hub, podaje klucz API, uruchamia kontener — dostaje izolowane środowisko z edytorem webowym, firewallem i Claude Code CLI, dostępne w przeglądarce pod przewidywalną subdomeną.

Kluczowa cecha: **zero konfiguracji**. Entrypoint kontenera sam wykrywa co ma do dyspozycji (git credentials, dostępne narzędzia, zasoby) i konfiguruje środowisko odpowiednio. Użytkownik nie wybiera modułów, nie edytuje configów — podaje klucz API i nazwa projektu, resztę robi kontener.

Współdzielona infrastruktura (reverse proxy) routuje ruch do aktywnych kontenerów. Setup na nowej maszynie to skopiowanie `.env` i `compose.yml` — nie klonowanie repo.

## Zasady projektowe

1. **Gotowy obraz, nie repozytorium.** Użytkownik pobiera obraz z Docker Hub. Nie klonuje repo, nie buduje, nie instaluje. `docker compose up -d` i gotowe.

2. **Auto-detection w runtime.** Entrypoint kontenera wykrywa możliwości środowiska: zamontowane git credentials, dostępne zasoby, zmienne środowiskowe. Konfiguruje się automatycznie — bez flag, bez wybierania modułów.

3. **Docker Desktop jako first-class UI.** Projekty czytelnie nazwane, zgrupowane, z labelami i healthcheck statusem. Logi, volumes, status — wszystko widoczne i zarządzalne przez Docker Desktop. Komendy CLI to standardowe `docker compose`.

4. **Transparentność.** Mimo automatyzacji, wszystko jest standardowym Dockerem. `docker compose`, `docker ps`, Docker Desktop — zero custom tooling. Compose files są krótkie i czytelne.

5. **Jeden obraz, wiele maszyn.** Ten sam obraz Docker Hub działa na workstation, laptopie i RPi. Jedyne co się różni to `.env` (sekrety). Entrypoint dostosowuje się do środowiska automatycznie.

6. **Efemeryczność kontenerów.** Zniszczenie kontenera nie zostawia śladów poza kodem źródłowym na hoście.

## Nie-cele

- **Nie jest orkiestratorem CI/CD.** Nie buduje pipeline'ów, nie deployuje na produkcję.
- **Nie jest platformą zespołową.** Jeden użytkownik, wiele maszyn. Brak multi-tenancy.
- **Nie zarządza projektami.** Nie ma bazy danych, dashboardu ani state'u poza Docker volumes.
- **Nie wymaga custom CLI.** Interfejsem jest `docker compose` i Docker Desktop.
