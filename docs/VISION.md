# Wizja — Sztauer

## Problem

Claude Code działa bezpośrednio na maszynie deweloperskiej. Nie ma izolacji, nie ma powtarzalności, nie ma prostego sposobu żeby zobaczyć efekty pracy AI w przeglądarce. Postawienie nowego środowiska to za każdym razem ręczny setup — inny na każdej maszynie, inny przy każdym projekcie.

Przy kilku maszynach (workstation, laptop, RPi) problem się mnoży: konfiguracja dryfuje, setup trzeba powtarzać, nie ma jednego źródła prawdy o tym jak wygląda środowisko.

## Przyczyna źródłowa

Brak gotowego obrazu Docker, który jedną komendą daje izolowane środowisko z Claude Code, edytorem webowym i firewallem — bez plików konfiguracyjnych, bez klonowania repo, bez budowania.

## Rozwiązanie

Sztauer to obraz Docker z Claude Code. Jedna komenda:

```bash
docker run -d -e ANTHROPIC_API_KEY -p 8080:8080 sztauer/sandbox
```

Otwierasz `localhost:8080` — edytor webowy z Claude Code gotowym do pracy. Firewall aktywny. Git skonfigurowany automatycznie (jeśli credentials zamontowane). Zero plików, zero konfiguracji.

Dla wielu projektów jednocześnie — opcjonalny compose z reverse proxy i subdomenami. Ale podstawowe doświadczenie nie wymaga niczego poza Docker i kluczem API.

## Zasady projektowe

1. **Jedna komenda.** `docker run` z kluczem API. Żadnych plików, żadnego klonowania, żadnego builda. Obraz gotowy na Docker Hub.

2. **Auto-detection w runtime.** Entrypoint kontenera wykrywa zamontowane git credentials, dostępne zasoby, zmienne środowiskowe. Konfiguruje się automatycznie — bez flag, bez configów.

3. **Progresywna złożoność.** Jedno środowisko = `docker run`. Wiele środowisk z subdomenami = compose + infra. Każdy poziom jest opcjonalny — wyższy nie wymaga niższego.

4. **Docker Desktop jako first-class UI.** Kontenery z czytelnymi nazwami, healthcheck statusem, przeglądalnymi logami. Start, stop, shell — wszystko przez GUI.

5. **Jeden obraz, wiele maszyn.** Ten sam obraz Docker Hub na workstation, laptopie i RPi (multi-arch). Nie ma konfiguracji maszynowej.

6. **Efemeryczność.** Zniszczenie kontenera nie zostawia śladów poza kodem źródłowym (jeśli zamontowany volume).

## Nie-cele

- **Nie jest orkiestratorem CI/CD.**
- **Nie jest platformą zespołową.** Jeden użytkownik, wiele maszyn.
- **Nie zarządza projektami.** Nie ma bazy danych ani dashboardu.
- **Nie wymaga żadnych plików.** compose.yml jest opcjonalny — convenience, nie wymóg.
