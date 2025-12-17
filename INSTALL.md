# Instrukcja instalacji - ViTV

## Wymagania wstępne

Przed rozpoczęciem instalacji upewnij się, że masz:
- System operacyjny Ubuntu (lub inny Linux)
- Docker zainstalowany i działający
- Docker Compose zainstalowany
- Uprawnienia root (sudo)

## Instalacja Docker (jeśli nie jest zainstalowany)

```bash
# Pobierz i uruchom skrypt instalacyjny Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Dodaj użytkownika do grupy docker (opcjonalnie, jeśli nie używasz root)
sudo usermod -aG docker $USER
newgrp docker
```

## Instalacja Docker Compose (jeśli nie jest zainstalowany)

```bash
# Pobierz najnowszą wersję Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

# Nadaj uprawnienia do wykonania
sudo chmod +x /usr/local/bin/docker-compose

# Sprawdź instalację
docker-compose --version
```

## Proces instalacji

### Krok 1: Pobranie projektu

```bash
# Jeśli masz projekt w repozytorium Git
git clone <url-repozytorium>
cd ViTV

# Lub skopiuj pliki projektu do wybranego katalogu
```

### Krok 2: Uruchomienie skryptu instalacyjnego

```bash
# Nadaj uprawnienia do wykonania (jeśli potrzebne)
chmod +x install.sh

# Uruchom skrypt jako root
sudo ./install.sh
```

### Krok 3: Konfiguracja interaktywna

Skrypt poprosi Cię o następujące informacje:

1. **Nazwa użytkownika** (domyślnie: `vitv`)
   - Skrypt utworzy dedykowanego użytkownika systemowego
   - Jeśli użytkownik już istnieje, możesz wybrać użycie istniejącego

2. **Ścieżka instalacji** (domyślnie: `/opt/vitv`)
   - Możesz wybrać dowolną ścieżkę, np. `/home/vitv/apps` lub `/mnt/storage/vitv`
   - Skrypt automatycznie utworzy wszystkie potrzebne katalogi

3. **Strefa czasowa** (domyślnie: `Europe/Warsaw`)
   - Ustaw odpowiednią strefę czasową dla Twojej lokalizacji

4. **Dane logowania Transmission**
   - Nazwa użytkownika (domyślnie: `admin`)
   - Hasło (domyślnie: `admin`) - **ZMIEŃ TO PO INSTALACJI!**

5. **Link symboliczny** (opcjonalnie)
   - Możesz utworzyć link `/usr/local/bin/vitv` dla łatwego zarządzania

### Krok 4: Co robi skrypt instalacyjny?

Skrypt automatycznie:

✅ **Tworzy użytkownika systemowego**
   - Dedykowany użytkownik dla aplikacji ViTV
   - Dodaje użytkownika do grupy `docker`

✅ **Tworzy strukturę katalogów**
   ```
   /opt/vitv/                    # lub wybrana ścieżka
   ├── config/                   # Konfiguracje aplikacji
   │   ├── jellyfin/
   │   ├── prowlarr/
   │   ├── sonarr/
   │   ├── jellyseerr/
   │   └── transmission/
   ├── media/                    # Gotowe media
   │   ├── tv/                   # Seriale
   │   └── movies/               # Filmy
   ├── downloads/                # Pobierane pliki
   │   └── watch/                # Katalog obserwowany
   └── cache/                    # Cache aplikacji
       └── jellyfin/
   ```

✅ **Ustawia uprawnienia**
   - Wszystkie katalogi należą do utworzonego użytkownika
   - Katalogi konfiguracyjne mają uprawnienia 700 (tylko właściciel)
   - Pozostałe katalogi mają uprawnienia 755

✅ **Konfiguruje docker-compose.yml**
   - Zamienia względne ścieżki na bezwzględne
   - Ustawia odpowiednie ścieżki dla wszystkich wolumenów

✅ **Tworzy plik .env**
   - Automatycznie konfiguruje wszystkie zmienne środowiskowe
   - Ustawia PUID i PGID na podstawie utworzonego użytkownika

✅ **Tworzy skrypt zarządzania**
   - `vitv.sh` - prosty skrypt do zarządzania serwisami
   - Opcjonalnie tworzy link symboliczny w `/usr/local/bin`

### Krok 5: Uruchomienie serwisów

Po zakończeniu instalacji:

```bash
# Przełącz się na utworzonego użytkownika
sudo su - vitv  # lub inna nazwa użytkownika

# Przejdź do katalogu instalacji
cd /opt/vitv  # lub inna wybrana ścieżka

# Uruchom wszystkie serwisy
./vitv.sh start
# lub jeśli utworzono link:
vitv start
```

## Weryfikacja instalacji

### Sprawdzenie statusu serwisów

```bash
vitv status
# lub
docker-compose ps
```

Wszystkie serwisy powinny być w stanie "Up".

### Sprawdzenie logów

```bash
vitv logs
# lub dla konkretnego serwisu:
vitv logs sonarr
```

### Dostęp do aplikacji

Po uruchomieniu, aplikacje będą dostępne pod:

- **Jellyfin**: http://localhost:8096
- **Prowlarr**: http://localhost:9696
- **Sonarr**: http://localhost:8989
- **Jellyseerr**: http://localhost:5055
- **Transmission**: http://localhost:9091

## Zarządzanie po instalacji

### Podstawowe komendy

```bash
# Uruchomienie
vitv start

# Zatrzymanie
vitv stop

# Restart
vitv restart

# Status
vitv status

# Logi
vitv logs [nazwa_serwisu]

# Aktualizacja
vitv update
```

### Zmiana hasła Transmission

1. Otwórz http://localhost:9091
2. Zaloguj się używając domyślnych danych
3. Przejdź do Settings → Remote Access
4. Zmień hasło

Lub edytuj plik `.env` i zrestartuj Transmission:

```bash
nano .env  # Zmień TRANSMISSION_PASS
vitv restart transmission
```

### Zmiana uprawnień katalogów

Jeśli potrzebujesz zmienić uprawnienia:

```bash
# Jako root
sudo chown -R vitv:vitv /opt/vitv
sudo chmod -R 755 /opt/vitv
sudo chmod 700 /opt/vitv/config/*
```

## Rozwiązywanie problemów

### Problem: "Permission denied" przy uruchamianiu Docker

**Rozwiązanie:**
```bash
# Dodaj użytkownika do grupy docker
sudo usermod -aG docker vitv
newgrp docker
```

### Problem: Aplikacje nie mogą zapisywać plików

**Rozwiązanie:**
```bash
# Sprawdź właściciela katalogów
ls -la /opt/vitv

# Ustaw właściciela (zastąp vitv swoim użytkownikiem)
sudo chown -R vitv:vitv /opt/vitv
```

### Problem: Kontenery nie mogą się komunikować

**Rozwiązanie:**
- Upewnij się, że wszystkie kontenery są uruchomione: `vitv status`
- Sprawdź logi: `vitv logs`
- Upewnij się, że używasz nazw kontenerów (np. `http://sonarr:8989`) zamiast `localhost`

### Problem: Porty są już zajęte

**Rozwiązanie:**
Edytuj `docker-compose.yml` i zmień mapowanie portów:

```yaml
ports:
  - "8097:8096"  # Zamiast 8096:8096
```

### Odinstalowanie

```bash
# Zatrzymaj i usuń kontenery
cd /opt/vitv
vitv stop
docker-compose down -v

# Usuń katalog instalacji (UWAGA: usuwa wszystkie dane!)
sudo rm -rf /opt/vitv

# Usuń użytkownika (opcjonalnie)
sudo userdel -r vitv

# Usuń link symboliczny (jeśli utworzono)
sudo rm /usr/local/bin/vitv
```

## Bezpieczeństwo

⚠️ **WAŻNE ZALECENIA:**

1. **Zmień domyślne hasła** - szczególnie Transmission
2. **Ogranicz dostęp do portów** - użyj firewall (UFW)
   ```bash
   sudo ufw allow 8096/tcp  # Jellyfin
   sudo ufw allow 9696/tcp  # Prowlarr
   # itd.
   ```
3. **Użyj reverse proxy** - dla produkcji rozważ Nginx z SSL
4. **VPN dla Transmission** - rozważ użycie VPN dla bezpieczeństwa
5. **Regularne aktualizacje** - uruchamiaj `vitv update` regularnie

## Wsparcie

W razie problemów:
- Sprawdź logi: `vitv logs`
- Sprawdź status: `vitv status`
- Przeczytaj README.md dla szczegółów konfiguracji aplikacji
- Sprawdź dokumentację poszczególnych aplikacji


