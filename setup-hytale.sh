#!/bin/sh
#===============================================================================
#  HYTALE SERVER - INSTALLATION INTERACTIVE
#  Télécharge et installe tous les fichiers depuis GitHub
#  Compatible: sh, bash, dash
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

# Résumés des étapes
STEP_SUMMARY_1=""
STEP_SUMMARY_2=""
STEP_SUMMARY_3=""
STEP_SUMMARY_4=""
STEP_SUMMARY_5=""
STEP_SUMMARY_6=""
STEP_SUMMARY_7=""
STEP_SUMMARY_8=""

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

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
    
    print_header
    
    # Afficher le récap des étapes terminées
    if [ -n "${STEP_SUMMARY_1}" ]; then
        printf "${DIM}1. Système:       ${STEP_SUMMARY_1}${NC}\n"
    fi
    if [ -n "${STEP_SUMMARY_2}" ]; then
        printf "${DIM}2. Répertoire:    ${STEP_SUMMARY_2}${NC}\n"
    fi
    if [ -n "${STEP_SUMMARY_3}" ]; then
        printf "${DIM}3. Utilisateur:   ${STEP_SUMMARY_3}${NC}\n"
    fi
    if [ -n "${STEP_SUMMARY_4}" ]; then
        printf "${DIM}4. Dépendances:   ${STEP_SUMMARY_4}${NC}\n"
    fi
    if [ -n "${STEP_SUMMARY_5}" ]; then
        printf "${DIM}5. Java:          ${STEP_SUMMARY_5}${NC}\n"
    fi
    if [ -n "${STEP_SUMMARY_6}" ]; then
        printf "${DIM}6. Téléchargement: ${STEP_SUMMARY_6}${NC}\n"
    fi
    if [ -n "${STEP_SUMMARY_7}" ]; then
        printf "${DIM}7. Configuration: ${STEP_SUMMARY_7}${NC}\n"
    fi
    if [ -n "${STEP_SUMMARY_8}" ]; then
        printf "${DIM}8. Systemd:       ${STEP_SUMMARY_8}${NC}\n"
    fi
    
    # Séparateur si au moins une étape terminée
    if [ -n "${STEP_SUMMARY_1}" ]; then
        echo ""
    fi
    
    # Étape actuelle
    printf "${BOLD}${BLUE}━━━ Étape ${current_step}/8: "
    case "${current_step}" in
        1) printf "Détection du système" ;;
        2) printf "Répertoire d'installation" ;;
        3) printf "Configuration utilisateur" ;;
        4) printf "Dépendances" ;;
        5) printf "Java" ;;
        6) printf "Téléchargement" ;;
        7) printf "Configuration" ;;
        8) printf "Services Systemd" ;;
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
    if [ -n "${default}" ]; then
        printf ">> %s [%s]: " "${msg}" "${default}"
    else
        printf ">> %s: " "${msg}"
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
            [Yy]*) return 0 ;;
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

step_welcome() {
    print_header
    echo "Bienvenue dans l'installation du serveur Hytale dédié !"
    echo ""
    echo "Ce script va :"
    echo "  • Vérifier et installer les dépendances"
    echo "  • Télécharger les scripts depuis GitHub"
    echo "  • Configurer les services systemd"
    echo ""
    printf "Source: ${BOLD}github.com/${GITHUB_REPO}${NC}\n"
    echo ""
    
    if ! prompt_yn "Continuer l'installation ?" "y"; then
        echo "Installation annulée."
        exit 0
    fi
}

step_1_detect() {
    print_progress 1
    
    detect_os
    
    priv_status="utilisateur"
    check_root && priv_status="root"
    
    printf "Système: ${BOLD}${OS_PRETTY}${NC}\n"
    printf "Privilèges: ${BOLD}${priv_status}${NC}\n"
    
    if ! check_root; then
        log_warn "Certaines fonctionnalités nécessitent sudo"
    fi
    
    echo ""
    STEP_SUMMARY_1="${OS_PRETTY} (${priv_status})"
    
    sleep 1
}

step_2_install_dir() {
    print_progress 2
    
    current_dir="$(pwd)"
    
    echo "1) Répertoire actuel: ${current_dir}"
    echo "2) Chemin par défaut: ${DEFAULT_INSTALL_DIR}"
    echo "3) Autre chemin"
    echo ""
    
    choice=$(prompt "Votre choix" "1")
    
    case "${choice}" in
        1) INSTALL_DIR="${current_dir}" ;;
        2) INSTALL_DIR="${DEFAULT_INSTALL_DIR}" ;;
        3) INSTALL_DIR=$(prompt "Chemin" "${DEFAULT_INSTALL_DIR}") ;;
        *) INSTALL_DIR="${current_dir}" ;;
    esac
    
    if [ ! -d "${INSTALL_DIR}" ]; then
        if prompt_yn "Créer le dossier ?" "y"; then
            mkdir -p "${INSTALL_DIR}"
        else
            log_error "Installation annulée"
            exit 1
        fi
    fi
    
    STEP_SUMMARY_2="${INSTALL_DIR}"
}

step_3_user() {
    print_progress 3
    
    current_user=$(whoami)
    
    # Utiliser automatiquement l'utilisateur courant
    HYTALE_USER="${current_user}"
    if [ "${OS_NAME}" = "macos" ]; then
        HYTALE_GROUP="staff"
    else
        HYTALE_GROUP="${current_user}"
    fi
    
    echo "Utilisateur: ${HYTALE_USER}:${HYTALE_GROUP}"
    STEP_SUMMARY_3="${HYTALE_USER}:${HYTALE_GROUP}"
    
    sleep 1
}

step_4_dependencies() {
    print_progress 4
    
    deps_missing=""
    deps_count=0
    
    for dep in curl unzip screen; do
        if command -v "${dep}" >/dev/null 2>&1; then
            printf "  ${GREEN}✓${NC} ${dep}\n"
        else
            printf "  ${RED}✗${NC} ${dep}\n"
            deps_missing="${deps_missing} ${dep}"
            deps_count=$((deps_count + 1))
        fi
    done
    
    echo ""
    
    if [ -n "${deps_missing}" ]; then
        if check_root; then
            if prompt_yn "Installer les dépendances manquantes ?" "y"; then
                for dep in ${deps_missing}; do
                    printf "  Installation ${dep}..."
                    if install_package "${dep}"; then
                        printf " ${GREEN}OK${NC}\n"
                    else
                        printf " ${RED}ÉCHEC${NC}\n"
                    fi
                done
                STEP_SUMMARY_4="Installées"
            else
                log_error "Dépendances requises"
                exit 1
            fi
        else
            log_error "Exécutez avec sudo"
            exit 1
        fi
    else
        STEP_SUMMARY_4="OK"
    fi
    
    # Optionnel: pigz (skip sur macOS car Homebrew + sudo = problème)
    if [ "${OS_NAME}" != "macos" ] && ! command -v pigz >/dev/null 2>&1 && check_root; then
        echo ""
        if prompt_yn "Installer pigz (backups rapides) ?" "y"; then
            install_package pigz
            STEP_SUMMARY_4="${STEP_SUMMARY_4} + pigz"
        fi
    fi
}

step_5_java() {
    print_progress 5
    
    java_ok=0
    java_info="Non installé"
    
    if command -v java >/dev/null 2>&1; then
        java_version=$(java --version 2>&1 | head -n1 || echo "?")
        java_major=$(echo "${java_version}" | grep -oE '[0-9]+' | head -n1 || echo "0")
        
        printf "Version: ${java_version}\n"
        
        if [ "${java_major}" -ge 25 ] 2>/dev/null; then
            log_success "Java ${java_major} compatible"
            java_ok=1
            java_info="Java ${java_major} ✓"
        else
            log_warn "Java ${java_major} < 25 requis"
            java_info="Java ${java_major} (upgrade needed)"
        fi
    else
        log_warn "Java non installé"
    fi
    
    if [ ${java_ok} -eq 0 ]; then
        echo ""
        printf "Installez Java 25: ${BOLD}https://adoptium.net/${NC}\n"
        echo ""
        if ! prompt_yn "Continuer sans Java ?" "y"; then
            exit 1
        fi
    fi
    
    STEP_SUMMARY_5="${java_info}"
}

step_6_download() {
    print_progress 6
    
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
    
    # Scripts
    download_file "hytale.sh" "hytale.sh"
    download_file "lib/utils.sh" "lib/utils.sh"
    download_file "scripts/update.sh" "scripts/update.sh"
    download_file "scripts/backup.sh" "scripts/backup.sh"
    download_file "scripts/watchdog.sh" "scripts/watchdog.sh"
    download_file "scripts/status-live.sh" "scripts/status-live.sh"
    download_file "scripts/hytale-auth.sh" "scripts/hytale-auth.sh"
    
    # Config
    download_file "config/server.conf" "config/server.conf"
    download_file "config/discord.conf" "config/discord.conf"
    
    # Services
    download_file "services/hytale.service" "services/hytale.service"
    download_file "services/hytale-backup.service" "services/hytale-backup.service"
    download_file "services/hytale-backup.timer" "services/hytale-backup.timer"
    download_file "services/hytale-watchdog.service" "services/hytale-watchdog.service"
    download_file "services/hytale-watchdog.timer" "services/hytale-watchdog.timer"
    
    # Docs
    download_file "README.md" "README.md"
    download_file "LICENSE" "LICENSE"
    
    STEP_SUMMARY_6="${downloaded} fichiers"
    if [ ${failed} -gt 0 ]; then
        STEP_SUMMARY_6="${STEP_SUMMARY_6} (${failed} échecs)"
    fi
}

step_7_configure() {
    print_progress 7
    
    printf "Configuration en cours...\n"
    
    # server.conf - remplacer __INSTALL_DIR__ par le vrai chemin
    if [ "$(uname)" = "Darwin" ]; then
        sed -i '' "s|__INSTALL_DIR__|${INSTALL_DIR}|g" "${INSTALL_DIR}/config/server.conf" 2>/dev/null || true
    else
        sed -i "s|__INSTALL_DIR__|${INSTALL_DIR}|g" "${INSTALL_DIR}/config/server.conf" 2>/dev/null || true
    fi
    
    # Services systemd
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
    
    # Dossiers
    mkdir -p "${INSTALL_DIR}/server/mods"
    mkdir -p "${INSTALL_DIR}/server/plugins"
    mkdir -p "${INSTALL_DIR}/server/universe"
    mkdir -p "${INSTALL_DIR}/backups"
    mkdir -p "${INSTALL_DIR}/logs/archive"
    mkdir -p "${INSTALL_DIR}/assets"
    
    log_success "Terminé"
    
    STEP_SUMMARY_7="OK"
}

step_8_systemd() {
    print_progress 8
    
    if [ ! -d "/etc/systemd/system" ]; then
        log_warn "Systemd non disponible"
        STEP_SUMMARY_8="Non disponible"
        return
    fi
    
    if ! check_root; then
        log_warn "Nécessite sudo"
        STEP_SUMMARY_8="Ignoré (pas root)"
        return
    fi
    
    if prompt_yn "Installer les services systemd ?" "y"; then
        cp "${INSTALL_DIR}/services/"*.service /etc/systemd/system/ 2>/dev/null
        cp "${INSTALL_DIR}/services/"*.timer /etc/systemd/system/ 2>/dev/null
        systemctl daemon-reload
        
        services_enabled=""
        
        if prompt_yn "Démarrage auto au boot ?" "y"; then
            systemctl enable hytale.service 2>/dev/null || true
            services_enabled="hytale"
        fi
        
        if prompt_yn "Backups auto (6h) ?" "y"; then
            systemctl enable hytale-backup.timer 2>/dev/null || true
            services_enabled="${services_enabled} backup"
        fi
        
        if prompt_yn "Watchdog (2min) ?" "y"; then
            systemctl enable hytale-watchdog.timer 2>/dev/null || true
            services_enabled="${services_enabled} watchdog"
        fi
        
        STEP_SUMMARY_8="${services_enabled:-Aucun}"
    else
        STEP_SUMMARY_8="Ignoré"
    fi
}

step_complete() {
    print_header
    
    # Récap final
    printf "${DIM}"
    echo "1. Système:        ${STEP_SUMMARY_1}"
    echo "2. Répertoire:     ${STEP_SUMMARY_2}"
    echo "3. Utilisateur:    ${STEP_SUMMARY_3}"
    echo "4. Dépendances:    ${STEP_SUMMARY_4}"
    echo "5. Java:           ${STEP_SUMMARY_5}"
    echo "6. Téléchargement: ${STEP_SUMMARY_6}"
    echo "7. Configuration:  ${STEP_SUMMARY_7}"
    echo "8. Systemd:        ${STEP_SUMMARY_8}"
    printf "${NC}\n"
    
    printf "${GREEN}"
    echo "═══════════════════════════════════════════════════════════"
    echo "              ✅ INSTALLATION TERMINÉE !"
    echo "═══════════════════════════════════════════════════════════"
    printf "${NC}\n"
    
    echo "Prochaines étapes :"
    echo ""
    printf "  1. ${CYAN}nano ${INSTALL_DIR}/config/server.conf${NC}\n"
    printf "  2. ${CYAN}nano ${INSTALL_DIR}/config/discord.conf${NC}  (optionnel)\n"
    printf "  3. ${CYAN}cd ${INSTALL_DIR} && ./hytale.sh start${NC}\n"
    echo ""
    echo "Le serveur sera téléchargé automatiquement si nécessaire."
    echo ""
}

# ============== MAIN ==============

main() {
    step_welcome
    step_1_detect
    step_2_install_dir
    step_3_user
    step_4_dependencies
    step_5_java
    step_6_download
    step_7_configure
    step_8_systemd
    step_complete
}

main "$@"
