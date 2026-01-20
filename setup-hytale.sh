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

# Répertoire d'installation par défaut
DEFAULT_INSTALL_DIR="/opt/hytale"
INSTALL_DIR=""
HYTALE_USER=""
HYTALE_GROUP=""

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_header() {
    clear
    printf "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                                                            ║"
    echo "║           🎮 HYTALE DEDICATED SERVER SETUP 🎮              ║"
    echo "║                                                            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    printf "${NC}\n"
}

print_step() {
    step_num="$1"
    step_name="$2"
    printf "\n${BOLD}${BLUE}━━━ Étape ${step_num}: ${step_name} ━━━${NC}\n\n"
}

log_info() { printf "${BLUE}[INFO]${NC} %s\n" "$*"; }
log_success() { printf "${GREEN}[OK]${NC} %s\n" "$*"; }
log_warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$*"; }
log_error() { printf "${RED}[ERROR]${NC} %s\n" "$*"; }

prompt() {
    msg="$1"
    default="$2"
    printf "${CYAN}➜${NC} ${msg}"
    [ -n "${default}" ] && printf " ${YELLOW}[${default}]${NC}"
    printf ": "
    read -r response
    [ -z "${response}" ] && response="${default}"
    echo "${response}"
}

prompt_yn() {
    msg="$1"
    default="$2"
    while true; do
        printf "${CYAN}➜${NC} ${msg} "
        if [ "${default}" = "y" ]; then
            printf "${YELLOW}[Y/n]${NC}: "
        else
            printf "${YELLOW}[y/N]${NC}: "
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
        OS_VERSION="${VERSION_ID:-}"
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
    echo "Source: ${BOLD}github.com/${GITHUB_REPO}${NC}"
    echo ""
    
    if ! prompt_yn "Continuer l'installation ?" "y"; then
        echo "Installation annulée."
        exit 0
    fi
}

step_detect_system() {
    print_step "1" "Détection du système"
    
    detect_os
    
    echo "Système d'exploitation: ${BOLD}${OS_PRETTY}${NC}"
    
    if check_root; then
        echo "Privilèges:             ${GREEN}root${NC}"
    else
        echo "Privilèges:             ${YELLOW}utilisateur normal${NC}"
        log_warn "Certaines fonctionnalités nécessitent sudo"
    fi
    
    echo ""
}

step_install_dir() {
    print_step "2" "Répertoire d'installation"
    
    current_dir="$(pwd)"
    
    echo "Options :"
    echo "  1) Répertoire actuel: ${current_dir}"
    echo "  2) Chemin par défaut: ${DEFAULT_INSTALL_DIR}"
    echo "  3) Autre chemin personnalisé"
    echo ""
    
    choice=$(prompt "Votre choix" "1")
    
    case "${choice}" in
        1) INSTALL_DIR="${current_dir}" ;;
        2) INSTALL_DIR="${DEFAULT_INSTALL_DIR}" ;;
        3) INSTALL_DIR=$(prompt "Chemin d'installation" "${DEFAULT_INSTALL_DIR}") ;;
        *) INSTALL_DIR="${current_dir}" ;;
    esac
    
    echo ""
    log_info "Installation dans: ${BOLD}${INSTALL_DIR}${NC}"
    
    if [ ! -d "${INSTALL_DIR}" ]; then
        if prompt_yn "Le dossier n'existe pas. Le créer ?" "y"; then
            mkdir -p "${INSTALL_DIR}"
            log_success "Dossier créé"
        else
            log_error "Installation annulée"
            exit 1
        fi
    fi
}

step_user_config() {
    print_step "3" "Configuration utilisateur"
    
    current_user=$(whoami)
    
    echo "L'utilisateur qui exécutera le serveur :"
    echo ""
    
    HYTALE_USER=$(prompt "Utilisateur" "${current_user}")
    HYTALE_GROUP=$(prompt "Groupe" "${HYTALE_USER}")
    
    echo ""
    log_info "Utilisateur: ${HYTALE_USER}:${HYTALE_GROUP}"
}

step_dependencies() {
    print_step "4" "Dépendances"
    
    echo "Vérification des dépendances requises..."
    echo ""
    
    deps_missing=""
    deps_ok=""
    
    for dep in curl unzip screen; do
        if command -v "${dep}" >/dev/null 2>&1; then
            printf "  ${GREEN}✓${NC} ${dep}\n"
            deps_ok="${deps_ok} ${dep}"
        else
            printf "  ${RED}✗${NC} ${dep} ${YELLOW}(manquant)${NC}\n"
            deps_missing="${deps_missing} ${dep}"
        fi
    done
    
    echo ""
    
    if [ -n "${deps_missing}" ]; then
        if check_root; then
            if prompt_yn "Installer les dépendances manquantes ?" "y"; then
                for dep in ${deps_missing}; do
                    printf "Installation de ${dep}..."
                    if install_package "${dep}"; then
                        printf " ${GREEN}OK${NC}\n"
                    else
                        printf " ${RED}ÉCHEC${NC}\n"
                    fi
                done
            else
                log_error "Dépendances requises non installées"
                exit 1
            fi
        else
            log_error "Exécutez avec sudo pour installer les dépendances"
            exit 1
        fi
    else
        log_success "Toutes les dépendances sont installées"
    fi
    
    # Optionnelles
    echo ""
    echo "Dépendances optionnelles :"
    
    for dep in pigz jq; do
        if command -v "${dep}" >/dev/null 2>&1; then
            printf "  ${GREEN}✓${NC} ${dep}\n"
        else
            printf "  ${YELLOW}○${NC} ${dep} ${YELLOW}(optionnel)${NC}\n"
        fi
    done
    
    if check_root; then
        echo ""
        if prompt_yn "Installer pigz (backups plus rapides) ?" "y"; then
            install_package pigz && log_success "pigz installé"
        fi
    fi
}

step_java() {
    print_step "5" "Java"
    
    echo "Vérification de Java..."
    echo ""
    
    java_ok=0
    
    if command -v java >/dev/null 2>&1; then
        java_version=$(java --version 2>&1 | head -n1)
        java_major=$(echo "${java_version}" | grep -oE '[0-9]+' | head -n1 || echo "0")
        
        echo "Version détectée: ${java_version}"
        
        if [ "${java_major}" -ge 25 ] 2>/dev/null; then
            log_success "Java ${java_major} compatible"
            java_ok=1
        else
            log_warn "Java ${java_major} détecté, mais Java 25+ est requis"
        fi
    else
        log_warn "Java non installé"
    fi
    
    if [ ${java_ok} -eq 0 ]; then
        echo ""
        echo "Installez Java 25 depuis: ${BOLD}https://adoptium.net/${NC}"
        echo ""
        case "${OS_NAME}" in
            ubuntu|debian)
                echo "Commande suggérée:"
                echo "  wget -qO- https://packages.adoptium.net/artifactory/api/gpg/key/public | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/adoptium.gpg"
                echo "  echo 'deb https://packages.adoptium.net/artifactory/deb \$(lsb_release -cs) main' | sudo tee /etc/apt/sources.list.d/adoptium.list"
                echo "  sudo apt update && sudo apt install temurin-25-jdk"
                ;;
        esac
        
        echo ""
        if ! prompt_yn "Continuer sans Java ?" "y"; then
            exit 1
        fi
    fi
}

step_download() {
    print_step "6" "Téléchargement"
    
    echo "Téléchargement des fichiers depuis GitHub..."
    echo ""
    
    download_file() {
        local_path="$1"
        remote_path="$2"
        
        mkdir -p "$(dirname "${INSTALL_DIR}/${local_path}")"
        
        if curl -fsSL "${GITHUB_RAW}/${remote_path}" -o "${INSTALL_DIR}/${local_path}" 2>/dev/null; then
            printf "  ${GREEN}✓${NC} ${local_path}\n"
        else
            printf "  ${RED}✗${NC} ${local_path}\n"
            return 1
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
    
    echo ""
    log_success "Téléchargement terminé"
}

step_configure() {
    print_step "7" "Configuration"
    
    echo "Mise à jour des chemins..."
    
    # server.conf
    if [ "$(uname)" = "Darwin" ]; then
        sed -i '' "s|^INSTALL_DIR=.*|INSTALL_DIR=\"${INSTALL_DIR}\"|" "${INSTALL_DIR}/config/server.conf" 2>/dev/null || true
    else
        sed -i "s|^INSTALL_DIR=.*|INSTALL_DIR=\"${INSTALL_DIR}\"|" "${INSTALL_DIR}/config/server.conf" 2>/dev/null || true
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
    
    log_success "Configuration terminée"
}

step_systemd() {
    print_step "8" "Services Systemd"
    
    if [ ! -d "/etc/systemd/system" ]; then
        log_warn "Systemd non disponible sur ce système"
        return
    fi
    
    if ! check_root; then
        log_warn "Exécutez avec sudo pour installer les services systemd"
        return
    fi
    
    if prompt_yn "Installer les services systemd ?" "y"; then
        cp "${INSTALL_DIR}/services/"*.service /etc/systemd/system/ 2>/dev/null
        cp "${INSTALL_DIR}/services/"*.timer /etc/systemd/system/ 2>/dev/null
        
        systemctl daemon-reload
        
        if prompt_yn "Activer le démarrage automatique au boot ?" "y"; then
            systemctl enable hytale.service 2>/dev/null || true
            log_success "Service hytale activé"
        fi
        
        if prompt_yn "Activer les backups automatiques (6h) ?" "y"; then
            systemctl enable hytale-backup.timer 2>/dev/null || true
            log_success "Timer backup activé"
        fi
        
        if prompt_yn "Activer le watchdog (2min) ?" "y"; then
            systemctl enable hytale-watchdog.timer 2>/dev/null || true
            log_success "Timer watchdog activé"
        fi
    fi
}

step_complete() {
    print_header
    
    printf "${GREEN}"
    echo "═══════════════════════════════════════════════════════════"
    echo "              ✅ INSTALLATION TERMINÉE !"
    echo "═══════════════════════════════════════════════════════════"
    printf "${NC}\n"
    
    echo "Répertoire: ${BOLD}${INSTALL_DIR}${NC}"
    echo ""
    echo "${BOLD}Prochaines étapes :${NC}"
    echo ""
    echo "  1. Configurer le serveur :"
    echo "     ${CYAN}nano ${INSTALL_DIR}/config/server.conf${NC}"
    echo ""
    echo "  2. Configurer Discord (optionnel) :"
    echo "     ${CYAN}nano ${INSTALL_DIR}/config/discord.conf${NC}"
    echo ""
    echo "  3. Télécharger le serveur Hytale :"
    echo "     ${CYAN}cd ${INSTALL_DIR} && ./scripts/update.sh download${NC}"
    echo ""
    echo "  4. Démarrer le serveur :"
    echo "     ${CYAN}./hytale.sh start${NC}"
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo ""
}

# ============== MAIN ==============

main() {
    step_welcome
    step_detect_system
    step_install_dir
    step_user_config
    step_dependencies
    step_java
    step_download
    step_configure
    step_systemd
    step_complete
}

main "$@"
