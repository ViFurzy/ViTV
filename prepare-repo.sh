#!/bin/bash

# Skrypt pomocniczy do przygotowania repozytorium Git

set -e

echo "=========================================="
echo "  Przygotowanie repozytorium ViTV"
echo "=========================================="
echo ""

# Sprawdzenie czy Git jest zainstalowany
if ! command -v git &> /dev/null; then
    echo "❌ Git nie jest zainstalowany."
    echo "Zainstaluj Git: sudo apt-get install git"
    exit 1
fi

# Sprawdzenie czy jesteśmy w katalogu projektu
if [ ! -f "docker-compose.yml" ] || [ ! -f "install.sh" ]; then
    echo "❌ Nie jesteś w katalogu projektu ViTV"
    exit 1
fi

# Sprawdzenie czy repozytorium już istnieje
if [ -d ".git" ]; then
    echo "ℹ️  Repozytorium Git już istnieje."
    read -p "Czy chcesz kontynuować? (t/n): " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[TtYy]$ ]]; then
        exit 0
    fi
else
    # Inicjalizacja repozytorium
    echo "📦 Inicjalizacja repozytorium Git..."
    git init
    echo "✅ Repozytorium zainicjalizowane"
fi

# Dodanie plików
echo ""
echo "📝 Dodawanie plików do repozytorium..."
git add docker-compose.yml
git add install.sh
git add setup.sh
git add README.md
git add INSTALL.md
git add QUICKSTART.md
git add SHARING.md
git add LICENSE
git add env.example
git add .gitignore
git add .dockerignore
git add .gitattributes

# Sprawdzenie czy są zmiany do commitowania
if git diff --staged --quiet; then
    echo "ℹ️  Brak zmian do commitowania"
else
    echo "💾 Tworzenie commita..."
    read -p "Podaj wiadomość commita (Enter = domyślna): " COMMIT_MSG
    COMMIT_MSG=${COMMIT_MSG:-"Initial commit: ViTV - kompleksowy system media streaming"}
    git commit -m "$COMMIT_MSG"
    echo "✅ Commit utworzony"
fi

echo ""
echo "=========================================="
echo "✅ Repozytorium gotowe!"
echo "=========================================="
echo ""
echo "Następne kroki:"
echo ""
echo "1. Utwórz repozytorium na GitHub/GitLab:"
echo "   - GitHub: https://github.com/new"
echo "   - GitLab: https://gitlab.com/projects/new"
echo ""
echo "2. Połącz lokalne repozytorium z zdalnym:"
echo "   git remote add origin https://github.com/TWOJA_NAZWA/ViTV.git"
echo "   git branch -M main"
echo "   git push -u origin main"
echo ""
echo "3. Zobacz SHARING.md dla szczegółowych instrukcji"
echo ""

