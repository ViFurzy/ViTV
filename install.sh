#!/bin/bash

# ViTV - Globalny skrypt instalacyjny
# Ten skrypt tworzy użytkownika, konfiguruje uprawnienia i przygotowuje środowisko

set -e

# Kolory dla lepszej czytelności
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funkcja do wyświetlania komunikatów
info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

# Sprawdzenie czy skrypt jest uruchomiony jako root
if [ "$EUID" -ne 0 ]; then 
    error "Ten skrypt musi być uruchomiony jako root (użyj sudo)"
    exit 1
fi

echo "=========================================="
echo "  ViTV - Globalny Skrypt Instalacyjny"
echo "=========================================="
echo ""

# Sprawdzenie czy Docker jest zainstalowany
if ! command -v docker &> /dev/null; then
    error "Docker nie jest zainstalowany."
    echo "Zainstaluj Docker używając:"
    echo "  curl -fsSL https://get.docker.com -o get-docker.sh"
    echo "  sh get-docker.sh"
    exit 1
fi

# Sprawdzenie czy Docker Compose jest zainstalowany i określenie komendy
DOCKER_COMPOSE_CMD=""
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE_CMD="docker compose"
else
    error "Docker Compose nie jest zainstalowany."
    exit 1
fi

success "Docker i Docker Compose są zainstalowane (używam: $DOCKER_COMPOSE_CMD)"
echo ""

# Pytanie o nazwę użytkownika
read -p "Podaj nazwę użytkownika dla ViTV (domyślnie: vitv): " VITV_USER
VITV_USER=${VITV_USER:-vitv}

# Sprawdzenie czy użytkownik już istnieje
if id "$VITV_USER" &>/dev/null; then
    warning "Użytkownik '$VITV_USER' już istnieje."
    read -p "Czy chcesz użyć istniejącego użytkownika? (t/n): " USE_EXISTING
    if [[ ! "$USE_EXISTING" =~ ^[TtYy]$ ]]; then
        error "Instalacja przerwana."
        exit 1
    fi
    VITV_UID=$(id -u "$VITV_USER")
    VITV_GID=$(id -g "$VITV_USER")
else
    # Utworzenie użytkownika
    info "Tworzenie użytkownika '$VITV_USER'..."
    useradd -r -m -s /bin/bash "$VITV_USER" 2>/dev/null || {
        error "Nie udało się utworzyć użytkownika."
        exit 1
    }
    VITV_UID=$(id -u "$VITV_USER")
    VITV_GID=$(id -g "$VITV_USER")
    success "Użytkownik '$VITV_USER' utworzony (UID: $VITV_UID, GID: $VITV_GID)"
fi

# Dodanie użytkownika do grupy docker
info "Dodawanie użytkownika do grupy docker..."
if getent group docker > /dev/null 2>&1; then
    usermod -aG docker "$VITV_USER"
    success "Użytkownik dodany do grupy docker"
    warning "UWAGA: Aby zmiany w grupie docker zadziałały, użytkownik $VITV_USER musi:"
    echo "  - Wylogować się i zalogować ponownie, LUB"
    echo "  - Uruchomić: newgrp docker"
else
    warning "Grupa docker nie istnieje. Utworzenie grupy..."
    groupadd docker
    usermod -aG docker "$VITV_USER"
    success "Grupa docker utworzona i użytkownik dodany"
    warning "UWAGA: Aby zmiany w grupie docker zadziałały, użytkownik $VITV_USER musi:"
    echo "  - Wylogować się i zalogować ponownie, LUB"
    echo "  - Uruchomić: newgrp docker"
fi

echo ""

# Pytanie o ścieżkę instalacji
read -p "Podaj ścieżkę instalacji (domyślnie: /opt/vitv): " INSTALL_PATH
INSTALL_PATH=${INSTALL_PATH:-/opt/vitv}

# Rozszerzenie ścieżki do pełnej ścieżki bezwzględnej
INSTALL_PATH=$(readlink -f "$INSTALL_PATH" 2>/dev/null || echo "$INSTALL_PATH")

info "Ścieżka instalacji: $INSTALL_PATH"

# Sprawdzenie czy katalog istnieje
if [ -d "$INSTALL_PATH" ]; then
    warning "Katalog '$INSTALL_PATH' już istnieje."
    read -p "Czy chcesz kontynuować? Istniejące pliki mogą zostać nadpisane. (t/n): " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[TtYy]$ ]]; then
        error "Instalacja przerwana."
        exit 1
    fi
else
    # Utworzenie katalogu głównego
    mkdir -p "$INSTALL_PATH"
    success "Katalog główny utworzony"
fi

# Ustawienie właściciela katalogu głównego
chown "$VITV_USER:$VITV_USER" "$INSTALL_PATH"
success "Właściciel katalogu ustawiony na $VITV_USER"

echo ""

# Pytanie o strefę czasową
read -p "Podaj strefę czasową (domyślnie: Europe/Warsaw): " TIMEZONE
TIMEZONE=${TIMEZONE:-Europe/Warsaw}

# Pytanie o dane logowania Transmission
read -p "Podaj nazwę użytkownika Transmission (domyślnie: admin): " TRANS_USER
TRANS_USER=${TRANS_USER:-admin}

read -sp "Podaj hasło Transmission (domyślnie: admin): " TRANS_PASS
TRANS_PASS=${TRANS_PASS:-admin}
echo ""

# Utworzenie struktury katalogów
info "Tworzenie struktury katalogów..."
mkdir -p "$INSTALL_PATH"/{config,media,downloads,cache}
mkdir -p "$INSTALL_PATH/config"/{jellyfin,prowlarr,sonarr,jellyseerr,transmission}
mkdir -p "$INSTALL_PATH/media"/{tv,movies}
mkdir -p "$INSTALL_PATH/downloads"/watch
mkdir -p "$INSTALL_PATH/cache"/jellyfin

success "Struktura katalogów utworzona"

# Ustawienie uprawnień
info "Ustawianie uprawnień..."
chown -R "$VITV_USER:$VITV_USER" "$INSTALL_PATH"
chmod -R 755 "$INSTALL_PATH"
# Katalogi konfiguracyjne - bardziej restrykcyjne
chmod 700 "$INSTALL_PATH/config"/*

success "Uprawnienia ustawione"

echo ""

# Kopiowanie plików projektu do katalogu instalacji
info "Kopiowanie plików projektu..."

# Sprawdzenie czy jesteśmy w katalogu z plikami projektu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
    cp "$SCRIPT_DIR/docker-compose.yml" "$INSTALL_PATH/"
    cp "$SCRIPT_DIR/env.example" "$INSTALL_PATH/" 2>/dev/null || true
    cp "$SCRIPT_DIR/.dockerignore" "$INSTALL_PATH/" 2>/dev/null || true
    cp "$SCRIPT_DIR/.gitignore" "$INSTALL_PATH/" 2>/dev/null || true
    cp "$SCRIPT_DIR/README.md" "$INSTALL_PATH/" 2>/dev/null || true
    success "Pliki projektu skopiowane"
else
    warning "Nie znaleziono plików projektu w $SCRIPT_DIR"
    warning "Będziesz musiał skopiować pliki ręcznie do $INSTALL_PATH"
fi

# Zmiana właściciela skopiowanych plików
chown -R "$VITV_USER:$VITV_USER" "$INSTALL_PATH"

echo ""

# Aktualizacja docker-compose.yml z bezwzględnymi ścieżkami
info "Aktualizacja docker-compose.yml z bezwzględnymi ścieżkami..."
if [ -f "$INSTALL_PATH/docker-compose.yml" ]; then
    # Backup oryginalnego pliku
    cp "$INSTALL_PATH/docker-compose.yml" "$INSTALL_PATH/docker-compose.yml.bak"
    
    # Zamiana względnych ścieżek na bezwzględne
    sed -i "s|\./config|$INSTALL_PATH/config|g" "$INSTALL_PATH/docker-compose.yml"
    sed -i "s|\./media|$INSTALL_PATH/media|g" "$INSTALL_PATH/docker-compose.yml"
    sed -i "s|\./downloads|$INSTALL_PATH/downloads|g" "$INSTALL_PATH/docker-compose.yml"
    sed -i "s|\./cache|$INSTALL_PATH/cache|g" "$INSTALL_PATH/docker-compose.yml"
    
    success "docker-compose.yml zaktualizowany"
fi

# Utworzenie pliku .env
info "Tworzenie pliku .env..."
cat > "$INSTALL_PATH/.env" << EOF
# User ID and Group ID for file permissions
PUID=$VITV_UID
PGID=$VITV_GID

# Timezone
TZ=$TIMEZONE

# Transmission credentials
TRANSMISSION_USER=$TRANS_USER
TRANSMISSION_PASS=$TRANS_PASS

# Jellyfin settings
JELLYFIN_PublishedServerUrl=http://localhost:8096
EOF

chown "$VITV_USER:$VITV_USER" "$INSTALL_PATH/.env"
chmod 600 "$INSTALL_PATH/.env"
success "Plik .env utworzony"

echo ""

# Utworzenie skryptu zarządzania
info "Tworzenie skryptu zarządzania..."
cat > "$INSTALL_PATH/vitv.sh" << 'SCRIPT_EOF'
#!/bin/bash

# ViTV - Skrypt zarządzania
# Użycie: ./vitv.sh [start|stop|restart|status|logs|update]

set -e

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$INSTALL_DIR"

# Wykryj dostępną komendę docker-compose
detect_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        echo "docker-compose"
    elif docker compose version &> /dev/null 2>&1; then
        echo "docker compose"
    else
        echo "docker-compose"  # fallback
    fi
}

DOCKER_COMPOSE_CMD=$(detect_docker_compose)

case "$1" in
    start)
        echo "Uruchamianie serwisów ViTV..."
        $DOCKER_COMPOSE_CMD up -d
        echo "Serwisy uruchomione!"
        ;;
    stop)
        echo "Zatrzymywanie serwisów ViTV..."
        $DOCKER_COMPOSE_CMD down
        echo "Serwisy zatrzymane!"
        ;;
    restart)
        echo "Restartowanie serwisów ViTV..."
        $DOCKER_COMPOSE_CMD restart
        echo "Serwisy zrestartowane!"
        ;;
    status)
        echo "Status serwisów ViTV:"
        $DOCKER_COMPOSE_CMD ps
        ;;
    logs)
        $DOCKER_COMPOSE_CMD logs -f "${2:-}"
        ;;
    update)
        echo "Aktualizowanie obrazów Docker..."
        $DOCKER_COMPOSE_CMD pull
        $DOCKER_COMPOSE_CMD up -d
        echo "Aktualizacja zakończona!"
        ;;
    *)
        echo "ViTV - Skrypt zarządzania"
        echo ""
        echo "Użycie: $0 [komenda]"
        echo ""
        echo "Komendy:"
        echo "  start     - Uruchom wszystkie serwisy"
        echo "  stop      - Zatrzymaj wszystkie serwisy"
        echo "  restart   - Zrestartuj wszystkie serwisy"
        echo "  status    - Pokaż status serwisów"
        echo "  logs [service] - Pokaż logi (opcjonalnie dla konkretnego serwisu)"
        echo "  update    - Zaktualizuj i zrestartuj serwisy"
        exit 1
        ;;
esac
SCRIPT_EOF

chmod +x "$INSTALL_PATH/vitv.sh"
chown "$VITV_USER:$VITV_USER" "$INSTALL_PATH/vitv.sh"
success "Skrypt zarządzania utworzony"

# Utworzenie linku symbolicznego do skryptu zarządzania (opcjonalne)
read -p "Czy chcesz utworzyć link symboliczny /usr/local/bin/vitv? (t/n): " CREATE_LINK
if [[ "$CREATE_LINK" =~ ^[TtYy]$ ]]; then
    ln -sf "$INSTALL_PATH/vitv.sh" /usr/local/bin/vitv
    success "Link symboliczny utworzony: /usr/local/bin/vitv"
fi

echo ""

# Funkcja do wyświetlania instrukcji konfiguracji
show_configuration_guide() {
    echo ""
    echo "=========================================="
    echo "  Instrukcje Konfiguracji - Krok po Kroku"
    echo "=========================================="
    echo ""
    
    info "WAŻNE: Konfiguruj aplikacje w następującej kolejności:"
    echo "  1. Transmission"
    echo "  2. Prowlarr"
    echo "  3. Sonarr"
    echo "  4. Jellyfin"
    echo "  5. Jellyseerr"
    echo ""
    read -p "Naciśnij Enter, aby kontynuować..."
    echo ""
    
    # 1. Transmission
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  1. TRANSMISSION - Klient BitTorrent"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📍 URL: http://localhost:9091"
    echo ""
    echo "Kroki konfiguracji:"
    echo "  1. Otwórz http://localhost:9091 w przeglądarce"
    echo "  2. Zaloguj się używając:"
    echo "     - Username: $TRANS_USER"
    echo "     - Password: $TRANS_PASS"
    echo "  3. Przejdź do: Settings → Download directories"
    echo "  4. Ustaw katalog pobierania: $INSTALL_PATH/downloads"
    echo "  5. Włącz 'Watch directory': $INSTALL_PATH/downloads/watch"
    echo "  6. Przejdź do: Settings → Remote Access"
    echo "  7. ⚠️  ZMIEŃ HASŁO na bezpieczne!"
    echo ""
    read -p "Naciśnij Enter, aby przejść do następnej aplikacji..."
    echo ""
    
    # 2. Prowlarr
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  2. PROWLARR - Menedżer Indekserów"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📍 URL: http://localhost:9696"
    echo ""
    echo "Kroki konfiguracji:"
    echo "  1. Otwórz http://localhost:9696 w przeglądarce"
    echo "  2. Przejdź do: Settings → Indexers"
    echo "  3. Kliknij '+ Add Indexer'"
    echo "  4. Dodaj indeksery (np. RARBG, 1337x, TorrentGalaxy)"
    echo "     - Wybierz indekser z listy"
    echo "     - Wypełnij wymagane pola (jeśli potrzebne)"
    echo "     - Zapisz"
    echo ""
    echo "  5. Przejdź do: Settings → Apps"
    echo "  6. Kliknij '+ Add Application'"
    echo "  7. Wybierz 'Sonarr'"
    echo "  8. Wypełnij:"
    echo "     - Name: Sonarr"
    echo "     - Prowlarr Server: http://prowlarr:9696"
    echo "     - Sonarr Server: http://sonarr:8989"
    echo "     - Sonarr API Key: (będziesz potrzebować z Sonarr)"
    echo "     - Sync App Indexers: ✓ (zaznacz)"
    echo "  9. Zapisz (możesz dodać API Key później)"
    echo ""
    echo "💡 TIP: API Key do Sonarr znajdziesz w:"
    echo "   Sonarr → Settings → General → Security → API Key"
    echo ""
    read -p "Naciśnij Enter, aby przejść do następnej aplikacji..."
    echo ""
    
    # 3. Sonarr
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  3. SONARR - Menedżer Seriali TV"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📍 URL: http://localhost:8989"
    echo ""
    echo "Kroki konfiguracji:"
    echo ""
    echo "A. Media Management:"
    echo "  1. Otwórz http://localhost:8989"
    echo "  2. Przejdź do: Settings → Media Management"
    echo "  3. Ustaw 'Root Folders':"
    echo "     - Kliknij '+ Add Root Folder'"
    echo "     - Wprowadź: $INSTALL_PATH/media/tv"
    echo "     - Zapisz"
    echo ""
    echo "B. Download Clients:"
    echo "  4. Przejdź do: Settings → Download Clients"
    echo "  5. Kliknij '+ Add Download Client'"
    echo "  6. Wybierz 'Transmission'"
    echo "  7. Wypełnij:"
    echo "     - Name: Transmission"
    echo "     - Host: transmission"
    echo "     - Port: 9091"
    echo "     - Username: $TRANS_USER"
    echo "     - Password: $TRANS_PASS"
    echo "     - Category: tv"
    echo "  8. Kliknij 'Test' aby sprawdzić połączenie"
    echo "  9. Zapisz"
    echo ""
    echo "C. Indexers:"
    echo "  10. Przejdź do: Settings → Indexers"
    echo "  11. Kliknij '+ Add Indexer'"
    echo "  12. Wybierz 'Prowlarr'"
    echo "  13. Wypełnij:"
    echo "      - Name: Prowlarr"
    echo "      - URL: http://prowlarr:9696"
    echo "      - API Key: (znajdziesz w Prowlarr → Settings → General)"
    echo "  14. Kliknij 'Test' aby sprawdzić połączenie"
    echo "  15. Zapisz"
    echo ""
    echo "D. Dodanie pierwszego serialu:"
    echo "  16. Kliknij 'Add New' w głównym menu"
    echo "  17. Wyszukaj serial"
    echo "  18. Wybierz serial i kliknij 'Add Series'"
    echo "  19. Wybierz folder: $INSTALL_PATH/media/tv"
    echo "  20. Zapisz"
    echo ""
    read -p "Naciśnij Enter, aby przejść do następnej aplikacji..."
    echo ""
    
    # 4. Jellyfin
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  4. JELLYFIN - Serwer Multimedialny"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📍 URL: http://localhost:8096"
    echo ""
    echo "Kroki konfiguracji:"
    echo "  1. Otwórz http://localhost:8096 w przeglądarce"
    echo "  2. Ukończ proces pierwszego uruchomienia:"
    echo "     - Wybierz język"
    echo "     - Utwórz konto administratora"
    echo "     - Wybierz biblioteki (możesz pominąć na razie)"
    echo ""
    echo "  3. Przejdź do: Dashboard (ikonka domu w lewym górnym rogu)"
    echo "  4. Kliknij: Libraries → '+ Add Media Library'"
    echo ""
    echo "  5. Dodaj bibliotekę Movies:"
    echo "     - Content Type: Movies"
    echo "     - Display Name: Movies"
    echo "     - Folders: Kliknij '+', wprowadź: $INSTALL_PATH/media/movies"
    echo "     - Zapisz"
    echo ""
    echo "  6. Dodaj bibliotekę TV Shows:"
    echo "     - Content Type: TV Shows"
    echo "     - Display Name: TV Shows"
    echo "     - Folders: Kliknij '+', wprowadź: $INSTALL_PATH/media/tv"
    echo "     - Zapisz"
    echo ""
    echo "  7. Przejdź do: Dashboard → Libraries"
    echo "  8. Kliknij 'Scan All Libraries' aby rozpocząć skanowanie"
    echo ""
    echo "  9. (Opcjonalnie) Przejdź do: Dashboard → API Keys"
    echo "     - Utwórz nowy klucz API dla Jellyseerr"
    echo "     - Skopiuj klucz (będzie potrzebny w Jellyseerr)"
    echo ""
    read -p "Naciśnij Enter, aby przejść do następnej aplikacji..."
    echo ""
    
    # 5. Jellyseerr
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  5. JELLYSEERR - System Żądań dla Mediów"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📍 URL: http://localhost:5055"
    echo ""
    echo "Kroki konfiguracji:"
    echo "  1. Otwórz http://localhost:5055 w przeglądarce"
    echo "  2. Ukończ proces pierwszego uruchomienia:"
    echo "     - Utwórz konto administratora"
    echo "     - Wybierz język"
    echo ""
    echo "  3. Przejdź do: Settings → Services"
    echo ""
    echo "  4. Dodaj Jellyfin:"
    echo "     - Kliknij '+ Add Service'"
    echo "     - Wybierz 'Jellyfin'"
    echo "     - Name: Jellyfin"
    echo "     - Server URL: http://jellyfin:8096"
    echo "     - API Key: (wklej klucz z Jellyfin → Dashboard → API Keys)"
    echo "     - Zapisz"
    echo ""
    echo "  5. Dodaj Sonarr:"
    echo "     - Kliknij '+ Add Service'"
    echo "     - Wybierz 'Sonarr'"
    echo "     - Name: Sonarr"
    echo "     - Server URL: http://sonarr:8989"
    echo "     - API Key: (znajdziesz w Sonarr → Settings → General → Security)"
    echo "     - Zapisz"
    echo ""
    echo "  6. Przejdź do: Settings → Users"
    echo "  7. Kliknij '+ Create User' aby dodać użytkowników"
    echo "  8. Użytkownicy będą mogli żądać filmów i seriali przez Jellyseerr"
    echo ""
    echo "  9. (Opcjonalnie) Przejdź do: Settings → Notifications"
    echo "     - Skonfiguruj powiadomienia (Discord, Email, itp.)"
    echo ""
    read -p "Naciśnij Enter, aby zakończyć..."
    echo ""
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    success "Instrukcje konfiguracji zakończone!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    info "Pamiętaj:"
    echo "  - Zmień hasło Transmission na bezpieczne!"
    echo "  - Dodaj indeksery w Prowlarr"
    echo "  - Połącz wszystkie aplikacje używając API Keys"
    echo "  - Dodaj pierwsze seriale/filmy do testowania"
    echo ""
}

# Zapytanie czy uruchomić dockery teraz
SHOW_GUIDE_SHOWN=false
echo ""
read -p "Czy chcesz uruchomić kontenery Docker teraz? (t/n): " START_NOW
if [[ "$START_NOW" =~ ^[TtYy]$ ]]; then
    info "Uruchamianie kontenerów Docker..."
    
    # Uruchomienie jako użytkownik vitv
    # Używamy pełnej ścieżki środowiska, aby upewnić się że PATH jest poprawny
    info "Sprawdzanie dostępności Docker Compose dla użytkownika $VITV_USER..."
    
    # Sprawdź czy użytkownik może użyć docker compose
    if sudo -u "$VITV_USER" bash -c "cd $INSTALL_PATH && $DOCKER_COMPOSE_CMD version &>/dev/null"; then
        info "Uruchamianie kontenerów używając: $DOCKER_COMPOSE_CMD"
        sudo -u "$VITV_USER" bash -c "cd $INSTALL_PATH && $DOCKER_COMPOSE_CMD up -d" 2>&1
        DOCKER_EXIT_CODE=$?
    else
        # Fallback - spróbuj docker compose (plugin)
        warning "Sprawdzanie alternatywnej metody..."
        if sudo -u "$VITV_USER" bash -c "cd $INSTALL_PATH && docker compose version &>/dev/null"; then
            info "Używam: docker compose"
            sudo -u "$VITV_USER" bash -c "cd $INSTALL_PATH && docker compose up -d" 2>&1
            DOCKER_EXIT_CODE=$?
            DOCKER_COMPOSE_CMD="docker compose"
        else
            error "Nie można znaleźć działającej komendy Docker Compose dla użytkownika $VITV_USER"
            DOCKER_EXIT_CODE=1
        fi
    fi
    
    if [ $DOCKER_EXIT_CODE -eq 0 ]; then
        success "Kontenery Docker uruchomione!"
        echo ""
        info "Oczekiwanie na uruchomienie serwisów (10 sekund)..."
        sleep 10
        
        # Sprawdzenie statusu
        echo ""
        info "Status kontenerów:"
        sudo -u "$VITV_USER" bash -c "cd $INSTALL_PATH && $DOCKER_COMPOSE_CMD ps"
        echo ""
        
        # Zapytanie o wyświetlenie instrukcji konfiguracji
        read -p "Czy chcesz wyświetlić instrukcje konfiguracji krok po kroku? (t/n): " SHOW_GUIDE
        if [[ "$SHOW_GUIDE" =~ ^[TtYy]$ ]]; then
            show_configuration_guide
            SHOW_GUIDE_SHOWN=true
        fi
    else
        error "Nie udało się uruchomić kontenerów."
        echo ""
        warning "Możliwe przyczyny:"
        echo "  1. Użytkownik $VITV_USER nie ma uprawnień do Docker"
        echo "  2. Docker Compose nie jest dostępny w PATH użytkownika"
        echo ""
        info "Rozwiązanie:"
        echo "  1. Przełącz się na użytkownika: sudo su - $VITV_USER"
        echo "  2. Przejdź do katalogu: cd $INSTALL_PATH"
        echo "  3. Uruchom ręcznie: $DOCKER_COMPOSE_CMD up -d"
        echo ""
        echo "Lub sprawdź logi:"
        echo "  cd $INSTALL_PATH"
        echo "  $DOCKER_COMPOSE_CMD logs"
        echo ""
        echo "Możesz też uruchomić ręcznie po przełączeniu na użytkownika:"
        echo "  sudo su - $VITV_USER"
        echo "  cd $INSTALL_PATH"
        echo "  ./vitv.sh start"
    fi
fi

echo ""
echo "=========================================="
success "Instalacja zakończona pomyślnie!"
echo "=========================================="
echo ""
echo "Szczegóły instalacji:"
echo "  Użytkownik: $VITV_USER (UID: $VITV_UID, GID: $VITV_GID)"
echo "  Katalog instalacji: $INSTALL_PATH"
echo "  Strefa czasowa: $TIMEZONE"
echo ""

if [[ ! "$START_NOW" =~ ^[TtYy]$ ]]; then
    echo "Następne kroki:"
    echo "  1. Przełącz się na użytkownika $VITV_USER:"
    echo "     sudo su - $VITV_USER"
    echo ""
    echo "  2. Przejdź do katalogu instalacji:"
    echo "     cd $INSTALL_PATH"
    echo ""
    echo "  3. Uruchom serwisy:"
    if [ -f /usr/local/bin/vitv ]; then
        echo "     vitv start"
    else
        echo "     ./vitv.sh start"
        echo "     # lub"
        echo "     docker-compose up -d"
    fi
    echo ""
fi

echo "Dostęp do aplikacji:"
echo "  - Jellyfin:     http://localhost:8096"
echo "  - Prowlarr:     http://localhost:9696"
echo "  - Sonarr:       http://localhost:8989"
echo "  - Jellyseerr:   http://localhost:5055"
echo "  - Transmission: http://localhost:9091"
echo ""

if [ "$SHOW_GUIDE_SHOWN" = false ]; then
    echo "Aby wyświetlić instrukcje konfiguracji krok po kroku:"
    echo "  cd $INSTALL_PATH"
    echo "  # Uruchom serwisy jeśli jeszcze nie:"
    if [ -f /usr/local/bin/vitv ]; then
        echo "  vitv start"
    else
        echo "  ./vitv.sh start"
    fi
    echo "  # Następnie przeczytaj:"
    echo "  - README.md - pełna dokumentacja z instrukcjami konfiguracji"
    echo "  - INSTALL.md - szczegółowa instrukcja instalacji"
    echo ""
fi

warning "WAŻNE: Po pierwszym uruchomieniu zmień hasło Transmission!"
echo ""


