#!/usr/bin/env bash
set -e

# ── Colori ──────────────────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✅ $1${NC}"; }
info() { echo -e "${YELLOW}➡️  $1${NC}"; }
err()  { echo -e "${RED}❌ $1${NC}"; exit 1; }

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║     DBeaver Auto-Updater Setup           ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# ── 1. Crea lo script dbeaver-update ─────────────────────
info "Creazione script /usr/local/bin/dbeaver-update..."

sudo tee /usr/local/bin/dbeaver-update > /dev/null << 'SCRIPT'
#!/usr/bin/env bash
set -e
set -o pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

GITHUB_API="https://api.github.com/repos/dbeaver/dbeaver/releases/latest"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║        DBeaver Update Checker            ║"
echo "╚══════════════════════════════════════════╝"
echo ""

log_info "Controllo versione DBeaver installata..."
INSTALLED=""
if dpkg-query -W -f='${Status}' dbeaver-ce 2>/dev/null | grep -q "install ok installed"; then
    INSTALLED=$(dpkg-query --showformat='${Version}' --show dbeaver-ce 2>/dev/null)
    log_info "Versione installata: $INSTALLED"
else
    log_warning "DBeaver non risulta installato tramite .deb"
fi

log_info "Controllo ultima versione disponibile su GitHub..."
API_RESPONSE=$(curl -fsSL "$GITHUB_API")
REMOTE_VERSION=$(echo "$API_RESPONSE" | grep '"tag_name"' | head -1 | grep -oP '"tag_name":\s*"\K[^"]+' )

if [ -z "$REMOTE_VERSION" ]; then
    log_error "Impossibile recuperare l'ultima versione. Verifica la connessione internet."
    log_warning "Avvio DBeaver senza aggiornamento..."
    notify-send "DBeaver" "⚠️ Impossibile verificare aggiornamenti" --icon=dbeaver 2>/dev/null || true
    exec dbeaver
fi

log_info "Ultima versione disponibile: $REMOTE_VERSION"
REMOTE_CLEAN="${REMOTE_VERSION#v}"

if [ -n "$INSTALLED" ] && [ "$INSTALLED" = "$REMOTE_CLEAN" ]; then
    log_info "DBeaver è già aggiornato ($INSTALLED). Avvio in corso..."
    notify-send "DBeaver" "✅ Già aggiornato ($INSTALLED)" --icon=dbeaver 2>/dev/null || true
    exec dbeaver
fi

echo ""
if [ -n "$INSTALLED" ]; then
    log_warning "Nuova versione disponibile: $REMOTE_CLEAN (installata: $INSTALLED)"
else
    log_warning "DBeaver $REMOTE_CLEAN è disponibile."
fi

read -r -p "$(echo -e "${BLUE}[?]${NC} Vuoi aggiornare ora? [Y/n] ")" answer

if [[ "$answer" == "n" || "$answer" == "N" ]]; then
    log_info "Aggiornamento rimandato. Avvio DBeaver..."
    exec dbeaver
fi

log_info "Recupero link download .deb..."
DEB_URL=$(echo "$API_RESPONSE" \
    | grep '"browser_download_url"' \
    | grep -i '\.deb' \
    | grep -i 'amd64\|x86_64' \
    | head -1 \
    | grep -oP '"browser_download_url":\s*"\K[^"]+' )

if [ -z "$DEB_URL" ]; then
    log_warning "Asset non trovato via API, uso URL diretto..."
    DEB_URL="https://github.com/dbeaver/dbeaver/releases/download/${REMOTE_VERSION}/dbeaver-ce_${REMOTE_CLEAN}_amd64.deb"
fi

log_info "URL: $DEB_URL"

log_info "Download DBeaver $REMOTE_CLEAN in corso..."
TMP_DIR=$(mktemp -d)
if curl -L --progress-bar "$DEB_URL" -o "$TMP_DIR/dbeaver.deb"; then
    log_info "Download completato."
else
    log_error "Download fallito. Avvio DBeaver con la versione attuale..."
    rm -rf "$TMP_DIR"
    notify-send "DBeaver" "❌ Download aggiornamento fallito" --icon=dbeaver 2>/dev/null || true
    exec dbeaver
fi

log_info "Installazione DBeaver $REMOTE_CLEAN..."
if sudo dpkg -i "$TMP_DIR/dbeaver.deb" && sudo apt-get install -f -y 2>/dev/null; then
    log_info "Aggiornamento completato con successo!"
    notify-send "DBeaver" "🎉 Aggiornato a $REMOTE_CLEAN!" --icon=dbeaver 2>/dev/null || true
else
    log_error "Installazione fallita. Avvio DBeaver con la versione attuale..."
    notify-send "DBeaver" "❌ Installazione aggiornamento fallita" --icon=dbeaver 2>/dev/null || true
fi

rm -rf "$TMP_DIR"

log_info "Avvio DBeaver..."
exec dbeaver
SCRIPT

ok "Script dbeaver-update creato."

# ── 2. Rendi eseguibile ──────────────────────────────────
info "Impostazione permessi eseguibili..."
sudo chmod +x /usr/local/bin/dbeaver-update
ok "Permessi impostati."

# ── 3. Trova il file .desktop di DBeaver ──────────────────
DESKTOP_LOCAL="$HOME/.local/share/applications/dbeaver-ce.desktop"
DESKTOP_SYSTEM=""

for candidate in \
    /usr/share/applications/dbeaver-ce.desktop \
    /usr/share/applications/dbeaver.desktop \
    /opt/dbeaver/dbeaver-ce.desktop; do
    if [ -f "$candidate" ]; then
        DESKTOP_SYSTEM="$candidate"
        break
    fi
done

if [ ! -f "$DESKTOP_LOCAL" ]; then
    info "Copio il .desktop di sistema in locale..."
    if [ -n "$DESKTOP_SYSTEM" ]; then
        cp "$DESKTOP_SYSTEM" "$DESKTOP_LOCAL"
        ok "Copiato da $DESKTOP_SYSTEM"
    else
        err "File .desktop di DBeaver non trovato! Hai DBeaver installato?"
    fi
else
    ok "File .desktop locale già presente."
fi

# ── 4. Modifica Exec= ─────────────────────────────────────────
info "Modifica riga Exec= nel .desktop..."
sed -i 's|^Exec=.*|Exec=bash -c "dbeaver-update"|' "$DESKTOP_LOCAL"
ok "Riga Exec= aggiornata."

# ── 5. Aggiorna database launcher ───────────────────────
info "Aggiornamento database applicazioni..."
update-desktop-database "$HOME/.local/share/applications/" 2>/dev/null || true
ok "Database aggiornato."

# ── Fine ─────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  Setup completato con successo! 🎉       ║"
echo "║                                          ║"
echo "║  Da ora, aprendo DBeaver dal menu app    ║"
echo "║  verrà chiesto se aggiornare quando      ║"
echo "║  una nuova versione è disponibile.       ║"
echo "╚══════════════════════════════════════════╝"
echo ""
