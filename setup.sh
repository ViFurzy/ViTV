#!/bin/bash

# Skrypt pomocniczy do konfiguracji ViTV

set -e

echo "=== ViTV - Skrypt konfiguracji ==="
echo ""

# Sprawdzenie czy Docker jest zainstalowany
if ! command -v docker &> /dev/null; then
    echo "❌ Docker nie jest zainstalowany. Zainstaluj Docker najpierw."
    exit 1
fi

# Sprawdzenie czy Docker Compose jest zainstalowany
if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose nie jest zainstalowany. Zainstaluj Docker Compose najpierw."
    exit 1
fi

echo "✅ Docker i Docker Compose są zainstalowane"
echo ""

# Pobranie PUID i PGID
PUID=$(id -u)
PGID=$(id -g)

echo "Twój PUID: $PUID"
echo "Twój PGID: $PGID"
echo ""

# Utworzenie pliku .env jeśli nie istnieje
if [ ! -f .env ]; then
    echo "📝 Tworzenie pliku .env..."
    cp env.example .env
    sed -i "s/PUID=1000/PUID=$PUID/" .env
    sed -i "s/PGID=1000/PGID=$PGID/" .env
    echo "✅ Plik .env utworzony"
else
    echo "ℹ️  Plik .env już istnieje"
fi

# Utworzenie katalogów
echo ""
echo "📁 Tworzenie katalogów..."
mkdir -p config/{jellyfin,prowlarr,sonarr,jellyseerr,transmission}
mkdir -p media/{tv,movies}
mkdir -p downloads/watch
mkdir -p cache/jellyfin
echo "✅ Katalogi utworzone"

# Ustawienie uprawnień
echo ""
echo "🔐 Ustawianie uprawnień..."
sudo chown -R $PUID:$PGID config media downloads cache 2>/dev/null || {
    echo "⚠️  Nie udało się ustawić uprawnień automatycznie. Uruchom ręcznie:"
    echo "   sudo chown -R $PUID:$PGID config media downloads cache"
}
echo "✅ Uprawnienia ustawione"

# Pobranie obrazów Docker
echo ""
echo "📥 Pobieranie obrazów Docker (może to chwilę potrwać)..."
docker-compose pull

echo ""
echo "✅ Konfiguracja zakończona!"
echo ""
echo "Aby uruchomić wszystkie serwisy, wykonaj:"
echo "   docker-compose up -d"
echo ""
echo "Aby sprawdzić status:"
echo "   docker-compose ps"
echo ""
echo "Aby zobaczyć logi:"
echo "   docker-compose logs -f"
echo ""

