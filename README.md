# ViTV - Kompleksowy System Media Streaming

Kompleksowe rozwiązanie Docker zawierające wszystkie niezbędne narzędzia do zarządzania i streamowania mediów:
- **Jellyfin** - Serwer multimedialny
- **Prowlarr** - Menedżer indekserów
- **Sonarr** - Menedżer seriali TV
- **Jellyseerr** - System żądań dla mediów
- **Transmission** - Klient BitTorrent

## Szybki Start

```bash
# Sklonuj repozytorium
git clone https://github.com/TWOJA_NAZWA/ViTV.git
cd ViTV

# Uruchom instalację
sudo ./install.sh
```

Zobacz [QUICKSTART.md](QUICKSTART.md) dla szybkiego przewodnika lub [INSTALL.md](INSTALL.md) dla szczegółowych instrukcji.

## Wymagania

- Docker (wersja 20.10 lub nowsza)
- Docker Compose (wersja 1.29 lub nowsza)
- Ubuntu (lub inny system Linux)
- Minimum 4GB RAM
- Wolne miejsce na dysku dla mediów
- Uprawnienia root (sudo) dla instalacji

> 💡 **Nowość**: Użyj automatycznego skryptu instalacyjnego `install.sh`, który utworzy użytkownika, skonfiguruje uprawnienia i przygotuje całe środowisko! Zobacz [INSTALL.md](INSTALL.md) dla szczegółowych instrukcji.

## Instalacja

### Opcja 1: Automatyczna instalacja (ZALECANA)

Użyj globalnego skryptu instalacyjnego, który automatycznie:
- Utworzy dedykowanego użytkownika Linux
- Skonfiguruje wszystkie uprawnienia
- Utworzy strukturę katalogów
- Skonfiguruje wszystkie aplikacje
- **Opcjonalnie uruchomi kontenery Docker**
- **Opcjonalnie wyświetli interaktywne instrukcje konfiguracji krok po kroku**

```bash
# Pobierz lub sklonuj projekt
cd /ścieżka/do/projektu

# Uruchom skrypt instalacyjny jako root
sudo ./install.sh
```

Skrypt poprosi Cię o:
- Nazwę użytkownika (domyślnie: `vitv`)
- Ścieżkę instalacji (domyślnie: `/opt/vitv`)
- Strefę czasową (domyślnie: `Europe/Warsaw`)
- Dane logowania do Transmission
- **Czy uruchomić kontenery Docker teraz?** (t/n)
- **Czy wyświetlić instrukcje konfiguracji krok po kroku?** (t/n) - jeśli uruchomiono dockery

> 💡 **Wskazówka**: Jeśli wybierzesz opcję wyświetlenia instrukcji, skrypt przeprowadzi Cię przez konfigurację każdej aplikacji (Transmission, Prowlarr, Sonarr, Jellyfin, Jellyseerr) z dokładnymi krokami i adresami URL.

Po zakończeniu instalacji (jeśli nie uruchomiono dockerów):
```bash
# Przełącz się na utworzonego użytkownika
sudo su - vitv  # lub inna nazwa użytkownika

# Przejdź do katalogu instalacji
cd /opt/vitv  # lub inna ścieżka

# Uruchom serwisy
./vitv.sh start
# lub jeśli utworzono link symboliczny:
vitv start
```

### Opcja 2: Ręczna instalacja

#### 1. Klonowanie/Przygotowanie projektu

```bash
cd /ścieżka/do/projektu
```

#### 2. Konfiguracja zmiennych środowiskowych

```bash
cp env.example .env
nano .env  # lub użyj innego edytora
```

Zaktualizuj wartości w pliku `.env`:
- `PUID` i `PGID` - ID użytkownika i grupy (sprawdź używając `id $USER`)
- `TZ` - Twoja strefa czasowa
- `TRANSMISSION_USER` i `TRANSMISSION_PASS` - dane logowania do Transmission

#### 3. Utworzenie katalogów

```bash
mkdir -p config/{jellyfin,prowlarr,sonarr,jellyseerr,transmission}
mkdir -p media/{tv,movies}
mkdir -p downloads
mkdir -p cache/jellyfin
```

#### 4. Ustawienie uprawnień

```bash
# Ustawienie właściciela katalogów (zastąp 1000:1000 swoimi PUID:PGID)
sudo chown -R 1000:1000 config media downloads cache
```

#### 5. Uruchomienie kontenerów

```bash
docker-compose up -d
```

## Dostęp do aplikacji

Po uruchomieniu, aplikacje będą dostępne pod następującymi adresami:

- **Jellyfin**: http://localhost:8096
- **Prowlarr**: http://localhost:9696
- **Sonarr**: http://localhost:8989
- **Jellyseerr**: http://localhost:5055
- **Transmission**: http://localhost:9091

## Konfiguracja krok po kroku

### 1. Transmission (Klient BitTorrent)

1. Otwórz http://localhost:9091
2. Zaloguj się używając danych z pliku `.env`
3. Przejdź do Settings → Download directories
4. Ustaw katalog pobierania: `/downloads`
5. Włącz "Watch directory": `/watch`

### 2. Prowlarr (Menedżer indekserów)

1. Otwórz http://localhost:9696
2. Przejdź do Settings → Indexers
3. Dodaj indeksery (np. RARBG, 1337x)
4. Przejdź do Settings → Apps
5. Dodaj Sonarr jako aplikację:
   - URL: `http://sonarr:8989`
   - API Key: (znajdziesz w Sonarr → Settings → General → Security)

### 3. Sonarr (Menedżer seriali)

1. Otwórz http://localhost:8989
2. Przejdź do Settings → Media Management
3. Ustaw katalogi:
   - Root Folders: `/tv`
   - Completed Download Handling: `/downloads`
4. Przejdź do Settings → Download Clients
5. Dodaj Transmission:
   - Host: `transmission`
   - Port: `9091`
   - Username/Password: (z pliku `.env`)
6. Przejdź do Settings → Indexers
7. Dodaj Prowlarr:
   - URL: `http://prowlarr:9696`
   - API Key: (znajdziesz w Prowlarr → Settings → General)

### 4. Jellyfin (Serwer multimedialny)

1. Otwórz http://localhost:8096
2. Ukończ proces pierwszego uruchomienia (ustawienia język, użytkownik admin)
3. Przejdź do Dashboard → Libraries
4. Dodaj biblioteki:
   - Movies: `/media/movies`
   - TV Shows: `/media/tv`
5. Uruchom skanowanie bibliotek

### 5. Jellyseerr (System żądań)

1. Otwórz http://localhost:5055
2. Ukończ proces pierwszego uruchomienia
3. Przejdź do Settings → Services
4. Dodaj Jellyfin:
   - URL: `http://jellyfin:8096`
   - API Key: (znajdziesz w Jellyfin → Dashboard → API Keys)
5. Dodaj Sonarr:
   - URL: `http://sonarr:8989`
   - API Key: (znajdziesz w Sonarr → Settings → General → Security)
6. Przejdź do Settings → Users i dodaj użytkowników

## Struktura katalogów

```
ViTV/
├── config/              # Konfiguracje aplikacji
│   ├── jellyfin/
│   ├── prowlarr/
│   ├── sonarr/
│   ├── jellyseerr/
│   └── transmission/
├── media/               # Gotowe media
│   ├── tv/             # Seriale
│   └── movies/         # Filmy
├── downloads/           # Pobierane pliki
│   └── watch/          # Katalog obserwowany przez Transmission
├── cache/              # Cache aplikacji
│   └── jellyfin/
├── docker-compose.yml
├── .env
└── README.md
```

## Zarządzanie

### Używając skryptu zarządzania (jeśli użyto install.sh)

```bash
# Jeśli utworzono link symboliczny:
vitv start      # Uruchom wszystkie serwisy
vitv stop       # Zatrzymaj wszystkie serwisy
vitv restart    # Zrestartuj wszystkie serwisy
vitv status     # Pokaż status serwisów
vitv logs       # Pokaż logi wszystkich serwisów
vitv logs sonarr # Pokaż logi konkretnego serwisu
vitv update     # Zaktualizuj i zrestartuj serwisy
```

### Bezpośrednie użycie docker-compose

```bash
cd /opt/vitv  # lub inna ścieżka instalacji

# Zatrzymanie wszystkich kontenerów
docker-compose down

# Zatrzymanie z usunięciem wolumenów (UWAGA: usuwa konfigurację!)
docker-compose down -v

# Restart konkretnego serwisu
docker-compose restart sonarr

# Wyświetlenie logów
docker-compose logs -f
# lub dla konkretnego serwisu:
docker-compose logs -f sonarr

# Aktualizacja obrazów
docker-compose pull
docker-compose up -d
```

## Rozwiązywanie problemów

### Problem z uprawnieniami
Jeśli aplikacje nie mogą zapisywać plików, sprawdź uprawnienia:
```bash
sudo chown -R $PUID:$PGID config media downloads cache
```

### Problem z połączeniem między kontenerami
Upewnij się, że wszystkie kontenery używają tej samej sieci Docker. W pliku `docker-compose.yml` wszystkie serwisy używają `network_mode: bridge`, co pozwala im komunikować się przez nazwy kontenerów.

### Sprawdzenie statusu kontenerów
```bash
docker-compose ps
```

### Sprawdzenie logów błędów
```bash
docker-compose logs --tail=100 [nazwa_serwisu]
```

## Bezpieczeństwo

⚠️ **UWAGA**: To rozwiązanie jest przeznaczone do użytku lokalnego. Jeśli planujesz udostępnić je w sieci:

1. Zmień domyślne hasła w Transmission
2. Rozważ użycie reverse proxy (np. Nginx) z SSL
3. Ogranicz dostęp do portów przez firewall
4. Używaj VPN dla Transmission

## Aktualizacje

Aplikacje będą automatycznie aktualizowane przy każdym `docker-compose pull && docker-compose up -d`, ponieważ używamy tagu `latest`. Dla środowiska produkcyjnego rozważ użycie konkretnych wersji.

## Wsparcie

W razie problemów sprawdź:
- Logi kontenerów: `docker-compose logs`
- Dokumentację poszczególnych aplikacji
- Status kontenerów: `docker-compose ps`

## Udostępnianie projektu

Jeśli chcesz udostępnić ten projekt innym, zobacz [SHARING.md](SHARING.md) dla szczegółowych instrukcji.

## Licencja

Ten projekt jest udostępniony na licencji MIT. Zobacz [LICENSE](LICENSE) dla szczegółów.

