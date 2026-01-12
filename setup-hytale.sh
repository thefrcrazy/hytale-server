#!/bin/sh
#===============================================================================
#  HYTALE SERVER - SCRIPT D'INSTALLATION STANDALONE
#  Crée tous les fichiers et dossiers nécessaires
#  Compatible: sh, bash, dash
#===============================================================================

# Déterminer le répertoire d'installation (dossier courant)
INSTALL_DIR="$(cd "$(dirname "$0")" && pwd)"
HYTALE_USER="hytale"
HYTALE_GROUP="hytale"

# Fonctions de log
log_info() { printf "\033[0;34m[INFO]\033[0m %s\n" "$*"; }
log_success() { printf "\033[0;32m[OK]\033[0m %s\n" "$*"; }
log_warn() { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
log_error() { printf "\033[0;31m[ERROR]\033[0m %s\n" "$*"; }

# ============== CRÉATION DES DOSSIERS ==============

create_directories() {
    log_info "Création des dossiers..."
    
    mkdir -p "${INSTALL_DIR}/server/mods"
    mkdir -p "${INSTALL_DIR}/server/plugins"
    mkdir -p "${INSTALL_DIR}/server/universe"
    mkdir -p "${INSTALL_DIR}/config"
    mkdir -p "${INSTALL_DIR}/backups"
    mkdir -p "${INSTALL_DIR}/logs"
    mkdir -p "${INSTALL_DIR}/assets"
    
    log_success "Dossiers créés."
}

# ============== CRÉATION DES FICHIERS DE CONFIGURATION ==============

create_server_conf() {
    log_info "Création de config/server.conf..."
    
    cat > "${INSTALL_DIR}/config/server.conf" << 'SERVERCONF'
#===============================================================================
#  HYTALE SERVER - CONFIGURATION PRINCIPALE
#===============================================================================

#===============================================================================
#  CHEMINS
#===============================================================================

INSTALL_DIR="__INSTALL_DIR__"
SERVER_DIR="${INSTALL_DIR}/server"
ASSETS_DIR="${INSTALL_DIR}/assets"
BACKUPS_DIR="${INSTALL_DIR}/backups"
LOGS_DIR="${INSTALL_DIR}/logs"
CONFIG_DIR="${INSTALL_DIR}/config"

SERVER_JAR="HytaleServer.jar"
ASSETS_FILE="Assets.zip"

#===============================================================================
#  SERVEUR HYTALE
#===============================================================================

SCREEN_NAME="hytale"
BIND_ADDRESS="0.0.0.0:5520"
AUTH_MODE="authenticated"
PATCHLINE="release"

#===============================================================================
#  JAVA
#===============================================================================

# Chemin Java personnalisé (vide = utiliser java du PATH)
# Exemple: "/usr/lib/jvm/temurin-25-jdk-amd64/bin/java"
JAVA_PATH=""

JAVA_MIN_VERSION=25
JAVA_OPTS="-Xms4G -Xmx8G -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200"
USE_AOT_CACHE="true"

#===============================================================================
#  BACKUP
#===============================================================================

ENABLE_BUILTIN_BACKUP="true"
BACKUP_FREQUENCY=30
MAX_BACKUPS=7
BACKUP_PREFIX="hytale_backup"

#===============================================================================
#  SYSTEMD
#===============================================================================

HYTALE_USER="hytale"
HYTALE_GROUP="hytale"

#===============================================================================
#  TÉLÉCHARGEMENT
#===============================================================================

DOWNLOADER_URL="https://downloader.hytale.com/hytale-downloader.zip"
SERVERCONF

    # Remplacer le placeholder par le vrai chemin
    sed -i "s|__INSTALL_DIR__|${INSTALL_DIR}|g" "${INSTALL_DIR}/config/server.conf" 2>/dev/null || \
    sed -i '' "s|__INSTALL_DIR__|${INSTALL_DIR}|g" "${INSTALL_DIR}/config/server.conf" 2>/dev/null || true
}

create_discord_conf() {
    log_info "Création de config/discord.conf..."
    
    cat > "${INSTALL_DIR}/config/discord.conf" << 'DISCORDCONF'
#===============================================================================
#  HYTALE SERVER - DISCORD WEBHOOKS
#===============================================================================

# Webhook Discord (un seul supporté en mode sh)
# Pour plusieurs webhooks, utilisez bash avec un array
WEBHOOK_URL="https://discord.com/api/webhooks/VOTRE_WEBHOOK_ID/VOTRE_WEBHOOK_TOKEN"

# Couleurs des embeds (format décimal)
COLOR_START="3066993"
COLOR_STOP="15158332"
COLOR_RESTART="15844367"
COLOR_ALERT="15158332"
COLOR_INFO="3447003"
COLOR_SUCCESS="3066993"

# Nom du serveur dans les notifications
SERVER_NAME="Hytale Server"
ALERT_ROLE_MENTION=""
DISCORDCONF
}

# ============== CRÉATION DES SCRIPTS ==============

create_hytale_sh() {
    log_info "Création de hytale.sh..."
    
    cat > "${INSTALL_DIR}/hytale.sh" << 'HYTALESH'
#!/bin/bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/config"

source "${CONFIG_DIR}/server.conf" 2>/dev/null || true
source "${CONFIG_DIR}/discord.conf" 2>/dev/null || true

: "${SERVER_DIR:=${SCRIPT_DIR}/server}"
: "${LOGS_DIR:=${SCRIPT_DIR}/logs}"
: "${BACKUPS_DIR:=${SCRIPT_DIR}/backups}"
: "${ASSETS_DIR:=${SCRIPT_DIR}/assets}"
: "${SERVER_JAR:=HytaleServer.jar}"
: "${ASSETS_FILE:=Assets.zip}"
: "${SCREEN_NAME:=hytale}"
: "${BIND_ADDRESS:=0.0.0.0:5520}"
: "${AUTH_MODE:=authenticated}"
: "${JAVA_MIN_VERSION:=25}"
: "${JAVA_OPTS:=-Xms4G -Xmx8G -XX:+UseG1GC}"
: "${JAVA_PATH:=}"
: "${USE_AOT_CACHE:=true}"
: "${ENABLE_BUILTIN_BACKUP:=true}"
: "${BACKUP_FREQUENCY:=30}"

if [[ -n "${JAVA_PATH}" ]] && [[ -x "${JAVA_PATH}" ]]; then
    JAVA_CMD="${JAVA_PATH}"
else
    JAVA_CMD="java"
fi

ASSETS_PATH="${ASSETS_DIR}/${ASSETS_FILE}"
AOT_CACHE="${SERVER_DIR}/HytaleServer.aot"

log() {
    local level="$1"; shift
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] $*"
    mkdir -p "${LOGS_DIR}"
    echo "[${timestamp}] [${level}] $*" >> "${LOGS_DIR}/hytale.log"
}

is_running() { screen -list | grep -q "\.${SCREEN_NAME}[[:space:]]"; }
get_pid() { pgrep -f "${SERVER_JAR}" 2>/dev/null || echo ""; }

send_discord() {
    local title="$1" desc="$2" color="$3"
    [[ -z "${WEBHOOK_URL:-}" ]] && return 0
    local ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local payload="{\"embeds\":[{\"title\":\"${title}\",\"description\":\"${desc}\",\"color\":${color},\"timestamp\":\"${ts}\"}]}"
    curl -s -H "Content-Type: application/json" -d "${payload}" "${WEBHOOK_URL}" &>/dev/null &
}

cmd_start() {
    if [[ -n "${JAVA_PATH}" ]] && [[ ! -x "${JAVA_PATH}" ]]; then
        log "ERROR" "Java introuvable: ${JAVA_PATH}"; exit 1
    fi
    if ! command -v ${JAVA_CMD} &>/dev/null; then
        log "ERROR" "Java non installé"; exit 1
    fi
    
    local ver=$(${JAVA_CMD} --version 2>&1 | head -n1 | grep -oP '\d+' | head -n1)
    [[ "${ver}" -lt "${JAVA_MIN_VERSION}" ]] && { log "ERROR" "Java ${JAVA_MIN_VERSION}+ requis"; exit 1; }
    
    is_running && { log "WARN" "Serveur déjà en cours"; exit 1; }
    [[ ! -f "${SERVER_DIR}/${SERVER_JAR}" ]] && { log "ERROR" "Serveur introuvable. Lancez: ./update.sh download"; exit 1; }
    [[ ! -f "${ASSETS_PATH}" ]] && { log "ERROR" "Assets introuvables"; exit 1; }
    
    log "INFO" "Démarrage..."
    send_discord "🚀 Démarrage" "Serveur en cours de démarrage..." "${COLOR_START:-3066993}"
    
    local cmd="${JAVA_CMD} ${JAVA_OPTS}"
    [[ "${USE_AOT_CACHE}" == "true" ]] && [[ -f "${AOT_CACHE}" ]] && cmd="${cmd} -XX:AOTCache=${AOT_CACHE}"
    cmd="${cmd} -jar ${SERVER_JAR} --assets ${ASSETS_PATH} --bind ${BIND_ADDRESS} --auth-mode ${AUTH_MODE}"
    [[ "${ENABLE_BUILTIN_BACKUP}" == "true" ]] && cmd="${cmd} --backup --backup-dir ${BACKUPS_DIR} --backup-frequency ${BACKUP_FREQUENCY}"
    
    cd "${SERVER_DIR}"
    screen -dmS "${SCREEN_NAME}" bash -c "${cmd} 2>&1 | tee -a ${LOGS_DIR}/server.log"
    sleep 3
    
    if is_running; then
        log "INFO" "Serveur démarré (screen: ${SCREEN_NAME})"
        ( sleep 30; is_running && send_discord "✅ En ligne" "Serveur opérationnel" "${COLOR_START:-3066993}" ) &
    else
        log "ERROR" "Échec du démarrage"; exit 1
    fi
}

cmd_stop() {
    is_running || { log "WARN" "Serveur non actif"; return 0; }
    log "INFO" "Arrêt..."
    screen -S "${SCREEN_NAME}" -p 0 -X stuff "stop$(printf '\r')"
    local t=30; while is_running && [ $t -gt 0 ]; do sleep 1; t=$((t-1)); done
    is_running && { screen -S "${SCREEN_NAME}" -X quit 2>/dev/null || true; }
    log "INFO" "Arrêté"
    send_discord "🛑 Arrêté" "Serveur arrêté" "${COLOR_STOP:-15158332}"
}

cmd_restart() { log "INFO" "Redémarrage..."; cmd_stop; sleep 5; cmd_start; }

cmd_status() {
    echo "=== HYTALE STATUS ==="
    if is_running; then
        echo "État: 🟢 EN LIGNE"
        echo "Screen: ${SCREEN_NAME}"
    else
        echo "État: 🔴 HORS LIGNE"
    fi
    echo "Adresse: ${BIND_ADDRESS}"
}

cmd_console() {
    is_running || { log "ERROR" "Serveur non actif"; exit 1; }
    echo "Console (Ctrl+A,D pour quitter)"
    screen -r "${SCREEN_NAME}"
}

case "${1:-help}" in
    start) cmd_start ;;
    stop) cmd_stop ;;
    restart) cmd_restart ;;
    status) cmd_status ;;
    console) cmd_console ;;
    *) echo "Usage: $0 {start|stop|restart|status|console}" ;;
esac
HYTALESH
    chmod +x "${INSTALL_DIR}/hytale.sh"
}

create_backup_sh() {
    log_info "Création de backup.sh..."
    
    cat > "${INSTALL_DIR}/backup.sh" << 'BACKUPSH'
#!/bin/bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config/server.conf" 2>/dev/null || true
source "${SCRIPT_DIR}/config/discord.conf" 2>/dev/null || true

: "${SERVER_DIR:=${SCRIPT_DIR}/server}"
: "${BACKUPS_DIR:=${SCRIPT_DIR}/backups}"
: "${MAX_BACKUPS:=7}"
: "${BACKUP_PREFIX:=hytale_backup}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

create_backup() {
    [[ ! -d "${SERVER_DIR}/universe" ]] && { log "ERREUR: universe/ introuvable"; exit 1; }
    mkdir -p "${BACKUPS_DIR}"
    local name="${BACKUP_PREFIX}_$(date '+%Y%m%d_%H%M%S').tar.gz"
    cd "${SERVER_DIR}"
    tar -czf "${BACKUPS_DIR}/${name}" universe/
    log "Backup créé: ${name}"
}

rotate_backups() {
    local count=$(find "${BACKUPS_DIR}" -name "${BACKUP_PREFIX}_*.tar.gz" | wc -l)
    if [ "${count}" -gt "${MAX_BACKUPS}" ]; then
        ls -t "${BACKUPS_DIR}"/${BACKUP_PREFIX}_*.tar.gz | tail -n +$((MAX_BACKUPS+1)) | xargs rm -f
        log "Rotation effectuée"
    fi
}

list_backups() {
    echo "=== BACKUPS ==="
    ls -lh "${BACKUPS_DIR}"/${BACKUP_PREFIX}_*.tar.gz 2>/dev/null || echo "Aucun backup"
}

case "${1:-help}" in
    create) create_backup; rotate_backups ;;
    list) list_backups ;;
    rotate) rotate_backups ;;
    *) echo "Usage: $0 {create|list|rotate}" ;;
esac
BACKUPSH
    chmod +x "${INSTALL_DIR}/backup.sh"
}

create_update_sh() {
    log_info "Création de update.sh..."
    
    cat > "${INSTALL_DIR}/update.sh" << 'UPDATESH'
#!/bin/sh
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
. "${SCRIPT_DIR}/config/server.conf" 2>/dev/null || true
. "${SCRIPT_DIR}/config/discord.conf" 2>/dev/null || true

SERVER_DIR="${SERVER_DIR:-${SCRIPT_DIR}/server}"
ASSETS_DIR="${ASSETS_DIR:-${SCRIPT_DIR}/assets}"
LOGS_DIR="${LOGS_DIR:-${SCRIPT_DIR}/logs}"
PATCHLINE="${PATCHLINE:-release}"
DOWNLOADER_URL="${DOWNLOADER_URL:-https://downloader.hytale.com/hytale-downloader.zip}"
TEMP_DIR="${SCRIPT_DIR}/.tmp"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] $2"; }

detect_platform() {
    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    arch=$(uname -m)
    case "${arch}" in x86_64|amd64) arch="amd64";; aarch64|arm64) arch="arm64";; *) arch="amd64";; esac
    case "${os}" in linux|darwin) echo "linux-${arch}";; *) echo "linux-${arch}";; esac
}

PLATFORM=$(detect_platform)
DOWNLOADER_BIN="${SCRIPT_DIR}/hytale-downloader-${PLATFORM}"

download_downloader() {
    log "INFO" "Téléchargement hytale-downloader..."
    mkdir -p "${TEMP_DIR}"
    curl -fsSL "${DOWNLOADER_URL}" -o "${TEMP_DIR}/dl.zip"
    unzip -o "${TEMP_DIR}/dl.zip" -d "${TEMP_DIR}/ext" >/dev/null 2>&1
    bin="${TEMP_DIR}/ext/hytale-downloader-${PLATFORM}"
    [ -f "${bin}" ] && cp "${bin}" "${DOWNLOADER_BIN}" || cp $(find "${TEMP_DIR}/ext" -name "hytale-downloader-linux-*" | head -1) "${DOWNLOADER_BIN}"
    chmod +x "${DOWNLOADER_BIN}"
    rm -rf "${TEMP_DIR}"
    log "INFO" "Installé: ${DOWNLOADER_BIN}"
}

cmd_download() {
    [ ! -x "${DOWNLOADER_BIN}" ] && download_downloader
    log "INFO" "Téléchargement serveur (${PATCHLINE})..."
    mkdir -p "${TEMP_DIR}"
    
    if ${DOWNLOADER_BIN} -download-path "${TEMP_DIR}/game.zip"; then
        mkdir -p "${SERVER_DIR}" "${ASSETS_DIR}"
        unzip -o "${TEMP_DIR}/game.zip" -d "${TEMP_DIR}/ext" >/dev/null 2>&1
        [ -f "${TEMP_DIR}/ext/Server/HytaleServer.jar" ] && cp "${TEMP_DIR}/ext/Server/HytaleServer.jar" "${SERVER_DIR}/"
        [ -f "${TEMP_DIR}/ext/HytaleServer.jar" ] && cp "${TEMP_DIR}/ext/HytaleServer.jar" "${SERVER_DIR}/"
        [ -f "${TEMP_DIR}/ext/Assets.zip" ] && cp "${TEMP_DIR}/ext/Assets.zip" "${ASSETS_DIR}/"
        rm -rf "${TEMP_DIR}"
        log "INFO" "Installation terminée"
    else
        log "ERROR" "Échec du téléchargement"
        rm -rf "${TEMP_DIR}"
        exit 1
    fi
}

cmd_check() {
    [ ! -x "${DOWNLOADER_BIN}" ] && download_downloader
    echo "=== VERSIONS ==="
    v=$(${DOWNLOADER_BIN} -print-version 2>/dev/null || echo "N/A")
    echo "Disponible: $v"
    [ -f "${SERVER_DIR}/HytaleServer.jar" ] && echo "Installé: Oui" || echo "Installé: Non"
}

case "${1:-help}" in
    download) cmd_download ;;
    check) cmd_check ;;
    auth-reset) rm -f "${SCRIPT_DIR}/.hytale-downloader-credentials.json"; log "INFO" "Credentials supprimés" ;;
    *) echo "Usage: $0 {download|check|auth-reset}" ;;
esac
UPDATESH
    chmod +x "${INSTALL_DIR}/update.sh"
}

create_auth_sh() {
    log_info "Création de hytale-auth.sh..."
    
    cat > "${INSTALL_DIR}/hytale-auth.sh" << 'AUTHSH'
#!/bin/bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/config/server.conf" 2>/dev/null || true

: "${SCREEN_NAME:=hytale}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] $2"; }

cmd_status() {
    echo "=== AUTH STATUS ==="
    echo "Pour s'authentifier:"
    echo "1. ./hytale.sh start"
    echo "2. ./hytale.sh console"
    echo "3. Tapez: /auth login device"
    echo "4. Visitez: https://accounts.hytale.com/device"
}

cmd_trigger() {
    if ! screen -list | grep -q "\.${SCREEN_NAME}"; then
        log "ERROR" "Serveur non actif"; exit 1
    fi
    screen -S "${SCREEN_NAME}" -p 0 -X stuff "/auth login device$(printf '\r')"
    log "INFO" "Commande envoyée. Vérifiez la console."
}

case "${1:-help}" in
    status) cmd_status ;;
    trigger) cmd_trigger ;;
    *) echo "Usage: $0 {status|trigger}" ;;
esac
AUTHSH
    chmod +x "${INSTALL_DIR}/hytale-auth.sh"
}

create_readme() {
    log_info "Création de README.md..."
    
    cat > "${INSTALL_DIR}/README.md" << 'README'
# 🎮 Serveur Hytale

## Commandes

| Commande | Description |
|----------|-------------|
| `./update.sh download` | Télécharger le serveur |
| `./hytale.sh start` | Démarrer |
| `./hytale.sh stop` | Arrêter |
| `./hytale.sh console` | Console |
| `./backup.sh create` | Backup |

## Configuration

- `config/server.conf` - Configuration principale
- `config/discord.conf` - Webhooks Discord

## Prérequis

- Java 25+ (Temurin recommandé)
- Port UDP 5520

## Authentification

1. `./hytale.sh start`
2. `./hytale.sh console`
3. `/auth login device`
4. https://accounts.hytale.com/device
README
}

# ============== INSTALLATION SYSTEMD ==============

install_systemd() {
    log_info "Installation des services systemd..."
    
    cat > /etc/systemd/system/hytale.service << EOF
[Unit]
Description=Hytale Server
After=network.target

[Service]
Type=forking
User=${HYTALE_USER}
Group=${HYTALE_GROUP}
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/hytale.sh start
ExecStop=${INSTALL_DIR}/hytale.sh stop
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    cat > /etc/systemd/system/hytale-backup.service << EOF
[Unit]
Description=Hytale Backup

[Service]
Type=oneshot
User=${HYTALE_USER}
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/backup.sh create
EOF

    cat > /etc/systemd/system/hytale-backup.timer << EOF
[Unit]
Description=Hytale Backup Timer

[Timer]
OnCalendar=*-*-* 00/6:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable hytale.service
    systemctl enable hytale-backup.timer
    
    log_success "Services systemd installés."
}

# ============== MAIN ==============

echo "============================================"
echo "  HYTALE SERVER - INSTALLATION"
echo "============================================"
echo ""
echo "Répertoire: ${INSTALL_DIR}"
echo ""

create_directories
create_server_conf
create_discord_conf
create_hytale_sh
create_backup_sh
create_update_sh
create_auth_sh
create_readme

# Permissions
chmod +x "${INSTALL_DIR}"/*.sh 2>/dev/null || true

# Systemd (seulement si root)
if [ "$(id -u)" -eq 0 ]; then
    install_systemd
else
    log_warn "Exécutez avec sudo pour installer systemd"
fi

echo ""
printf "\033[0;32m=== INSTALLATION TERMINÉE ===\033[0m\n"
echo ""
echo "Prochaines étapes:"
echo "  1. nano config/server.conf   (server)"
echo "  2. nano config/discord.conf  (webhooks)"
echo "  3. ./update.sh download      (télécharger)"
echo "  4. ./hytale.sh start         (démarrer)"
echo ""
