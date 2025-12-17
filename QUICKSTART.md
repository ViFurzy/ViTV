# Szybki Start - ViTV

## Najszybsza instalacja (3 kroki)

### 1. Uruchom skrypt instalacyjny

```bash
sudo ./install.sh
```

Skrypt poprosi Cię o:
- Nazwę użytkownika (Enter = `vitv`)
- Ścieżkę instalacji (Enter = `/opt/vitv`)
- Strefę czasową (Enter = `Europe/Warsaw`)
- Dane logowania Transmission

### 2. Przełącz się na użytkownika i uruchom

```bash
sudo su - vitv
cd /opt/vitv
vitv start
```

### 3. Otwórz aplikacje

- **Jellyfin**: http://localhost:8096
- **Prowlarr**: http://localhost:9696
- **Sonarr**: http://localhost:8989
- **Jellyseerr**: http://localhost:5055
- **Transmission**: http://localhost:9091

## Podstawowe komendy

```bash
vitv start      # Uruchom
vitv stop       # Zatrzymaj
vitv restart    # Restart
vitv status     # Status
vitv logs       # Logi
vitv update     # Aktualizuj
```

## Co dalej?

1. **Zmień hasło Transmission** - zaloguj się i zmień w ustawieniach
2. **Skonfiguruj aplikacje** - zobacz [README.md](README.md) sekcja "Konfiguracja krok po kroku"
3. **Dodaj indeksery** - w Prowlarr dodaj źródła torrentów
4. **Połącz aplikacje** - skonfiguruj integracje między aplikacjami

## Więcej informacji

- Szczegółowa instalacja: [INSTALL.md](INSTALL.md)
- Pełna dokumentacja: [README.md](README.md)


