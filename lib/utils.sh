#!/bin/bash
#===============================================================================
#  HYTALE SERVER - BIBLIOTHÈQUE COMMUNE
#  Fonctions partagées par tous les scripts
#===============================================================================

# ============== DETECTION DU RÉPERTOIRE ==============
# Si SCRIPT_DIR n'est pas défini, on le calcule
if [[ -z "${LIB_DIR:-}" ]]; then
    LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi
if [[ -z "${SCRIPT_DIR:-}" ]]; then
    SCRIPT_DIR="$(dirname "${LIB_DIR}")"
fi

# ============== CHARGEMENT CONFIGS ==============
CONFIG_DIR="${SCRIPT_DIR}/config"

# Charger les configurations si pas déjà fait
if [[ -z "${_CONFIGS_LOADED:-}" ]]; then
    [[ -f "${CONFIG_DIR}/server.conf" ]] && source "${CONFIG_DIR}/server.conf"
    [[ -f "${CONFIG_DIR}/discord.conf" ]] && source "${CONFIG_DIR}/discord.conf"
    _CONFIGS_LOADED=1
fi

# ============== VALEURS PAR DÉFAUT ==============
: "${SERVER_DIR:=${SCRIPT_DIR}/server}"
: "${LOGS_DIR:=${SCRIPT_DIR}/logs}"
: "${BACKUPS_DIR:=${SCRIPT_DIR}/backups}"
: "${ASSETS_DIR:=${SCRIPT_DIR}/assets}"
: "${SERVER_JAR:=HytaleServer.jar}"
: "${ASSETS_FILE:=Assets.zip}"
: "${SCREEN_NAME:=hytale}"
: "${SERVER_NAME:=Hytale Server}"
: "${MAX_PLAYERS:=20}"

# Java
: "${JAVA_PATH:=}"
: "${JAVA_MIN_VERSION:=25}"
: "${JAVA_OPTS:=-Xms4G -Xmx8G -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200}"
: "${USE_AOT_CACHE:=true}"

# Backup
: "${MAX_BACKUPS:=7}"
: "${BACKUP_PREFIX:=hytale_backup}"
: "${USE_PIGZ:=true}"

# Logs
: "${LOG_RETENTION_DAYS:=7}"

# Espace disque
: "${MIN_DISK_SPACE_GB:=5}"

# Watchdog
: "${WATCHDOG_ENABLED:=true}"

# Discord - Couleurs (format décimal)
: "${COLOR_START:=3066993}"          # Vert
: "${COLOR_START_ORANGE:=16744448}"  # Orange
: "${COLOR_STOP:=15158332}"          # Rouge
: "${COLOR_RESTART:=15844367}"       # Jaune
: "${COLOR_ALERT:=15158332}"         # Rouge
: "${COLOR_INFO:=3447003}"           # Bleu
: "${COLOR_SUCCESS:=3066993}"        # Vert
: "${COLOR_MAINTENANCE:=9807270}"    # Gris

# Discord - Personnalisation
: "${WEBHOOK_USERNAME:=}"
: "${WEBHOOK_AVATAR_URL:=}"
: "${STATUS_MESSAGE_ID:=}"
: "${ALERT_ROLE_MENTION:=}"

# Déterminer l'exécutable Java
if [[ -n "${JAVA_PATH}" ]] && [[ -x "${JAVA_PATH}" ]]; then
    JAVA_CMD="${JAVA_PATH}"
else
    JAVA_CMD="java"
fi

# ============== SYSTÈME DE TRADUCTION ==============
# LANG_CODE: fr (Français) ou en (English)
: "${LANG_CODE:=fr}"

t() {
    local key="$1"
    case "${LANG_CODE}" in
        en|EN)
            case "${key}" in
                # Général
                "server_starting") echo "Server is starting..." ;;
                "server_started") echo "Server is now online and ready for players." ;;
                "server_stopped") echo "Server has been stopped properly." ;;
                "server_restarting") echo "Server is restarting..." ;;
                "server_not_running") echo "Server is not running." ;;
                "server_already_running") echo "Server is already running." ;;
                "server_not_found") echo "Server not found, automatic download..." ;;
                "download_failed") echo "Download failed" ;;
                "script_not_found") echo "Download script not found" ;;
                "assets_not_found") echo "Assets not found" ;;
                "disk_space_low") echo "Insufficient disk space" ;;
                "disk_space_ok") echo "Disk space OK" ;;
                "available") echo "available" ;;
                "required") echo "required" ;;
                "starting_cancelled") echo "Start cancelled: insufficient disk space" ;;
                "download_info") echo "If this is the first time, OAuth2 authentication will be required." ;;
                "downloading_server") echo "DOWNLOADING SERVER" ;;
                # Backup
                "backup_started") echo "Starting backup..." ;;
                "backup_completed") echo "Backup completed" ;;
                "backup_failed") echo "Backup failed" ;;
                "backup_cleaned") echo "Old backups cleaned" ;;
                "backup_restored") echo "Backup restored" ;;
                # Watchdog
                "watchdog_check") echo "Watchdog: checking server..." ;;
                "watchdog_restart") echo "Watchdog: server crashed, restarting..." ;;
                "watchdog_ok") echo "Watchdog: server OK" ;;
                # Updates
                "update_checking") echo "Checking for updates..." ;;
                "update_available") echo "Update available" ;;
                "update_current") echo "Server is up to date." ;;
                "installed") echo "Installed" ;;
                "available_version") echo "Available" ;;
                # Players
                "no_players") echo "No players connected." ;;
                "players_online") echo "player(s) online" ;;
                "players_connected") echo "Players connected" ;;
                # Status
                "status_online") echo "ONLINE" ;;
                "status_offline") echo "OFFLINE" ;;
                "status_starting") echo "STARTING" ;;
                # Maintenance
                "maintenance") echo "Maintenance" ;;
                "log_rotation") echo "Log rotation" ;;
                # Erreurs
                "java_not_found") echo "Java not found" ;;
                "java_version_low") echo "Java version too low" ;;
                "deps_missing") echo "Missing dependencies" ;;
                # Fin
                *) echo "${key}" ;;
            esac
            ;;
        *)
            case "${key}" in
                # Général
                "server_starting") echo "Le serveur est en cours de démarrage..." ;;
                "server_started") echo "Le serveur est maintenant opérationnel et prêt à accueillir des joueurs." ;;
                "server_stopped") echo "Le serveur a été arrêté proprement." ;;
                "server_restarting") echo "Le serveur redémarre..." ;;
                "server_not_running") echo "Le serveur n'est pas en cours d'exécution." ;;
                "server_already_running") echo "Le serveur est déjà en cours d'exécution." ;;
                "server_not_found") echo "Serveur non trouvé, téléchargement automatique..." ;;
                "download_failed") echo "Échec du téléchargement" ;;
                "script_not_found") echo "Script de téléchargement introuvable" ;;
                "assets_not_found") echo "Assets introuvables" ;;
                "disk_space_low") echo "Espace disque insuffisant" ;;
                "disk_space_ok") echo "Espace disque OK" ;;
                "available") echo "disponible" ;;
                "required") echo "requis" ;;
                "starting_cancelled") echo "Démarrage annulé: espace disque insuffisant" ;;
                "download_info") echo "Si c'est la première fois, une authentification OAuth2 sera requise." ;;
                "downloading_server") echo "TÉLÉCHARGEMENT DU SERVEUR" ;;
                # Backup
                "backup_started") echo "Démarrage de la sauvegarde..." ;;
                "backup_completed") echo "Sauvegarde terminée" ;;
                "backup_failed") echo "Échec de la sauvegarde" ;;
                "backup_cleaned") echo "Anciennes sauvegardes nettoyées" ;;
                "backup_restored") echo "Sauvegarde restaurée" ;;
                # Watchdog
                "watchdog_check") echo "Watchdog: vérification du serveur..." ;;
                "watchdog_restart") echo "Watchdog: serveur crashé, redémarrage..." ;;
                "watchdog_ok") echo "Watchdog: serveur OK" ;;
                # Updates
                "update_checking") echo "Vérification des mises à jour..." ;;
                "update_available") echo "Mise à jour disponible" ;;
                "update_current") echo "Le serveur est à jour." ;;
                "installed") echo "Installé" ;;
                "available_version") echo "Disponible" ;;
                # Players
                "no_players") echo "Aucun joueur connecté." ;;
                "players_online") echo "joueur(s) en ligne" ;;
                "players_connected") echo "Joueurs connectés" ;;
                # Status
                "status_online") echo "EN LIGNE" ;;
                "status_offline") echo "HORS LIGNE" ;;
                "status_starting") echo "DÉMARRAGE" ;;
                # Maintenance
                "maintenance") echo "Maintenance" ;;
                "log_rotation") echo "Rotation des logs" ;;
                # Erreurs
                "java_not_found") echo "Java non trouvé" ;;
                "java_version_low") echo "Version Java trop basse" ;;
                "deps_missing") echo "Dépendances manquantes" ;;
                # Fin
                *) echo "${key}" ;;
            esac
            ;;
    esac
}

# ============== FONCTIONS DE LOG ==============

log() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${msg}"
    mkdir -p "${LOGS_DIR}" 2>/dev/null
    echo "[${timestamp}] [${level}] ${msg}" >> "${LOGS_DIR}/hytale.log" 2>/dev/null
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_success() { log "OK" "$@"; }

# Fonctions colorées pour le terminal
print_info() { printf "\033[0;34m[INFO]\033[0m %s\n" "$*"; }
print_success() { printf "\033[0;32m[OK]\033[0m %s\n" "$*"; }
print_warn() { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
print_error() { printf "\033[0;31m[ERROR]\033[0m %s\n" "$*"; }

# ============== FONCTIONS UTILITAIRES ==============

is_running() {
    screen -list 2>/dev/null | grep -q "\.${SCREEN_NAME}[[:space:]]" && return 0 || return 1
}

get_pid() {
    pgrep -f "${SERVER_JAR}" 2>/dev/null || echo ""
}

# Vérifie si le processus Java répond (pas zombifié)
is_process_healthy() {
    local pid
    pid=$(get_pid)
    
    if [[ -z "${pid}" ]]; then
        return 1
    fi
    
    # Vérifier que le processus existe et n'est pas zombie
    if [[ -d "/proc/${pid}" ]]; then
        local state
        state=$(cat "/proc/${pid}/stat" 2>/dev/null | awk '{print $3}')
        [[ "${state}" != "Z" ]] && return 0
    else
        # macOS/BSD: utiliser ps
        ps -p "${pid}" -o state= 2>/dev/null | grep -qv "Z" && return 0
    fi
    
    return 1
}

# ============== ESPACE DISQUE ==============

# Retourne l'espace disque disponible en GB
get_available_disk_space_gb() {
    local path="${1:-${SCRIPT_DIR}}"
    local available_kb
    
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS
        available_kb=$(df -k "${path}" | tail -1 | awk '{print $4}')
    else
        # Linux
        available_kb=$(df -k "${path}" | tail -1 | awk '{print $4}')
    fi
    
    echo $((available_kb / 1024 / 1024))
}

# Vérifie si l'espace disque est suffisant
check_disk_space() {
    local required_gb="${1:-${MIN_DISK_SPACE_GB}}"
    local path="${2:-${SCRIPT_DIR}}"
    local available_gb
    
    available_gb=$(get_available_disk_space_gb "${path}")
    
    if [[ "${available_gb}" -lt "${required_gb}" ]]; then
        log_error "Espace disque insuffisant: ${available_gb}GB disponible, ${required_gb}GB requis"
        return 1
    fi
    
    log_info "Espace disque OK: ${available_gb}GB disponible"
    return 0
}

# ============== ROTATION DES LOGS ==============

rotate_logs() {
    local retention_days="${1:-${LOG_RETENTION_DAYS}}"
    local archive_dir="${LOGS_DIR}/archive"
    
    mkdir -p "${archive_dir}"
    
    log_info "Rotation des logs (rétention: ${retention_days} jours)..."
    
    # Archiver les logs actuels s'ils sont volumineux (>10MB)
    for logfile in "${LOGS_DIR}"/*.log; do
        [[ ! -f "${logfile}" ]] && continue
        
        local size_kb
        size_kb=$(du -k "${logfile}" 2>/dev/null | cut -f1)
        
        if [[ "${size_kb}" -gt 10240 ]]; then
            local basename
            basename=$(basename "${logfile}" .log)
            local archive_name="${basename}_$(date '+%Y%m%d_%H%M%S').log"
            
            # Compresser avec pigz si disponible
            if command -v pigz &>/dev/null; then
                cp "${logfile}" "${archive_dir}/${archive_name}"
                pigz "${archive_dir}/${archive_name}"
            elif command -v gzip &>/dev/null; then
                cp "${logfile}" "${archive_dir}/${archive_name}"
                gzip "${archive_dir}/${archive_name}"
            else
                mv "${logfile}" "${archive_dir}/${archive_name}"
            fi
            
            # Vider le fichier original (sans le supprimer pour les processus qui écrivent dedans)
            : > "${logfile}"
            
            log_info "Archivé: ${basename}.log -> ${archive_name}.gz"
        fi
    done
    
    # Supprimer les archives plus vieilles que retention_days
    local deleted_count=0
    while IFS= read -r -d '' old_archive; do
        rm -f "${old_archive}"
        ((deleted_count++))
    done < <(find "${archive_dir}" -name "*.log*" -type f -mtime +"${retention_days}" -print0 2>/dev/null)
    
    if [[ "${deleted_count}" -gt 0 ]]; then
        log_info "Supprimé ${deleted_count} archive(s) de plus de ${retention_days} jours"
    fi
    
    log_success "Rotation des logs terminée"
}

# ============== WEBHOOKS DISCORD ==============

send_discord_embed() {
    local title="$1"
    local description="$2"
    local color="$3"
    local footer="${4:-${SERVER_NAME}}"
    
    # Support WEBHOOK_URL (single) ou WEBHOOKS (array)
    if [[ -z "${WEBHOOK_URL:-}" ]] && [[ -z "${WEBHOOKS:-}" ]]; then
        return 0
    fi
    
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Construire le payload JSON
    local payload='{"embeds":[{"title":"'"${title}"'","description":"'"${description}"'","color":'"${color}"',"timestamp":"'"${timestamp}"'","footer":{"text":"'"${footer}"'"}}]'
    
    # Ajouter username personnalisé si défini
    if [[ -n "${WEBHOOK_USERNAME:-}" ]]; then
        payload="${payload%\}*},\"username\":\"${WEBHOOK_USERNAME}\""
    fi
    
    # Ajouter avatar personnalisé si défini
    if [[ -n "${WEBHOOK_AVATAR_URL:-}" ]]; then
        payload="${payload%\}*},\"avatar_url\":\"${WEBHOOK_AVATAR_URL}\""
    fi
    
    payload="${payload}}"
    
    # Envoyer au webhook unique si défini
    if [[ -n "${WEBHOOK_URL:-}" ]]; then
        curl -s -H "Content-Type: application/json" -d "${payload}" "${WEBHOOK_URL}" &>/dev/null &
    fi
    
    # Envoyer aux webhooks multiples si définis
    if [[ -n "${WEBHOOKS:-}" ]]; then
        for webhook in "${WEBHOOKS[@]}"; do
            curl -s -H "Content-Type: application/json" -d "${payload}" "${webhook}" &>/dev/null &
        done
    fi
}

# Éditer un message Discord existant (pour status live)
edit_discord_message() {
    local message_id="$1"
    local title="$2"
    local description="$3"
    local color="$4"
    local footer="${5:-${SERVER_NAME}}"
    
    if [[ -z "${WEBHOOK_URL:-}" ]] || [[ -z "${message_id}" ]]; then
        return 1
    fi
    
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    local payload='{"embeds":[{"title":"'"${title}"'","description":"'"${description}"'","color":'"${color}"',"timestamp":"'"${timestamp}"'","footer":{"text":"'"${footer}"'"}}]}'
    
    # L'URL pour éditer un message webhook
    local edit_url="${WEBHOOK_URL}/messages/${message_id}"
    
    curl -s -X PATCH -H "Content-Type: application/json" -d "${payload}" "${edit_url}" &>/dev/null
}

# Créer un message et retourner son ID (pour initialiser status live)
create_discord_message() {
    local title="$1"
    local description="$2"
    local color="$3"
    
    if [[ -z "${WEBHOOK_URL:-}" ]]; then
        return 1
    fi
    
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    local payload='{"embeds":[{"title":"'"${title}"'","description":"'"${description}"'","color":'"${color}"',"timestamp":"'"${timestamp}"'","footer":{"text":"'"${SERVER_NAME}"'"}}],"wait":true}'
    
    # Ajouter username/avatar si définis
    if [[ -n "${WEBHOOK_USERNAME:-}" ]]; then
        payload="${payload%,\"wait\":true\}*},\"username\":\"${WEBHOOK_USERNAME}\",\"wait\":true}"
    fi
    
    local response
    response=$(curl -s -H "Content-Type: application/json" -d "${payload}" "${WEBHOOK_URL}?wait=true")
    
    # Extraire l'ID du message
    echo "${response}" | grep -oP '"id":\s*"\K[0-9]+' | head -1
}

# Raccourcis pour les notifications communes
discord_start() {
    send_discord_embed "🚀 Serveur en démarrage" "Le serveur Hytale est en cours de démarrage..." "${COLOR_START_ORANGE}"
}

discord_started() {
    send_discord_embed "✅ Serveur En Ligne" "Le serveur Hytale est maintenant opérationnel et prêt à accueillir des joueurs." "${COLOR_START}"
}

discord_stop() {
    send_discord_embed "🛑 Serveur Arrêté" "Le serveur Hytale a été arrêté proprement." "${COLOR_STOP}"
}

discord_restart() {
    send_discord_embed "🔄 Redémarrage" "Le serveur Hytale redémarre..." "${COLOR_RESTART}"
}

discord_maintenance() {
    local action="$1"
    send_discord_embed "🔧 Maintenance" "${action}" "${COLOR_MAINTENANCE}"
}

discord_alert() {
    local message="$1"
    local mention=""
    [[ -n "${ALERT_ROLE_MENTION:-}" ]] && mention="${ALERT_ROLE_MENTION} "
    send_discord_embed "⚠️ Alerte" "${mention}${message}" "${COLOR_ALERT}"
}

discord_update() {
    local version="$1"
    send_discord_embed "📦 Mise à jour" "Le serveur a été mis à jour vers la version ${version}." "${COLOR_INFO}"
}

discord_update_available() {
    local installed="$1"
    local available="$2"
    send_discord_embed "🔔 Mise à jour disponible" "Une nouvelle version est disponible!\\n\\n**Installée:** ${installed}\\n**Disponible:** ${available}" "${COLOR_INFO}"
}

discord_players() {
    local players_info="$1"
    local player_count="${2:-0}"
    
    local description
    if [[ "${player_count}" == "0" ]]; then
        description="Aucun joueur connecté."
    else
        description="**${player_count}** joueur(s) en ligne:\\n\\n${players_info}"
    fi
    
    send_discord_embed "👥 Joueurs connectés" "${description}" "${COLOR_INFO}"
}

discord_watchdog() {
    local event="$1"
    discord_alert "🐕 Watchdog: ${event}"
}

discord_backup() {
    local status="$1"
    local details="$2"
    send_discord_embed "💾 Backup: ${status}" "${details}" "${COLOR_INFO}"
}

# ============== MESSAGES SERVEUR IN-GAME ==============

send_server_message() {
    local message="$1"
    if is_running; then
        screen -S "${SCREEN_NAME}" -p 0 -X stuff "/say ${message}$(printf '\r')"
        log_info "Message envoyé au serveur: ${message}"
        return 0
    fi
    return 1
}

# ============== INFORMATIONS SYSTÈME ==============

get_memory_usage() {
    local pid
    pid=$(get_pid)
    
    if [[ -n "${pid}" ]]; then
        ps -p "${pid}" -o %mem= 2>/dev/null | tr -d ' ' || echo "N/A"
    else
        echo "N/A"
    fi
}

get_cpu_usage() {
    local pid
    pid=$(get_pid)
    
    if [[ -n "${pid}" ]]; then
        ps -p "${pid}" -o %cpu= 2>/dev/null | tr -d ' ' || echo "N/A"
    else
        echo "N/A"
    fi
}

get_uptime() {
    local pid
    pid=$(get_pid)
    
    if [[ -n "${pid}" ]]; then
        ps -p "${pid}" -o etime= 2>/dev/null | tr -d ' ' || echo "N/A"
    else
        echo "N/A"
    fi
}

get_players_count() {
    if ! is_running; then
        echo "N/A (serveur hors ligne)"
        return 1
    fi
    
    local log_file="${LOGS_DIR}/server.log"
    local line_before
    line_before=$(wc -l < "${log_file}" 2>/dev/null || echo "0")
    
    screen -S "${SCREEN_NAME}" -p 0 -X stuff "/who$(printf '\r')"
    sleep 1
    
    local output
    output=$(tail -n +$((line_before + 1)) "${log_file}" 2>/dev/null | grep -E 'default \([0-9]+\):' | tail -n1)
    
    if [[ -n "${output}" ]]; then
        local count
        count=$(echo "${output}" | grep -oP '\(\K[0-9]+' || echo "0")
        
        local names
        names=$(echo "${output}" | sed 's/.*): //' | tr -d ':')
        
        if [[ "${count}" -eq 0 ]]; then
            echo "0 joueur(s)"
        elif [[ "${count}" -eq 1 ]]; then
            echo "1 joueur: ${names}"
        else
            echo "${count} joueurs: ${names}"
        fi
    else
        echo "? (impossible de récupérer)"
    fi
}

# ============== VÉRIFICATION DÉPENDANCES ==============

check_command() {
    command -v "$1" &>/dev/null
}

check_java() {
    if [[ -n "${JAVA_PATH}" ]]; then
        if [[ ! -x "${JAVA_PATH}" ]]; then
            log_error "Java introuvable: ${JAVA_PATH}"
            return 1
        fi
        log_info "Utilisation de Java personnalisé: ${JAVA_PATH}"
    else
        if ! check_command java; then
            log_error "Java n'est pas installé. Java ${JAVA_MIN_VERSION}+ est requis."
            return 1
        fi
    fi
    
    local java_version
    java_version=$(${JAVA_CMD} --version 2>&1 | head -n1 | grep -oP '\d+' | head -n1)
    
    if [[ "${java_version}" -lt "${JAVA_MIN_VERSION}" ]]; then
        log_error "Java ${JAVA_MIN_VERSION}+ requis. Version détectée: ${java_version}"
        return 1
    fi
    
    log_info "Java ${java_version} détecté ✓"
    return 0
}

check_dependencies() {
    local missing=()
    
    check_command screen || missing+=("screen")
    check_command curl || missing+=("curl")
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Dépendances manquantes: ${missing[*]}"
        return 1
    fi
    
    return 0
}

# Marquer la lib comme chargée
_UTILS_LOADED=1
