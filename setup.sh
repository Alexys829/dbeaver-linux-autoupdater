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

LOCK_FILE="/tmp/dbeaver-update.lock"
GITHUB_API="https://api.github.com/repos/dbeaver/dbeaver/releases/latest"

cleanup() {
    rm -f "$LOCK_FILE"
    [ -n "$TMP_DIR" ] && rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if [ -f "$LOCK_FILE" ]; then
    PID=$(cat "$LOCK_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        MSG="⚠️ Update già in corso (PID: $PID)"
        echo "$MSG"
        notify-send "DBeaver" "$MSG" --icon=dbeaver 2>/dev/null || true
        exit 1
    fi
    rm -f "$LOCK_FILE"
fi
echo $$ > "$LOCK_FILE"

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║        DBeaver Update Checker            ║"
echo "╚══════════════════════════════════════════╝"
echo ""

notify-send "DBeaver" "🔍 Controllo aggiornamenti..." --icon=dbeaver 2>/dev/null || true

echo "🔍 Controllo versione DBeaver installata..."
INSTALLED=""
if dpkg-query -W -f='${Status}' dbeaver-ce 2>/dev/null | grep -q "install ok installed"; then
    INSTALLED=$(dpkg-query --showformat='${Version}' --show dbeaver-ce 2>/dev/null)
    echo "   Versione installata: $INSTALLED"
else
    echo "   DBeaver non ancora installato."
fi

echo "🌐 Recupero ultima versione disponibile..."
notify-send "DBeaver" "🌐 Controllo server..." --icon=dbeaver 2>/dev/null || true

set -o pipefail
CURL_EXIT=0
API_RESPONSE=$(curl -fsSL "$GITHUB_API" 2>&1) || CURL_EXIT=$?
if [ $CURL_EXIT -ne 0 ]; then
    MSG="❌ Errore curl (exit $CURL_EXIT)"
    echo "$MSG"
    notify-send "DBeaver" "$MSG" --icon=dbeaver 2>/dev/null || true
    exit 1
fi

REMOTE_VERSION=$(echo "$API_RESPONSE" | grep '"tag_name"' | head -1 | grep -oP '"tag_name":\s*"\K[^"]+' )

if [ -z "$REMOTE_VERSION" ]; then
    MSG="❌ Impossibile recuperare versione"
    echo "$MSG"
    notify-send "DBeaver" "$MSG" --icon=dbeaver 2>/dev/null || true
    exit 1
fi

echo "   Ultima versione: $REMOTE_VERSION"
REMOTE_CLEAN="${REMOTE_VERSION#v}"

INSTALLED_BASE="${INSTALLED%%-*}"
if [ -n "$INSTALLED" ] && [ "$INSTALLED_BASE" = "$REMOTE_CLEAN" ]; then
    echo "✅ DBeaver è già aggiornato ($INSTALLED)."
    notify-send "DBeaver" "✅ Già aggiornato ($INSTALLED)" --icon=dbeaver 2>/dev/null || true
    exit 0
fi

if [ -n "$INSTALLED" ]; then
    MSG="Nuova versione: $REMOTE_CLEAN (installata: $INSTALLED)"
else
    MSG="DBeaver $REMOTE_CLEAN è disponibile."
fi

notify-send "DBeaver" "⚠️ $MSG" --icon=dbeaver 2>/dev/null || true

if [ -t 0 ] && [ -t 1 ]; then
    echo "⚠️ $MSG"
    read -r -p "$(echo -e "🔔 Vuoi aggiornare ora? [Y/n] ")" answer
    if [[ "$answer" == "n" || "$answer" == "N" ]]; then
        echo "✅ Aggiornamento rimandato. Avvio DBeaver..."
        exec dbeaver
    fi
else
    if command -v zenity &>/dev/null; then
        zenity --question --title="DBeaver Update" --text="$MSG\n\nVuoi aggiornare ora?" --ok-label="Aggiorna" --cancel-label="Annulla" 2>/dev/null || exec dbeaver
    else
        echo "⚠️ $MSG - zenity non disponibile, avvio DBeaver..."
        notify-send "DBeaver" "⚠️ $MSG - Apri da terminale per aggiornare" --icon=dbeaver 2>/dev/null || true
        exec dbeaver
    fi
fi

echo "⬇️  Download DBeaver $REMOTE_CLEAN..."
notify-send "DBeaver" "⬇️  Scaricamento DBeaver $REMOTE_CLEAN..." --icon=dbeaver 2>/dev/null || true

DEB_URL=$(echo "$API_RESPONSE" \
    | grep '"browser_download_url"' \
    | grep -i '\.deb' \
    | grep -i 'amd64\|x86_64' \
    | head -1 \
    | grep -oP '"browser_download_url":\s*"\K[^"]+' )

if [ -z "$DEB_URL" ]; then
    DEB_URL="https://github.com/dbeaver/dbeaver/releases/download/${REMOTE_VERSION}/dbeaver-ce_${REMOTE_CLEAN}_amd64.deb"
fi

echo "   URL: $DEB_URL"

TMP_DIR=$(mktemp -d)
if ! curl -L --max-time 120 "$DEB_URL" -o "$TMP_DIR/dbeaver.deb"; then
    MSG="❌ Download fallito"
    echo "$MSG"
    notify-send "DBeaver" "$MSG" --icon=dbeaver 2>/dev/null || true
    exit 1
fi

if [ ! -s "$TMP_DIR/dbeaver.deb" ]; then
    MSG="❌ File scaricato vuoto/corrotto"
    echo "$MSG"
    notify-send "DBeaver" "$MSG" --icon=dbeaver 2>/dev/null || true
    exit 1
fi

if ! dpkg-deb --info "$TMP_DIR/dbeaver.deb" >/dev/null 2>&1; then
    MSG="❌ File .deb non valido o corrotto"
    echo "$MSG"
    notify-send "DBeaver" "$MSG" --icon=dbeaver 2>/dev/null || true
    exit 1
fi

echo "📦 Installazione in corso..."
notify-send "DBeaver" "📦 Installazione DBeaver $REMOTE_CLEAN..." --icon=dbeaver 2>/dev/null || true

if ! pkexec sh -c "dpkg -i '$TMP_DIR/dbeaver.deb' && apt-get install -f -y"; then
    MSG="❌ Installazione fallita"
    echo "$MSG"
    notify-send "DBeaver" "$MSG" --icon=dbeaver 2>/dev/null || true
    exit 1
fi

echo "🎉 DBeaver $REMOTE_CLEAN installato con successo!"
notify-send "DBeaver" "🎉 Aggiornato a $REMOTE_CLEAN!" --icon=dbeaver 2>/dev/null || true

exec dbeaver
SCRIPT

ok "Script dbeaver-update creato."

# ── 2. Rendi eseguibile ──────────────────────────────────
info "Permessi eseguibili su dbeaver-update..."
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
        ok "Copiato in $DESKTOP_LOCAL"
    else
        err "File .desktop di DBeaver non trovato! Hai DBeaver installato?"
    fi
else
    ok "File .desktop locale già presente."
fi

# ── 4. Modifica Exec= ─────────────────────────────────────────
info "Modifica riga Exec= nel .desktop..."
sed -i 's|^Exec=.*|Exec=bash -c "dbeaver-update; /usr/bin/dbeaver"|' "$DESKTOP_LOCAL"
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
echo "║  verrà eseguito il check aggiornamento   ║"
echo "║  automaticamente prima dell'avvio.       ║"
echo "╚══════════════════════════════════════════╝"
echo ""