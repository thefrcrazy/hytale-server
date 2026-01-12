#!/bin/bash
#===============================================================================
#  HYTALE DEDICATED SERVER - SCRIPT PRINCIPAL
#  Auteur: Script généré automatiquement
#  Requis: Java 25 LTS, screen
#===============================================================================

set -eu

# ============== CHARGEMENT CONFIGURATION ==============
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/config"

# Charger la configuration principale
source "${CONFIG_DIR}/server.conf" 2>/dev/null || true

# Charger la configuration Discord
source "${CONFIG_DIR}/discord.conf" 2>/dev/null || true

# Valeurs par défaut si non définies
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
: "${JAVA_OPTS:=-Xms4G -Xmx8G -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200}"
: "${JAVA_PATH:=}"
: "${USE_AOT_CACHE:=true}"
: "${ENABLE_BUILTIN_BACKUP:=true}"
: "${BACKUP_FREQUENCY:=30}"

# Déterminer l'exécutable Java
if [[ -n "${JAVA_PATH}" ]] && [[ -x "${JAVA_PATH}" ]]; then
    JAVA_CMD="${JAVA_PATH}"
else
    JAVA_CMD="java"
fi

ASSETS_PATH="${ASSETS_DIR}/${ASSETS_FILE}"
AOT_CACHE="${SERVER_DIR}/HytaleServer.aot"

# ============== FONCTIONS UTILITAIRES ==============

log() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${msg}"
    mkdir -p "${LOGS_DIR}"
    echo "[${timestamp}] [${level}] ${msg}" >> "${LOGS_DIR}/hytale.log"
}

check_java() {
    # Utiliser le chemin personnalisé ou java du PATH
    if [[ -n "${JAVA_PATH}" ]]; then
        if [[ ! -x "${JAVA_PATH}" ]]; then
            log "ERROR" "Java introuvable: ${JAVA_PATH}"
            exit 1
        fi
        log "INFO" "Utilisation de Java personnalisé: ${JAVA_PATH}"
    else
        if ! command -v java &> /dev/null; then
            log "ERROR" "Java n'est pas installé. Java ${JAVA_MIN_VERSION}+ est requis."
            exit 1
        fi
    fi
    
    local java_version
    java_version=$(${JAVA_CMD} --version 2>&1 | head -n1 | grep -oP '\d+' | head -n1)
    
    if [[ "${java_version}" -lt "${JAVA_MIN_VERSION}" ]]; then
        log "ERROR" "Java ${JAVA_MIN_VERSION}+ requis. Version détectée: ${java_version}"
        exit 1
    fi
    
    log "INFO" "Java ${java_version} détecté ✓"
}

check_dependencies() {
    if ! command -v screen &> /dev/null; then
        log "ERROR" "screen n'est pas installé. Installez-le avec: brew install screen (macOS) ou apt install screen (Linux)"
        exit 1
    fi
    
    if ! command -v curl &> /dev/null; then
        log "ERROR" "curl n'est pas installé."
        exit 1
    fi
}

is_running() {
    screen -list | grep -q "\.${SCREEN_NAME}[[:space:]]" && return 0 || return 1
}

get_pid() {
    pgrep -f "${SERVER_JAR}" 2>/dev/null || echo ""
}

# ============== WEBHOOKS DISCORD ==============

send_discord_embed() {
    local title="$1"
    local description="$2"
    local color="$3"
    local footer="${4:-${SERVER_NAME:-Hytale Server}}"
    
    [[ -z "${WEBHOOKS:-}" ]] && return 0
    
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    local hostname
    hostname=$(hostname)
    
    local payload
    payload=$(cat <<EOF
{
    "embeds": [{
        "title": "${title}",
        "description": "${description}",
        "color": ${color},
        "timestamp": "${timestamp}",
        "footer": {
            "text": "${footer}"
        },
        "fields": [
            {
                "name": "🖥️ Serveur",
                "value": "${hostname}",
                "inline": true
            },
            {
                "name": "📡 Adresse",
                "value": "\`${BIND_ADDRESS}\`",
                "inline": true
            }
        ]
    }]
}
EOF
)
    
    for webhook in "${WEBHOOKS[@]}"; do
        curl -s -H "Content-Type: application/json" -d "${payload}" "${webhook}" &>/dev/null &
    done
}

discord_start() {
    send_discord_embed "🚀 Serveur Démarré" "Le serveur Hytale est en cours de démarrage..." "${COLOR_START:-3066993}"
}

discord_started() {
    send_discord_embed "✅ Serveur En Ligne" "Le serveur Hytale est maintenant opérationnel et prêt à accueillir des joueurs." "${COLOR_START:-3066993}"
}

discord_stop() {
    send_discord_embed "🛑 Serveur Arrêté" "Le serveur Hytale a été arrêté proprement." "${COLOR_STOP:-15158332}"
}

discord_restart() {
    send_discord_embed "🔄 Redémarrage" "Le serveur Hytale redémarre..." "${COLOR_RESTART:-15844367}"
}

# ============== COMMANDES SERVEUR ==============

cmd_start() {
    check_java
    check_dependencies
    
    if is_running; then
        log "WARN" "Le serveur est déjà en cours d'exécution."
        exit 1
    fi
    
    if [[ ! -f "${SERVER_DIR}/${SERVER_JAR}" ]]; then
        log "ERROR" "Fichier serveur introuvable: ${SERVER_DIR}/${SERVER_JAR}"
        log "INFO" "Téléchargez le serveur avec: ./update.sh download"
        exit 1
    fi
    
    if [[ ! -f "${ASSETS_PATH}" ]]; then
        log "ERROR" "Assets introuvables: ${ASSETS_PATH}"
        exit 1
    fi
    
    log "INFO" "Démarrage du serveur Hytale..."
    discord_start
    
    # Construction de la commande
    local cmd="${JAVA_CMD} ${JAVA_OPTS}"
    
    # AOT Cache si disponible
    if [[ "${USE_AOT_CACHE}" == "true" ]] && [[ -f "${AOT_CACHE}" ]]; then
        cmd="${cmd} -XX:AOTCache=${AOT_CACHE}"
    fi
    
    cmd="${cmd} -jar ${SERVER_JAR} --assets ${ASSETS_PATH} --bind ${BIND_ADDRESS} --auth-mode ${AUTH_MODE}"
    
    # Backup intégré
    if [[ "${ENABLE_BUILTIN_BACKUP}" == "true" ]]; then
        cmd="${cmd} --backup --backup-dir ${BACKUPS_DIR} --backup-frequency ${BACKUP_FREQUENCY}"
    fi
    
    # Démarrage dans screen
    cd "${SERVER_DIR}"
    screen -dmS "${SCREEN_NAME}" bash -c "${cmd} 2>&1 | tee -a ${LOGS_DIR}/server.log"
    
    sleep 3
    
    if is_running; then
        log "INFO" "Serveur démarré avec succès (screen: ${SCREEN_NAME})"
        
        # Attendre que le serveur soit vraiment prêt (surveillance du log)
        (
            sleep 30
            if is_running; then
                discord_started
            fi
        ) &
    else
        log "ERROR" "Échec du démarrage. Consultez les logs: ${LOGS_DIR}/server.log"
        exit 1
    fi
}

cmd_stop() {
    if ! is_running; then
        log "WARN" "Le serveur n'est pas en cours d'exécution."
        return 0
    fi
    
    log "INFO" "Arrêt du serveur..."
    
    # Envoyer la commande stop au serveur
    screen -S "${SCREEN_NAME}" -p 0 -X stuff "stop$(printf '\r')"
    
    # Attendre l'arrêt propre
    local timeout=30
    while is_running && [[ $timeout -gt 0 ]]; do
        sleep 1
        ((timeout--))
    done
    
    if is_running; then
        log "WARN" "Arrêt forcé du serveur..."
        screen -S "${SCREEN_NAME}" -X quit 2>/dev/null || true
        local pid
        pid=$(get_pid)
        [[ -n "${pid}" ]] && kill -9 "${pid}" 2>/dev/null || true
    fi
    
    log "INFO" "Serveur arrêté."
    discord_stop
}

cmd_restart() {
    log "INFO" "Redémarrage du serveur..."
    discord_restart
    cmd_stop
    sleep 5
    cmd_start
}

cmd_status() {
    echo "============================================"
    echo "   HYTALE SERVER STATUS"
    echo "============================================"
    
    if is_running; then
        local pid
        pid=$(get_pid)
        echo "État:        🟢 EN LIGNE"
        echo "PID:         ${pid:-N/A}"
        echo "Screen:      ${SCREEN_NAME}"
        
        if [[ -n "${pid}" ]]; then
            local cpu mem
            cpu=$(ps -p "${pid}" -o %cpu= 2>/dev/null | tr -d ' ' || echo "N/A")
            mem=$(ps -p "${pid}" -o %mem= 2>/dev/null | tr -d ' ' || echo "N/A")
            echo "CPU:         ${cpu}%"
            echo "RAM:         ${mem}%"
        fi
    else
        echo "État:        🔴 HORS LIGNE"
    fi
    
    echo "Adresse:     ${BIND_ADDRESS}"
    echo "Auth Mode:   ${AUTH_MODE}"
    echo "============================================"
}

cmd_console() {
    if ! is_running; then
        log "ERROR" "Le serveur n'est pas en cours d'exécution."
        exit 1
    fi
    
    echo "Connexion à la console... (Ctrl+A, D pour détacher)"
    screen -r "${SCREEN_NAME}"
}

cmd_auth() {
    log "INFO" "Lancement de l'authentification Hytale..."
    log "INFO" "Exécutez '/auth login device' dans la console du serveur."
    log "INFO" "Puis visitez: https://accounts.hytale.com/device"
    
    if is_running; then
        screen -S "${SCREEN_NAME}" -p 0 -X stuff "/auth login device$(printf '\r')"
        log "INFO" "Commande envoyée à la console."
    else
        log "WARN" "Le serveur doit être démarré pour l'authentification."
    fi
}

cmd_test_webhook() {
    log "INFO" "Test des webhooks Discord..."
    send_discord_embed "🧪 Test Webhook" "Ceci est un test de notification Discord depuis le serveur Hytale." "3447003"
    log "INFO" "Messages envoyés aux webhooks configurés."
}

cmd_help() {
    cat <<EOF
Usage: $0 {start|stop|restart|status|console|auth|test-webhook|help}

Commandes:
    start        Démarrer le serveur
    stop         Arrêter le serveur proprement
    restart      Redémarrer le serveur
    status       Afficher l'état du serveur
    console      Accéder à la console du serveur
    auth         Lancer l'authentification Hytale OAuth2
    test-webhook Tester les webhooks Discord
    help         Afficher cette aide

Configuration:
    ${CONFIG_DIR}/server.conf  - Configuration principale
    ${CONFIG_DIR}/discord.conf - Webhooks Discord
    
Port UDP 5520 requis (protocole QUIC).
EOF
}

# ============== MAIN ==============

mkdir -p "${LOGS_DIR}"

case "${1:-help}" in
    start)
        cmd_start
        ;;
    stop)
        cmd_stop
        ;;
    restart)
        cmd_restart
        ;;
    status)
        cmd_status
        ;;
    console)
        cmd_console
        ;;
    auth)
        cmd_auth
        ;;
    test-webhook)
        cmd_test_webhook
        ;;
    help|--help|-h)
        cmd_help
        ;;
    *)
        log "ERROR" "Commande inconnue: $1"
        cmd_help
        exit 1
        ;;
esac
