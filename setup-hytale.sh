#!/bin/sh
#===============================================================================
#  HYTALE SERVER - INSTALLATION INTERACTIVE
#  Télécharge et installe tous les fichiers depuis GitHub
#  Compatible: sh, bash, dash | Bilingue FR/EN
#===============================================================================

set -e

# Configuration GitHub
GITHUB_REPO="thefrcrazy/hytale-server"
GITHUB_BRANCH="main"
GITHUB_RAW="https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}"

# Variables globales
DEFAULT_INSTALL_DIR="/opt/hytale"
INSTALL_DIR=""
HYTALE_USER=""
HYTALE_GROUP=""
OS_NAME=""
OS_PRETTY=""
LANG_CODE="fr"

# Configuration
CFG_PORT="5520"
CFG_SERVER_NAME="Hytale Server"
CFG_MAX_PLAYERS="20"
CFG_WEBHOOK_URL=""
CFG_WEBHOOK_USERNAME=""
CFG_AUTO_DOWNLOAD="n"
CFG_START_AFTER="n"

# Résumés des étapes
STEP_SUMMARY_1=""
STEP_SUMMARY_2=""
STEP_SUMMARY_3=""
STEP_SUMMARY_4=""
STEP_SUMMARY_5=""
STEP_SUMMARY_6=""
STEP_SUMMARY_7=""
STEP_SUMMARY_8=""
STEP_SUMMARY_9=""
STEP_SUMMARY_10=""

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

# ============== TRADUCTIONS ==============

t() {
    key="$1"
    case "${LANG_CODE}" in
        fr)
            case "${key}" in
                "welcome") echo "Bienvenue dans l'installation du serveur Hytale dédié !" ;;
                "source") echo "Source" ;;
                "continue") echo "Continuer l'installation ?" ;;
                "cancelled") echo "Installation annulée." ;;
                "step") echo "Étape" ;;
                "system") echo "Système" ;;
                "directory") echo "Répertoire" ;;
                "user") echo "Utilisateur" ;;
                "deps") echo "Dépendances" ;;
                "java") echo "Java" ;;
                "server_config") echo "Config Serveur" ;;
                "discord_config") echo "Config Discord" ;;
                "download") echo "Téléchargement" ;;
                "options") echo "Options" ;;
                "systemd") echo "Systemd" ;;
                "current_dir") echo "Répertoire actuel" ;;
                "default_path") echo "Chemin par défaut" ;;
                "other_path") echo "Autre chemin" ;;
                "your_choice") echo "Votre choix" ;;
                "create_folder") echo "Créer le dossier ?" ;;
                "port") echo "Port UDP" ;;
                "server_name") echo "Nom du serveur" ;;
                "max_players") echo "Joueurs max" ;;
                "webhook_url") echo "Webhook URL Discord" ;;
                "webhook_user") echo "Nom du bot Discord" ;;
                "skip_empty") echo "laissez vide pour ignorer" ;;
                "auto_download") echo "Télécharger le serveur maintenant ?" ;;
                "start_after") echo "Démarrer le serveur après l'installation ?" ;;
                "install_deps") echo "Installer les dépendances manquantes ?" ;;
                "install_pigz") echo "Installer pigz (backups rapides) ?" ;;
                "java_required") echo "Java 25+ requis" ;;
                "continue_without") echo "Continuer sans Java ?" ;;
                "config_done") echo "Configuration terminée" ;;
                "files") echo "fichiers" ;;
                "existing_kept") echo "existant, conservé" ;;
                "auto_boot") echo "Démarrage auto au boot ?" ;;
                "auto_backup") echo "Backups auto (6h) ?" ;;
                "auto_watchdog") echo "Watchdog (2min) ?" ;;
                "complete") echo "INSTALLATION TERMINÉE !" ;;
                "next_steps") echo "Prochaines étapes" ;;
                "edit_config") echo "Modifier la configuration" ;;
                "start_server") echo "Démarrer le serveur" ;;
                "auto_download_info") echo "Le serveur sera téléchargé automatiquement si nécessaire." ;;
                "example") echo "exemple" ;;
                "default") echo "défaut" ;;
                *) echo "${key}" ;;
            esac
            ;;
        en)
            case "${key}" in
                "welcome") echo "Welcome to the Hytale Dedicated Server installer!" ;;
                "source") echo "Source" ;;
                "continue") echo "Continue installation?" ;;
                "cancelled") echo "Installation cancelled." ;;
                "step") echo "Step" ;;
                "system") echo "System" ;;
                "directory") echo "Directory" ;;
                "user") echo "User" ;;
                "deps") echo "Dependencies" ;;
                "java") echo "Java" ;;
                "server_config") echo "Server Config" ;;
                "discord_config") echo "Discord Config" ;;
                "download") echo "Download" ;;
                "options") echo "Options" ;;
                "systemd") echo "Systemd" ;;
                "current_dir") echo "Current directory" ;;
                "default_path") echo "Default path" ;;
                "other_path") echo "Other path" ;;
                "your_choice") echo "Your choice" ;;
                "create_folder") echo "Create folder?" ;;
                "port") echo "UDP Port" ;;
                "server_name") echo "Server name" ;;
                "max_players") echo "Max players" ;;
                "webhook_url") echo "Discord Webhook URL" ;;
                "webhook_user") echo "Discord bot name" ;;
                "skip_empty") echo "leave empty to skip" ;;
                "auto_download") echo "Download server now?" ;;
                "start_after") echo "Start server after installation?" ;;
                "install_deps") echo "Install missing dependencies?" ;;
                "install_pigz") echo "Install pigz (faster backups)?" ;;
                "java_required") echo "Java 25+ required" ;;
                "continue_without") echo "Continue without Java?" ;;
                "config_done") echo "Configuration complete" ;;
                "files") echo "files" ;;
                "existing_kept") echo "existing, kept" ;;
                "auto_boot") echo "Auto-start on boot?" ;;
                "auto_backup") echo "Auto backups (6h)?" ;;
                "auto_watchdog") echo "Watchdog (2min)?" ;;
                "complete") echo "INSTALLATION COMPLETE!" ;;
                "next_steps") echo "Next steps" ;;
                "edit_config") echo "Edit configuration" ;;
                "start_server") echo "Start server" ;;
                "auto_download_info") echo "The server will be downloaded automatically if needed." ;;
                "example") echo "example" ;;
                "default") echo "default" ;;
                *) echo "${key}" ;;
            esac
            ;;
    esac
}

# ============== AFFICHAGE ==============

print_header() {
    clear
    printf "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║           🎮 HYTALE DEDICATED SERVER SETUP 🎮              ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    printf "${NC}\n"
}

print_progress() {
    current_step="$1"
    total_steps="10"
    
    print_header
    
    # Afficher le récap des étapes terminées
    [ -n "${STEP_SUMMARY_1}" ] && printf "${DIM}1. $(t system):       ${STEP_SUMMARY_1}${NC}\n"
    [ -n "${STEP_SUMMARY_2}" ] && printf "${DIM}2. $(t directory):    ${STEP_SUMMARY_2}${NC}\n"
    [ -n "${STEP_SUMMARY_3}" ] && printf "${DIM}3. $(t user):   ${STEP_SUMMARY_3}${NC}\n"
    [ -n "${STEP_SUMMARY_4}" ] && printf "${DIM}4. $(t deps):   ${STEP_SUMMARY_4}${NC}\n"
    [ -n "${STEP_SUMMARY_5}" ] && printf "${DIM}5. $(t java):          ${STEP_SUMMARY_5}${NC}\n"
    [ -n "${STEP_SUMMARY_6}" ] && printf "${DIM}6. $(t server_config): ${STEP_SUMMARY_6}${NC}\n"
    [ -n "${STEP_SUMMARY_7}" ] && printf "${DIM}7. $(t discord_config): ${STEP_SUMMARY_7}${NC}\n"
    [ -n "${STEP_SUMMARY_8}" ] && printf "${DIM}8. $(t download): ${STEP_SUMMARY_8}${NC}\n"
    [ -n "${STEP_SUMMARY_9}" ] && printf "${DIM}9. $(t options):       ${STEP_SUMMARY_9}${NC}\n"
    [ -n "${STEP_SUMMARY_10}" ] && printf "${DIM}10. $(t systemd):     ${STEP_SUMMARY_10}${NC}\n"
    
    [ -n "${STEP_SUMMARY_1}" ] && echo ""
    
    printf "${BOLD}${BLUE}━━━ $(t step) ${current_step}/${total_steps}: "
    case "${current_step}" in
        1) printf "$(t system)" ;;
        2) printf "$(t directory)" ;;
        3) printf "$(t user)" ;;
        4) printf "$(t deps)" ;;
        5) printf "$(t java)" ;;
        6) printf "$(t server_config)" ;;
        7) printf "$(t discord_config)" ;;
        8) printf "$(t download)" ;;
        9) printf "$(t options)" ;;
        10) printf "$(t systemd)" ;;
    esac
    printf " ━━━${NC}\n\n"
}

log_info() { echo "[INFO] $*"; }
log_success() { echo "[OK] $*"; }
log_warn() { echo "[WARN] $*"; }
log_error() { echo "[ERROR] $*"; }

prompt() {
    msg="$1"
    default="$2"
    example="$3"
    
    if [ -n "${default}" ]; then
        printf ">> %s [%s]: " "${msg}" "${default}" >&2
    elif [ -n "${example}" ]; then
        printf ">> %s ($(t example): %s): " "${msg}" "${example}" >&2
    else
        printf ">> %s: " "${msg}" >&2
    fi
    read -r response
    [ -z "${response}" ] && response="${default}"
    echo "${response}"
}

prompt_yn() {
    msg="$1"
    default="$2"
    while true; do
        if [ "${default}" = "y" ]; then
            printf ">> %s [Y/n]: " "${msg}"
        else
            printf ">> %s [y/N]: " "${msg}"
        fi
        read -r response
        [ -z "${response}" ] && response="${default}"
        case "${response}" in
            [Yy]*|[Oo]*) return 0 ;;
            [Nn]*) return 1 ;;
        esac
    done
}

# ============== DETECTION OS ==============

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME="${ID}"
        OS_PRETTY="${PRETTY_NAME:-${OS_NAME}}"
    elif [ -f /etc/debian_version ]; then
        OS_NAME="debian"
        OS_PRETTY="Debian"
    elif [ -f /etc/redhat-release ]; then
        OS_NAME="rhel"
        OS_PRETTY="RHEL/CentOS"
    elif [ "$(uname)" = "Darwin" ]; then
        OS_NAME="macos"
        OS_PRETTY="macOS"
    else
        OS_NAME="unknown"
        OS_PRETTY="Unknown"
    fi
}

check_root() {
    [ "$(id -u)" -eq 0 ]
}

install_package() {
    pkg="$1"
    case "${OS_NAME}" in
        ubuntu|debian|linuxmint|pop)
            apt-get update -qq >/dev/null 2>&1
            apt-get install -y -qq "${pkg}" >/dev/null 2>&1
            ;;
        centos|rhel|fedora|rocky|almalinux)
            if command -v dnf >/dev/null 2>&1; then
                dnf install -y -q "${pkg}" >/dev/null 2>&1
            else
                yum install -y -q "${pkg}" >/dev/null 2>&1
            fi
            ;;
        macos)
            if command -v brew >/dev/null 2>&1; then
                brew install "${pkg}" >/dev/null 2>&1
            fi
            ;;
    esac
}

# ============== ÉTAPES D'INSTALLATION ==============

step_language() {
    print_header
    echo "🌐 Select language / Choisir la langue:"
    echo ""
    echo "  1) Français"
    echo "  2) English"
    echo ""
    choice=$(prompt "$(t your_choice)" "1")
    
    case "${choice}" in
        2|en|EN) LANG_CODE="en" ;;
        *) LANG_CODE="fr" ;;
    esac
}

step_welcome() {
    print_header
    echo "$(t welcome)"
    echo ""
    echo "Ce script va / This script will:"
    echo "  • Vérifier les dépendances / Check dependencies"
    echo "  • Configurer le serveur / Configure server"
    echo "  • Télécharger les scripts / Download scripts"
    echo ""
    printf "$(t source): ${BOLD}github.com/${GITHUB_REPO}${NC}\n"
    echo ""
    
    if ! prompt_yn "$(t continue)" "y"; then
        echo "$(t cancelled)"
        exit 0
    fi
}

step_1_detect() {
    print_progress 1
    
    detect_os
    
    priv_status="user"
    check_root && priv_status="root"
    
    printf "$(t system): ${BOLD}${OS_PRETTY}${NC}\n"
    printf "Privileges: ${BOLD}${priv_status}${NC}\n"
    
    STEP_SUMMARY_1="${OS_PRETTY} (${priv_status})"
    
    sleep 1
}

step_2_install_dir() {
    print_progress 2
    
    current_dir="$(pwd)"
    
    echo "1) $(t current_dir): ${current_dir}"
    echo "2) $(t default_path): ${DEFAULT_INSTALL_DIR}"
    echo "3) $(t other_path)"
    echo ""
    
    choice=$(prompt "$(t your_choice)" "1")
    
    case "${choice}" in
        1) INSTALL_DIR="${current_dir}" ;;
        2) INSTALL_DIR="${DEFAULT_INSTALL_DIR}" ;;
        3) INSTALL_DIR=$(prompt "Path" "${DEFAULT_INSTALL_DIR}") ;;
        *) INSTALL_DIR="${current_dir}" ;;
    esac
    
    if [ ! -d "${INSTALL_DIR}" ]; then
        if prompt_yn "$(t create_folder)" "y"; then
            mkdir -p "${INSTALL_DIR}"
        else
            log_error "$(t cancelled)"
            exit 1
        fi
    fi
    
    STEP_SUMMARY_2="${INSTALL_DIR}"
}

step_3_user() {
    print_progress 3
    
    current_user=$(whoami)
    
    HYTALE_USER="${current_user}"
    if [ "${OS_NAME}" = "macos" ]; then
        HYTALE_GROUP="staff"
    else
        HYTALE_GROUP="${current_user}"
    fi
    
    echo "$(t user): ${HYTALE_USER}:${HYTALE_GROUP}"
    STEP_SUMMARY_3="${HYTALE_USER}:${HYTALE_GROUP}"
    
    sleep 1
}

step_4_dependencies() {
    print_progress 4
    
    deps_missing=""
    
    for dep in curl unzip screen; do
        if command -v "${dep}" >/dev/null 2>&1; then
            printf "  ${GREEN}✓${NC} ${dep}\n"
        else
            printf "  ${RED}✗${NC} ${dep}\n"
            deps_missing="${deps_missing} ${dep}"
        fi
    done
    
    echo ""
    
    if [ -n "${deps_missing}" ]; then
        if check_root; then
            if prompt_yn "$(t install_deps)" "y"; then
                for dep in ${deps_missing}; do
                    printf "  Installing ${dep}..."
                    if install_package "${dep}"; then
                        printf " ${GREEN}OK${NC}\n"
                    else
                        printf " ${RED}FAIL${NC}\n"
                    fi
                done
                STEP_SUMMARY_4="OK"
            else
                log_error "$(t cancelled)"
                exit 1
            fi
        else
            log_error "Run with sudo"
            exit 1
        fi
    else
        STEP_SUMMARY_4="OK"
    fi
    
    # pigz (optionnel, skip sur macOS)
    if [ "${OS_NAME}" != "macos" ] && ! command -v pigz >/dev/null 2>&1 && check_root; then
        echo ""
        if prompt_yn "$(t install_pigz)" "y"; then
            install_package pigz
            STEP_SUMMARY_4="${STEP_SUMMARY_4} + pigz"
        fi
    fi
}

step_5_java() {
    print_progress 5
    
    java_ok=0
    java_info="Not installed"
    
    if command -v java >/dev/null 2>&1; then
        java_version=$(java --version 2>&1 | head -n1 || echo "?")
        java_major=$(echo "${java_version}" | grep -oE '[0-9]+' | head -n1 || echo "0")
        
        printf "Version: ${java_version}\n"
        
        if [ "${java_major}" -ge 25 ] 2>/dev/null; then
            log_success "Java ${java_major} OK"
            java_ok=1
            java_info="Java ${java_major} ✓"
        else
            log_warn "Java ${java_major} < 25 - $(t java_required)"
            java_info="Java ${java_major}"
        fi
    else
        log_warn "$(t java_required)"
    fi
    
    if [ ${java_ok} -eq 0 ]; then
        echo ""
        printf "Install Java 25: ${BOLD}https://adoptium.net/${NC}\n"
        echo ""
        if ! prompt_yn "$(t continue_without)" "y"; then
            exit 1
        fi
    fi
    
    STEP_SUMMARY_5="${java_info}"
}

step_6_server_config() {
    print_progress 6
    
    # Charger config existante si disponible
    if [ -f "${INSTALL_DIR}/config/server.conf" ]; then
        . "${INSTALL_DIR}/config/server.conf" 2>/dev/null || true
        CFG_PORT="${BIND_ADDRESS##*:}"
        CFG_PORT="${CFG_PORT:-5520}"
        CFG_SERVER_NAME="${SERVER_NAME:-Hytale Server}"
        CFG_MAX_PLAYERS="${MAX_PLAYERS:-20}"
    fi
    
    echo "$(t port) ($(t default): 5520)"
    CFG_PORT=$(prompt "Port" "${CFG_PORT}")
    
    echo ""
    echo "$(t server_name)"
    CFG_SERVER_NAME=$(prompt "Name" "${CFG_SERVER_NAME}")
    
    echo ""
    echo "$(t max_players)"
    CFG_MAX_PLAYERS=$(prompt "Max" "${CFG_MAX_PLAYERS}")
    
    STEP_SUMMARY_6="Port ${CFG_PORT}, ${CFG_MAX_PLAYERS} players"
}

step_7_discord_config() {
    print_progress 7
    
    # Charger config existante si disponible
    if [ -f "${INSTALL_DIR}/config/discord.conf" ]; then
        . "${INSTALL_DIR}/config/discord.conf" 2>/dev/null || true
        CFG_WEBHOOK_URL="${WEBHOOK_URL:-}"
        CFG_WEBHOOK_USERNAME="${WEBHOOK_USERNAME:-}"
    fi
    
    echo "$(t webhook_url) ($(t skip_empty))"
    echo "$(t example): https://discord.com/api/webhooks/123/abc"
    CFG_WEBHOOK_URL=$(prompt "URL" "${CFG_WEBHOOK_URL}")
    
    if [ -n "${CFG_WEBHOOK_URL}" ]; then
        echo ""
        echo "$(t webhook_user)"
        CFG_WEBHOOK_USERNAME=$(prompt "Bot name" "${CFG_WEBHOOK_USERNAME:-Hytale Bot}")
        STEP_SUMMARY_7="Webhook ✓"
    else
        STEP_SUMMARY_7="Skipped"
    fi
}

step_8_download() {
    print_progress 8
    
    downloaded=0
    failed=0
    
    download_file() {
        local_path="$1"
        remote_path="$2"
        
        mkdir -p "$(dirname "${INSTALL_DIR}/${local_path}")"
        
        if curl -fsSL "${GITHUB_RAW}/${remote_path}" -o "${INSTALL_DIR}/${local_path}" 2>/dev/null; then
            printf "  ${GREEN}✓${NC} ${local_path}\n"
            downloaded=$((downloaded + 1))
        else
            printf "  ${RED}✗${NC} ${local_path}\n"
            failed=$((failed + 1))
        fi
    }
    
    # Scripts (toujours mis à jour)
    download_file "hytale.sh" "hytale.sh"
    download_file "lib/utils.sh" "lib/utils.sh"
    download_file "scripts/update.sh" "scripts/update.sh"
    download_file "scripts/backup.sh" "scripts/backup.sh"
    download_file "scripts/watchdog.sh" "scripts/watchdog.sh"
    download_file "scripts/status-live.sh" "scripts/status-live.sh"
    download_file "scripts/hytale-auth.sh" "scripts/hytale-auth.sh"
    
    # Config templates (seulement si n'existent pas)
    if [ ! -f "${INSTALL_DIR}/config/server.conf" ]; then
        download_file "config/server.conf" "config/server.conf"
    else
        printf "  ${YELLOW}⊘${NC} config/server.conf ($(t existing_kept))\n"
    fi
    
    if [ ! -f "${INSTALL_DIR}/config/discord.conf" ]; then
        download_file "config/discord.conf" "config/discord.conf"
    else
        printf "  ${YELLOW}⊘${NC} config/discord.conf ($(t existing_kept))\n"
    fi
    
    # Services
    download_file "services/hytale.service" "services/hytale.service"
    download_file "services/hytale-backup.service" "services/hytale-backup.service"
    download_file "services/hytale-backup.timer" "services/hytale-backup.timer"
    download_file "services/hytale-watchdog.service" "services/hytale-watchdog.service"
    download_file "services/hytale-watchdog.timer" "services/hytale-watchdog.timer"
    
    # Docs
    download_file "README.md" "README.md"
    download_file "LICENSE" "LICENSE"
    
    STEP_SUMMARY_8="${downloaded} $(t files)"
    if [ ${failed} -gt 0 ]; then
        STEP_SUMMARY_8="${STEP_SUMMARY_8} (${failed} failed)"
    fi
}

step_9_options() {
    print_progress 9
    
    echo "$(t auto_download)"
    if prompt_yn "Download Hytale server now?" "n"; then
        CFG_AUTO_DOWNLOAD="y"
    fi
    
    echo ""
    echo "$(t start_after)"
    if prompt_yn "Start after install?" "n"; then
        CFG_START_AFTER="y"
    fi
    
    opts=""
    [ "${CFG_AUTO_DOWNLOAD}" = "y" ] && opts="Download"
    [ "${CFG_START_AFTER}" = "y" ] && opts="${opts} Start"
    [ -z "${opts}" ] && opts="None"
    
    STEP_SUMMARY_9="${opts}"
}

step_10_configure() {
    printf "Applying configuration...\n"
    
    # Appliquer la configuration à server.conf
    config_file="${INSTALL_DIR}/config/server.conf"
    if [ -f "${config_file}" ]; then
        if [ "$(uname)" = "Darwin" ]; then
            sed -i '' "s|__INSTALL_DIR__|${INSTALL_DIR}|g" "${config_file}" 2>/dev/null || true
            sed -i '' "s|^BIND_ADDRESS=.*|BIND_ADDRESS=\"0.0.0.0:${CFG_PORT}\"|" "${config_file}" 2>/dev/null || true
            sed -i '' "s|^SERVER_NAME=.*|SERVER_NAME=\"${CFG_SERVER_NAME}\"|" "${config_file}" 2>/dev/null || true
            sed -i '' "s|^MAX_PLAYERS=.*|MAX_PLAYERS=\"${CFG_MAX_PLAYERS}\"|" "${config_file}" 2>/dev/null || true
        else
            sed -i "s|__INSTALL_DIR__|${INSTALL_DIR}|g" "${config_file}" 2>/dev/null || true
            sed -i "s|^BIND_ADDRESS=.*|BIND_ADDRESS=\"0.0.0.0:${CFG_PORT}\"|" "${config_file}" 2>/dev/null || true
            sed -i "s|^SERVER_NAME=.*|SERVER_NAME=\"${CFG_SERVER_NAME}\"|" "${config_file}" 2>/dev/null || true
            sed -i "s|^MAX_PLAYERS=.*|MAX_PLAYERS=\"${CFG_MAX_PLAYERS}\"|" "${config_file}" 2>/dev/null || true
        fi
    fi
    
    # Appliquer la configuration à discord.conf
    discord_file="${INSTALL_DIR}/config/discord.conf"
    if [ -f "${discord_file}" ] && [ -n "${CFG_WEBHOOK_URL}" ]; then
        if [ "$(uname)" = "Darwin" ]; then
            sed -i '' "s|^WEBHOOK_URL=.*|WEBHOOK_URL=\"${CFG_WEBHOOK_URL}\"|" "${discord_file}" 2>/dev/null || true
            sed -i '' "s|^WEBHOOK_USERNAME=.*|WEBHOOK_USERNAME=\"${CFG_WEBHOOK_USERNAME}\"|" "${discord_file}" 2>/dev/null || true
        else
            sed -i "s|^WEBHOOK_URL=.*|WEBHOOK_URL=\"${CFG_WEBHOOK_URL}\"|" "${discord_file}" 2>/dev/null || true
            sed -i "s|^WEBHOOK_USERNAME=.*|WEBHOOK_USERNAME=\"${CFG_WEBHOOK_USERNAME}\"|" "${discord_file}" 2>/dev/null || true
        fi
    fi
    
    # Mettre à jour les services systemd
    for f in "${INSTALL_DIR}/services/"*.service "${INSTALL_DIR}/services/"*.timer; do
        [ ! -f "$f" ] && continue
        if [ "$(uname)" = "Darwin" ]; then
            sed -i '' "s|/opt/hytale|${INSTALL_DIR}|g" "$f" 2>/dev/null || true
            sed -i '' "s|User=hytale|User=${HYTALE_USER}|g" "$f" 2>/dev/null || true
            sed -i '' "s|Group=hytale|Group=${HYTALE_GROUP}|g" "$f" 2>/dev/null || true
        else
            sed -i "s|/opt/hytale|${INSTALL_DIR}|g" "$f" 2>/dev/null || true
            sed -i "s|User=hytale|User=${HYTALE_USER}|g" "$f" 2>/dev/null || true
            sed -i "s|Group=hytale|Group=${HYTALE_GROUP}|g" "$f" 2>/dev/null || true
        fi
    done
    
    # Permissions
    chmod +x "${INSTALL_DIR}/hytale.sh" 2>/dev/null || true
    chmod +x "${INSTALL_DIR}/lib/utils.sh" 2>/dev/null || true
    chmod +x "${INSTALL_DIR}/scripts/"*.sh 2>/dev/null || true
    
    # Créer les dossiers
    mkdir -p "${INSTALL_DIR}/server/mods"
    mkdir -p "${INSTALL_DIR}/server/plugins"
    mkdir -p "${INSTALL_DIR}/server/universe"
    mkdir -p "${INSTALL_DIR}/backups"
    mkdir -p "${INSTALL_DIR}/logs/archive"
    mkdir -p "${INSTALL_DIR}/assets"
    
    log_success "$(t config_done)"
}

step_11_systemd() {
    print_progress 10
    
    if [ ! -d "/etc/systemd/system" ]; then
        log_warn "Systemd not available"
        STEP_SUMMARY_10="N/A"
        return
    fi
    
    if ! check_root; then
        log_warn "Need sudo for systemd"
        STEP_SUMMARY_10="Skipped (no root)"
        return
    fi
    
    if prompt_yn "Install systemd services?" "y"; then
        cp "${INSTALL_DIR}/services/"*.service /etc/systemd/system/ 2>/dev/null
        cp "${INSTALL_DIR}/services/"*.timer /etc/systemd/system/ 2>/dev/null
        systemctl daemon-reload
        
        services_enabled=""
        
        if prompt_yn "$(t auto_boot)" "y"; then
            systemctl enable hytale.service 2>/dev/null || true
            services_enabled="hytale"
        fi
        
        if prompt_yn "$(t auto_backup)" "y"; then
            systemctl enable hytale-backup.timer 2>/dev/null || true
            services_enabled="${services_enabled} backup"
        fi
        
        if prompt_yn "$(t auto_watchdog)" "y"; then
            systemctl enable hytale-watchdog.timer 2>/dev/null || true
            services_enabled="${services_enabled} watchdog"
        fi
        
        STEP_SUMMARY_10="${services_enabled:-None}"
    else
        STEP_SUMMARY_10="Skipped"
    fi
}

step_post_install() {
    # Auto-download si demandé
    if [ "${CFG_AUTO_DOWNLOAD}" = "y" ]; then
        echo ""
        echo "Downloading Hytale server..."
        "${INSTALL_DIR}/scripts/update.sh" download || true
    fi
    
    # Auto-start si demandé
    if [ "${CFG_START_AFTER}" = "y" ]; then
        echo ""
        echo "Starting server..."
        "${INSTALL_DIR}/hytale.sh" start || true
    fi
}

step_complete() {
    print_header
    
    # Récap final
    printf "${DIM}"
    echo "1.  $(t system):        ${STEP_SUMMARY_1}"
    echo "2.  $(t directory):     ${STEP_SUMMARY_2}"
    echo "3.  $(t user):          ${STEP_SUMMARY_3}"
    echo "4.  $(t deps):          ${STEP_SUMMARY_4}"
    echo "5.  $(t java):          ${STEP_SUMMARY_5}"
    echo "6.  $(t server_config): ${STEP_SUMMARY_6}"
    echo "7.  $(t discord_config): ${STEP_SUMMARY_7}"
    echo "8.  $(t download):      ${STEP_SUMMARY_8}"
    echo "9.  $(t options):       ${STEP_SUMMARY_9}"
    echo "10. $(t systemd):       ${STEP_SUMMARY_10}"
    printf "${NC}\n"
    
    printf "${GREEN}"
    echo "═══════════════════════════════════════════════════════════"
    echo "              ✅ $(t complete)"
    echo "═══════════════════════════════════════════════════════════"
    printf "${NC}\n"
    
    echo "$(t next_steps):"
    echo ""
    if [ "${CFG_AUTO_DOWNLOAD}" != "y" ]; then
        printf "  1. ${CYAN}cd ${INSTALL_DIR} && ./hytale.sh start${NC}\n"
        echo ""
        echo "$(t auto_download_info)"
    else
        printf "  1. ${CYAN}cd ${INSTALL_DIR} && ./hytale.sh status${NC}\n"
    fi
    echo ""
}

# ============== MAIN ==============

main() {
    step_language
    step_welcome
    step_1_detect
    step_2_install_dir
    step_3_user
    step_4_dependencies
    step_5_java
    step_6_server_config
    step_7_discord_config
    step_8_download
    step_9_options
    step_10_configure
    step_11_systemd
    step_post_install
    step_complete
}

main "$@"
