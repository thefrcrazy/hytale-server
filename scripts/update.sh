#!/bin/sh
#===============================================================================
#  HYTALE SERVER - DOWNLOAD & UPDATE SCRIPT
#  Téléchargement et mise à jour via hytale-downloader
#  Compatible: sh, bash, dash
#===============================================================================

# Déterminer le répertoire du script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/config"

# Charger la configuration principale
if [ -f "${CONFIG_DIR}/server.conf" ]; then
    . "${CONFIG_DIR}/server.conf"
fi

# Charger la configuration Discord
if [ -f "${CONFIG_DIR}/discord.conf" ]; then
    . "${CONFIG_DIR}/discord.conf"
fi

# Valeurs par défaut
SERVER_DIR="${SERVER_DIR:-${SCRIPT_DIR}/server}"
ASSETS_DIR="${ASSETS_DIR:-${SCRIPT_DIR}/assets}"
LOGS_DIR="${LOGS_DIR:-${SCRIPT_DIR}/logs}"
PATCHLINE="${PATCHLINE:-release}"
DOWNLOADER_URL="${DOWNLOADER_URL:-https://downloader.hytale.com/hytale-downloader.zip}"
MIN_DISK_SPACE_GB="${MIN_DISK_SPACE_GB:-5}"

TEMP_DIR="${SCRIPT_DIR}/.tmp"
CREDENTIALS_FILE="${SCRIPT_DIR}/.hytale-downloader-credentials.json"

# Détecter la plateforme
detect_platform() {
    os=$(uname -s | tr '[:upper:]' '[:lower:]')
    arch=$(uname -m)
    
    case "${arch}" in
        x86_64|amd64) arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        *) arch="amd64" ;;
    esac
    
    case "${os}" in
        linux)  echo "linux-${arch}" ;;
        darwin) echo "linux-${arch}" ;;
        mingw*|msys*|cygwin*) echo "windows-${arch}" ;;
        *) echo "linux-${arch}" ;;
    esac
}

PLATFORM=$(detect_platform)
DOWNLOADER_BIN="${SCRIPT_DIR}/hytale-downloader-${PLATFORM}"

# Windows: ajouter .exe
case "${PLATFORM}" in
    windows-*) DOWNLOADER_BIN="${DOWNLOADER_BIN}.exe" ;;
esac

# ============== FONCTIONS ==============

log() {
    level="$1"
    shift
    msg="$*"
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${msg}"
    mkdir -p "${LOGS_DIR}" 2>/dev/null
    echo "[${timestamp}] [${level}] ${msg}" >> "${LOGS_DIR}/update.log" 2>/dev/null
}

# Retourne l'espace disque disponible en GB
get_available_disk_space_gb() {
    path="${1:-${SCRIPT_DIR}}"
    available_kb=$(df -k "${path}" 2>/dev/null | tail -1 | awk '{print $4}')
    echo $((available_kb / 1024 / 1024))
}

# Vérifie si l'espace disque est suffisant
check_disk_space() {
    required_gb="${1:-${MIN_DISK_SPACE_GB}}"
    available_gb=$(get_available_disk_space_gb "${SCRIPT_DIR}")
    
    if [ "${available_gb}" -lt "${required_gb}" ]; then
        log "ERROR" "Espace disque insuffisant: ${available_gb}GB disponible, ${required_gb}GB requis"
        return 1
    fi
    
    log "INFO" "Espace disque OK: ${available_gb}GB disponible"
    return 0
}

send_discord_update() {
    title="$1"
    description="$2"
    color="$3"
    
    if [ -z "${WEBHOOK_URL:-}" ]; then
        return 0
    fi
    
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    server_name="${SERVER_NAME:-Hytale Updater}"
    
    # Construire le payload
    payload="{\"embeds\":[{\"title\":\"${title}\",\"description\":\"${description}\",\"color\":${color},\"timestamp\":\"${timestamp}\",\"footer\":{\"text\":\"${server_name}\"}}]"
    
    # Ajouter username/avatar si définis
    if [ -n "${WEBHOOK_USERNAME:-}" ]; then
        payload="${payload%\}*},\"username\":\"${WEBHOOK_USERNAME}\"}"
    fi
    if [ -n "${WEBHOOK_AVATAR_URL:-}" ]; then
        payload="${payload%\}*},\"avatar_url\":\"${WEBHOOK_AVATAR_URL}\"}"
    fi
    
    payload="${payload}}"
    
    curl -s -H "Content-Type: application/json" -d "${payload}" "${WEBHOOK_URL}" >/dev/null 2>&1 &
}

check_dependencies() {
    for cmd in curl unzip; do
        if ! command -v "${cmd}" >/dev/null 2>&1; then
            log "ERROR" "${cmd} n'est pas installé."
            exit 1
        fi
    done
}

download_downloader() {
    log "INFO" "Téléchargement de hytale-downloader depuis ${DOWNLOADER_URL}..."
    log "INFO" "Plateforme détectée: ${PLATFORM}"
    
    mkdir -p "${TEMP_DIR}"
    zip_file="${TEMP_DIR}/hytale-downloader.zip"
    
    if curl -fsSL "${DOWNLOADER_URL}" -o "${zip_file}"; then
        log "INFO" "Extraction..."
        unzip -o "${zip_file}" -d "${TEMP_DIR}/downloader" >/dev/null 2>&1
        
        if [ $? -ne 0 ]; then
            log "ERROR" "Échec de l'extraction."
            rm -rf "${TEMP_DIR}"
            exit 1
        fi
        
        # Chercher le binaire correspondant
        binary_name="hytale-downloader-${PLATFORM}"
        case "${PLATFORM}" in
            windows-*) binary_name="${binary_name}.exe" ;;
        esac
        
        found_bin="${TEMP_DIR}/downloader/${binary_name}"
        
        if [ -f "${found_bin}" ]; then
            cp "${found_bin}" "${DOWNLOADER_BIN}"
        else
            # Fallback: chercher un binaire Linux
            found_bin=$(find "${TEMP_DIR}/downloader" -name "hytale-downloader-linux-*" -type f 2>/dev/null | head -n1)
            if [ -n "${found_bin}" ] && [ -f "${found_bin}" ]; then
                cp "${found_bin}" "${DOWNLOADER_BIN}"
                log "WARN" "Binaire ${binary_name} non trouvé, utilisation de $(basename "${found_bin}")"
            else
                log "ERROR" "Aucun binaire hytale-downloader trouvé."
                rm -rf "${TEMP_DIR}"
                exit 1
            fi
        fi
        
        chmod +x "${DOWNLOADER_BIN}"
        rm -rf "${TEMP_DIR}"
        log "INFO" "hytale-downloader installé: ${DOWNLOADER_BIN}"
    else
        log "ERROR" "Échec du téléchargement depuis ${DOWNLOADER_URL}"
        rm -rf "${TEMP_DIR}"
        exit 1
    fi
}

ensure_downloader() {
    if [ ! -x "${DOWNLOADER_BIN}" ]; then
        log "INFO" "hytale-downloader non trouvé, téléchargement..."
        download_downloader
    fi
}

cmd_download() {
    check_dependencies
    
    # Vérifier l'espace disque (10GB recommandé pour le téléchargement)
    if ! check_disk_space 10; then
        log "ERROR" "Téléchargement annulé: espace disque insuffisant"
        exit 1
    fi
    
    ensure_downloader
    
    log "INFO" "Téléchargement du serveur Hytale (patchline: ${PATCHLINE})..."
    
    # Instructions d'authentification
    if [ ! -f "${CREDENTIALS_FILE}" ]; then
        echo ""
        echo "============================================"
        echo "  AUTHENTIFICATION OAUTH2 REQUISE"
        echo "============================================"
        echo ""
        echo "Premiere utilisation detectee."
        echo "Le downloader va afficher:"
        echo "  - Une URL a visiter"
        echo "  - Un code d'autorisation"
        echo ""
        echo "1. Ouvrez l'URL dans votre navigateur"
        echo "2. Connectez-vous avec votre compte Hytale"
        echo "3. Entrez le code affiche"
        echo "4. Le telechargement demarrera automatiquement"
        echo ""
        echo "============================================"
        echo ""
    fi
    
    send_discord_update "📥 Téléchargement en cours" "Téléchargement du serveur Hytale..." "${COLOR_MAINTENANCE:-9807270}"
    
    mkdir -p "${TEMP_DIR}"
    game_zip="${TEMP_DIR}/hytale-server.zip"
    
    # Construire la commande
    dl_args="-download-path ${game_zip}"
    if [ "${PATCHLINE}" != "release" ]; then
        dl_args="${dl_args} -patchline ${PATCHLINE}"
    fi
    
    log "INFO" "Exécution: ${DOWNLOADER_BIN} ${dl_args}"
    
    if ${DOWNLOADER_BIN} ${dl_args}; then
        log "INFO" "Téléchargement terminé. Extraction..."
        
        mkdir -p "${SERVER_DIR}" "${ASSETS_DIR}"
        unzip -o "${game_zip}" -d "${TEMP_DIR}/extracted" >/dev/null 2>&1
        
        # Copier HytaleServer.jar
        jar_found=""
        for path in "Server/HytaleServer.jar" "HytaleServer.jar" "server/HytaleServer.jar"; do
            if [ -f "${TEMP_DIR}/extracted/${path}" ]; then
                cp "${TEMP_DIR}/extracted/${path}" "${SERVER_DIR}/"
                jar_found="yes"
                log "INFO" "HytaleServer.jar installé."
                break
            fi
        done
        if [ -z "${jar_found}" ]; then
            log "WARN" "HytaleServer.jar non trouvé."
        fi
        
        # Copier Assets.zip
        if [ -f "${TEMP_DIR}/extracted/Assets.zip" ]; then
            cp "${TEMP_DIR}/extracted/Assets.zip" "${ASSETS_DIR}/"
            log "INFO" "Assets.zip installé."
        fi
        
        rm -rf "${TEMP_DIR}"
        
        version=$(${DOWNLOADER_BIN} -print-version 2>/dev/null || echo "inconnue")
        # Sauvegarder la version installée
        echo "${version}" > "${SCRIPT_DIR}/.installed_version"
        log "INFO" "Installation terminée. Version: ${version}"
        send_discord_update "✅ Serveur Téléchargé" "Version ${version} installée." "${COLOR_SUCCESS:-3066993}"
    else
        log "ERROR" "Échec du téléchargement."
        send_discord_update "❌ Échec" "Erreur lors du téléchargement." "${COLOR_ALERT:-15158332}"
        rm -rf "${TEMP_DIR}"
        exit 1
    fi
}

cmd_check_version() {
    ensure_downloader
    
    echo "=== VERSIONS ==="
    
    remote_version=$(${DOWNLOADER_BIN} -print-version 2>/dev/null || echo "N/A")
    echo "Disponible: ${remote_version}"
    
    # Lire la version installée depuis le fichier
    installed_version="Non installé"
    if [ -f "${SCRIPT_DIR}/.installed_version" ]; then
        installed_version=$(cat "${SCRIPT_DIR}/.installed_version" 2>/dev/null || echo "Inconnue")
    elif [ -f "${SERVER_DIR}/HytaleServer.jar" ]; then
        installed_version="Inconnue (fichier version manquant)"
    fi
    echo "Installé: ${installed_version}"
    
    # Afficher espace disque
    echo "Espace disque: $(get_available_disk_space_gb)GB disponible"
    
    # Vérifier si une mise à jour est disponible
    if [ "${installed_version}" != "Non installé" ] && [ "${installed_version}" != "Inconnue (fichier version manquant)" ]; then
        if [ "${installed_version}" != "${remote_version}" ] && [ "${remote_version}" != "N/A" ]; then
            echo ""
            echo "⚠️  Une mise à jour est disponible!"
            return 1
        else
            echo ""
            echo "✅ Le serveur est à jour."
            return 0
        fi
    fi
}

cmd_update_downloader() {
    log "INFO" "Mise à jour de hytale-downloader..."
    
    if [ -x "${DOWNLOADER_BIN}" ]; then
        ${DOWNLOADER_BIN} -check-update || true
    fi
    
    rm -f "${DOWNLOADER_BIN}"
    download_downloader
}

cmd_pre_release() {
    PATCHLINE="pre-release"
    cmd_download
}

cmd_auth_reset() {
    log "INFO" "Réinitialisation des credentials OAuth2..."
    
    found=0
    for cred in "${CREDENTIALS_FILE}" "${SCRIPT_DIR}/.hytale-downloader-credentials.json" "${HOME}/.hytale-downloader-credentials.json"; do
        if [ -f "${cred}" ]; then
            rm -f "${cred}"
            log "INFO" "Supprimé: ${cred}"
            found=1
        fi
    done
    
    if [ ${found} -eq 0 ]; then
        log "INFO" "Aucun fichier de credentials trouvé."
    else
        log "INFO" "Credentials supprimés."
    fi
}

cmd_downloader_version() {
    ensure_downloader
    ${DOWNLOADER_BIN} -version
}

cmd_update_scripts() {
    log "INFO" "Récupération de la dernière version des scripts depuis GitHub..."
    
    GITHUB_REPO="thefrcrazy/hytale-server"
    RELEASE_API="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"
    
    # Le script est dans /scripts/, donc la racine est un niveau au-dessus
    ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
    
    # Récupérer les informations de la dernière release
    release_info=$(curl -fsSL "${RELEASE_API}" 2>/dev/null)
    
    if [ -z "${release_info}" ]; then
        log "ERROR" "Impossible de récupérer les informations de release depuis GitHub"
        exit 1
    fi
    
    # Extraire le tag de la version
    version=$(echo "${release_info}" | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
    log "INFO" "Dernière version: ${version}"
    
    # Télécharger setup-hytale.sh depuis le raw GitHub
    setup_url="https://raw.githubusercontent.com/${GITHUB_REPO}/${version}/setup-hytale.sh"
    
    log "INFO" "Téléchargement de setup-hytale.sh..."
    
    if curl -fsSL "${setup_url}" -o "${ROOT_DIR}/setup-hytale.sh.new"; then
        # Remplacer l'ancien fichier
        mv "${ROOT_DIR}/setup-hytale.sh.new" "${ROOT_DIR}/setup-hytale.sh"
        chmod +x "${ROOT_DIR}/setup-hytale.sh"
        log "INFO" "setup-hytale.sh mis à jour vers la version ${version}"
        
        echo ""
        echo "Pour réinstaller les scripts (vos configs seront préservées):"
        echo "  cd ${ROOT_DIR} && ./setup-hytale.sh"
    else
        log "ERROR" "Échec du téléchargement de setup-hytale.sh"
        rm -f "${ROOT_DIR}/setup-hytale.sh.new"
        exit 1
    fi
}

show_help() {
    cat <<EOF
Usage: $0 {download|check|update-scripts|update-downloader|pre-release|auth-reset|help}

Commandes:
    download             Télécharger le serveur
    check                Afficher les versions
    update-scripts       Télécharger la dernière version des scripts depuis GitHub
    update-downloader    Mettre à jour hytale-downloader
    pre-release          Canal pre-release
    auth-reset           Réinitialiser l'authentification
    downloader-version   Version du downloader
    help                 Cette aide

Configuration (config/server.conf):
    MIN_DISK_SPACE_GB=${MIN_DISK_SPACE_GB} (espace minimum requis)

Authentification OAuth2:
    Première utilisation: suivez les instructions affichées.
    En cas d'erreur 401/403: $0 auth-reset
EOF
}

# ============== MAIN ==============

case "${1:-help}" in
    download)
        cmd_download
        ;;
    check)
        cmd_check_version
        ;;
    update-scripts)
        cmd_update_scripts
        ;;
    update-downloader)
        cmd_update_downloader
        ;;
    pre-release)
        cmd_pre_release
        ;;
    auth-reset)
        cmd_auth_reset
        ;;
    downloader-version)
        cmd_downloader_version
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log "ERROR" "Commande inconnue: $1"
        show_help
        exit 1
        ;;
esac
