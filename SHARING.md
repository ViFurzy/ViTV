# Jak udostępnić projekt ViTV

Ten przewodnik pomoże Ci udostępnić projekt ViTV innym użytkownikom.

## Opcja 1: Repozytorium Git (ZALECANA)

### A. GitHub

1. **Utwórz nowe repozytorium na GitHub:**
   - Przejdź na https://github.com/new
   - Nazwa: `ViTV` (lub dowolna inna)
   - Opis: "Kompleksowy system media streaming z Jellyfin, Sonarr, Prowlarr, Jellyseerr i Transmission"
   - Publiczne lub prywatne (według uznania)
   - **NIE** zaznaczaj "Initialize with README" (już masz README)

2. **Zainicjalizuj repozytorium lokalnie:**
   ```bash
   cd /ścieżka/do/ViTV
   git init
   git add .
   git commit -m "Initial commit: ViTV - kompleksowy system media streaming"
   ```

3. **Połącz z repozytorium GitHub:**
   ```bash
   git remote add origin https://github.com/TWOJA_NAZWA/ViTV.git
   git branch -M main
   git push -u origin main
   ```

4. **Udostępnij link:**
   - Publiczne: https://github.com/TWOJA_NAZWA/ViTV
   - Inni użytkownicy mogą sklonować: `git clone https://github.com/TWOJA_NAZWA/ViTV.git`

### B. GitLab

1. **Utwórz nowy projekt na GitLab:**
   - Przejdź na https://gitlab.com/projects/new
   - Wypełnij formularz podobnie jak na GitHub

2. **Wykonaj te same kroki jak dla GitHub**, zmieniając tylko URL:
   ```bash
   git remote add origin https://gitlab.com/TWOJA_NAZWA/ViTV.git
   ```

### C. Inne platformy Git

- **Bitbucket**: https://bitbucket.org/repo/create
- **Codeberg**: https://codeberg.org/repo/create
- **Własny serwer Git**: skonfiguruj zgodnie z dokumentacją

## Opcja 2: Archiwum (ZIP/TAR)

Jeśli nie chcesz używać Git:

1. **Utwórz archiwum:**
   ```bash
   cd /ścieżka/do/projektu
   tar -czf ViTV.tar.gz --exclude='.git' --exclude='config' --exclude='media' --exclude='downloads' --exclude='cache' --exclude='.env' .
   # lub
   zip -r ViTV.zip . -x "*.git*" "config/*" "media/*" "downloads/*" "cache/*" ".env"
   ```

2. **Udostępnij archiwum:**
   - Prześlij na Google Drive, Dropbox, OneDrive
   - Wyślij przez email
   - Udostępnij przez serwer FTP

3. **Instrukcje dla odbiorcy:**
   - Pobierz i rozpakuj archiwum
   - Postępuj zgodnie z instrukcjami w README.md

## Opcja 3: Własny serwer

Jeśli masz własny serwer:

1. **Prześlij pliki przez SCP/SFTP:**
   ```bash
   scp -r /ścieżka/do/ViTV user@server:/path/to/destination
   ```

2. **Lub użyj rsync:**
   ```bash
   rsync -avz --exclude='.git' --exclude='config' --exclude='media' --exclude='downloads' --exclude='cache' --exclude='.env' /ścieżka/do/ViTV/ user@server:/path/to/destination/
   ```

## Instrukcje dla odbiorców

### Instalacja z Git

```bash
# Sklonuj repozytorium
git clone https://github.com/TWOJA_NAZWA/ViTV.git
cd ViTV

# Uruchom instalację
sudo ./install.sh
```

### Instalacja z archiwum

```bash
# Pobierz i rozpakuj
tar -xzf ViTV.tar.gz
cd ViTV
# lub
unzip ViTV.zip
cd ViTV

# Uruchom instalację
sudo ./install.sh
```

## Co jest udostępniane

✅ **Zawarte w repozytorium:**
- `docker-compose.yml` - konfiguracja Docker
- `install.sh` - skrypt instalacyjny
- `setup.sh` - pomocniczy skrypt
- `README.md` - dokumentacja
- `INSTALL.md` - instrukcje instalacji
- `QUICKSTART.md` - szybki start
- `env.example` - przykładowe zmienne środowiskowe
- `LICENSE` - licencja
- `.gitignore` - ignorowane pliki
- `.dockerignore` - ignorowane pliki Docker

❌ **NIE udostępniaj (zawarte w .gitignore):**
- `.env` - zmienne środowiskowe z hasłami
- `config/` - konfiguracje aplikacji (mogą zawierać dane osobowe)
- `media/` - pliki multimedialne
- `downloads/` - pobrane pliki
- `cache/` - cache aplikacji

## Bezpieczeństwo

⚠️ **Przed udostępnieniem sprawdź:**

1. **Nie ma wrażliwych danych:**
   ```bash
   # Sprawdź czy nie ma haseł w plikach
   grep -r "password\|secret\|key" . --exclude-dir=.git
   ```

2. **Usuń historię Git (jeśli zawiera wrażliwe dane):**
   ```bash
   # Jeśli potrzebujesz wyczyścić historię:
   git checkout --orphan new-main
   git add .
   git commit -m "Initial commit"
   git branch -D main
   git branch -m main
   git push -f origin main
   ```

3. **Sprawdź .gitignore:**
   - Upewnij się, że wszystkie wrażliwe pliki są ignorowane

## Aktualizacje

Gdy zaktualizujesz projekt:

```bash
git add .
git commit -m "Opis zmian"
git push
```

Użytkownicy mogą zaktualizować:
```bash
cd ViTV
git pull
```

## Licencja

Projekt jest udostępniony na licencji MIT - możesz swobodnie używać, modyfikować i udostępniać.

## Wsparcie

Jeśli udostępniasz projekt publicznie, rozważ:
- Utworzenie Issues na GitHub/GitLab dla zgłaszania problemów
- Utworzenie Wiki dla dodatkowej dokumentacji
- Dodanie sekcji "Contributing" w README

