#!/bin/bash
#===============================================================================
#  HYTALE DEDICATED SERVER - SCRIPT PRINCIPAL
#  Auteur: TheFRcRaZy
#  Requis: Java 25 LTS, screen
#===============================================================================

set -eu

# ============== CHARGEMENT BIBLIOTHÈQUE COMMUNE ==============
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Charger la bibliothèque commune
if [[ -f "${SCRIPT_DIR}/lib/utils.sh" ]]; then
    source "${SCRIPT_DIR}/lib/utils.sh"
else
    echo "[ERROR] Bibliothèque lib/utils.sh introuvable. Exécutez ./setup-hytale.sh"
    exit 1
fi

# Chemins additionnels
ASSETS_PATH="${ASSETS_DIR}/${ASSETS_FILE}"
AOT_CACHE="${SERVER_DIR}/HytaleServer.aot"

# ============== MESSAGES RESTART ==============
: "${ENABLE_AUTO_RESTART:=false}"
: "${AUTO_RESTART_TIMES:=06:00}"
: "${RESTART_WARNINGS:=300 60 30 10 5}"
: "${AUTO_UPDATE_ON_RESTART:=false}"
: "${MSG_RESTART_WARNING:=⚠️ ATTENTION: Le serveur redémarrera dans %s!}"
: "${MSG_RESTART_NOW:=🔄 Le serveur redémarre maintenant... À tout de suite!}"
: "${MSG_UPDATE_AVAILABLE:=📦 Une mise à jour a été détectée et sera installée.}"
: "${MSG_NO_UPDATE:=✅ Serveur déjà à jour.}"

# ============== FONCTIONS RESTART ==============

format_time() {
    local seconds=$1
    if [[ $seconds -ge 60 ]]; then
        local minutes=$((seconds / 60))
        echo "${minutes} minute(s)"
    else
        echo "${seconds} seconde(s)"
    fi
}

announce_restart() {
    local warnings=(${RESTART_WARNINGS})
    local sorted_warnings=($(echo "${warnings[@]}" | tr ' ' '\n' | sort -rn))
    
    log_info "Début du compte à rebours de restart..."
    
    local sleep_time=0
    
    for warning in "${sorted_warnings[@]}"; do
        [[ $sleep_time -gt 0 ]] && sleep $sleep_time
        
        local time_str
        time_str=$(format_time $warning)
        local message
        message=$(printf "${MSG_RESTART_WARNING}" "${time_str}")
        send_server_message "${message}"
        
        local next_idx=-1
        for i in "${!sorted_warnings[@]}"; do
            if [[ "${sorted_warnings[$i]}" == "$warning" ]]; then
                next_idx=$((i + 1))
                break
            fi
        done
        
        if [[ $next_idx -lt ${#sorted_warnings[@]} ]]; then
            sleep_time=$((warning - sorted_warnings[next_idx]))
        else
            sleep_time=$warning
        fi
    done
    
    sleep $sleep_time
    send_server_message "${MSG_RESTART_NOW}"
    sleep 2
}

# ============== MISE À JOUR ==============

check_for_updates() {
    local update_script="${SCRIPT_DIR}/scripts/update.sh"
    
    if [[ ! -x "${update_script}" ]]; then
        log_error "Script de mise à jour introuvable: ${update_script}"
        return 1
    fi
    
    local output
    output=$("${update_script}" check 2>&1)
    
    echo "${output}"
    
    local installed_version available_version
    available_version=$(echo "${output}" | grep -oP 'Disponible: \K.*' || echo "")
    installed_version=$(echo "${output}" | grep -oP 'Installé: \K.*' || echo "")
    
    if echo "${output}" | grep -q "mise à jour est disponible"; then
        discord_update_available "${installed_version}" "${available_version}"
        return 1
    fi
    
    return 0
}

perform_update() {
    local update_script="${SCRIPT_DIR}/scripts/update.sh"
    
    if [[ ! -x "${update_script}" ]]; then
        log_error "Script de mise à jour introuvable: ${update_script}"
        return 1
    fi
    
    log_info "Téléchargement de la mise à jour..."
    discord_maintenance "Téléchargement de la mise à jour en cours..."
    
    if "${update_script}" download; then
        log_info "Mise à jour téléchargée avec succès."
        return 0
    else
        log_error "Échec de la mise à jour."
        return 1
    fi
}

# ============== COMMANDES SERVEUR ==============

cmd_start() {
    check_java || exit 1
    check_dependencies || exit 1
    
    if is_running; then
        log_warn "Le serveur est déjà en cours d'exécution."
        exit 1
    fi
    
    if [[ ! -f "${SERVER_DIR}/${SERVER_JAR}" ]]; then
        log_warn "Serveur non trouvé, téléchargement automatique..."
        if [[ -x "${SCRIPT_DIR}/scripts/update.sh" ]]; then
            "${SCRIPT_DIR}/scripts/update.sh" download || {
                log_error "Échec du téléchargement"
                exit 1
            }
        else
            log_error "Script de téléchargement introuvable: ${SCRIPT_DIR}/scripts/update.sh"
            exit 1
        fi
    fi
    
    if [[ ! -f "${ASSETS_PATH}" ]]; then
        log_error "Assets introuvables: ${ASSETS_PATH}"
        exit 1
    fi
    
    # Vérifier l'espace disque
    if ! check_disk_space; then
        log_error "Démarrage annulé: espace disque insuffisant"
        exit 1
    fi
    
    log_info "Démarrage du serveur Hytale..."
    discord_start
    
    # Construction de la commande
    local cmd="${JAVA_CMD} ${JAVA_OPTS}"
    
    # AOT Cache si disponible
    if [[ "${USE_AOT_CACHE}" == "true" ]] && [[ -f "${AOT_CACHE}" ]]; then
        cmd="${cmd} -XX:AOTCache=${AOT_CACHE}"
    fi
    
    cmd="${cmd} -jar ${SERVER_JAR} --assets ${ASSETS_PATH} --bind ${BIND_ADDRESS} --auth-mode ${AUTH_MODE} --name \"${SERVER_NAME}\" --max-players ${MAX_PLAYERS:-20}"
    
    # Backup intégré
    if [[ "${ENABLE_BUILTIN_BACKUP:-true}" == "true" ]]; then
        cmd="${cmd} --backup --backup-dir ${BACKUPS_DIR} --backup-frequency ${BACKUP_FREQUENCY:-30}"
    fi
    
    # Démarrage dans screen
    cd "${SERVER_DIR}"
    screen -dmS "${SCREEN_NAME}" bash -c "${cmd} 2>&1 | tee -a ${LOGS_DIR}/server.log"
    
    sleep 3
    
    if is_running; then
        log_info "Serveur démarré avec succès (screen: ${SCREEN_NAME})"
        
        # Attendre que le serveur soit vraiment prêt
        (
            sleep 30
            if is_running; then
                discord_started
            fi
        ) &
    else
        log_error "Échec du démarrage. Consultez les logs: ${LOGS_DIR}/server.log"
        exit 1
    fi
}

cmd_stop() {
    if ! is_running; then
        log_warn "Le serveur n'est pas en cours d'exécution."
        return 0
    fi
    
    log_info "Arrêt du serveur..."
    
    # Envoyer la commande stop au serveur
    screen -S "${SCREEN_NAME}" -p 0 -X stuff "stop$(printf '\r')"
    
    # Attendre l'arrêt propre
    local timeout=30
    while is_running && [[ $timeout -gt 0 ]]; do
        sleep 1
        ((timeout--))
    done
    
    if is_running; then
        log_warn "Arrêt forcé du serveur..."
        screen -S "${SCREEN_NAME}" -X quit 2>/dev/null || true
        local pid
        pid=$(get_pid)
        [[ -n "${pid}" ]] && kill -9 "${pid}" 2>/dev/null || true
    fi
    
    log_info "Serveur arrêté."
    discord_stop
}

cmd_restart() {
    log_info "Redémarrage du serveur..."
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
            echo "CPU:         $(get_cpu_usage)%"
            echo "RAM:         $(get_memory_usage)%"
            echo "Uptime:      $(get_uptime)"
        fi
        
        echo "Joueurs:     $(get_players_count)"
    else
        echo "État:        🔴 HORS LIGNE"
    fi
    
    echo "Adresse:     ${BIND_ADDRESS}"
    echo "Auth Mode:   ${AUTH_MODE}"
    echo "Disque:      $(get_available_disk_space_gb)GB disponible"
    echo "============================================"
}

cmd_console() {
    if ! is_running; then
        log_error "Le serveur n'est pas en cours d'exécution."
        exit 1
    fi
    
    echo "Connexion à la console... (Ctrl+A, D pour détacher)"
    screen -r "${SCREEN_NAME}"
}

cmd_auth() {
    log_info "Lancement de l'authentification Hytale..."
    log_info "Exécutez '/auth login device' dans la console du serveur."
    log_info "Puis visitez: https://accounts.hytale.com/device"
    
    if is_running; then
        screen -S "${SCREEN_NAME}" -p 0 -X stuff "/auth login device$(printf '\r')"
        log_info "Commande envoyée à la console."
    else
        log_warn "Le serveur doit être démarré pour l'authentification."
    fi
}

cmd_test_webhook() {
    log_info "Test des webhooks Discord..."
    send_discord_embed "🧪 Test Webhook" "Ceci est un test de notification Discord depuis le serveur Hytale." "${COLOR_INFO}"
    log_info "Messages envoyés aux webhooks configurés."
}

cmd_scheduled_restart() {
    if ! is_running; then
        log_warn "Le serveur n'est pas en cours d'exécution."
        return 0
    fi
    
    log_info "Restart planifié avec annonces aux joueurs..."
    discord_restart
    
    announce_restart
    
    cmd_stop
    sleep 5
    cmd_start
}

cmd_check_update() {
    log_info "Vérification des mises à jour..."
    check_for_updates
}

cmd_update_restart() {
    log_info "Mise à jour et redémarrage du serveur..."
    
    # Vérifier l'espace disque
    if ! check_disk_space 10; then
        log_error "Espace disque insuffisant pour la mise à jour (10GB requis)"
        exit 1
    fi
    
    check_for_updates
    
    if is_running; then
        send_server_message "${MSG_UPDATE_AVAILABLE}"
        sleep 3
        
        announce_restart
        
        cmd_stop
        sleep 5
    fi
    
    if perform_update; then
        local version
        version=$("${SCRIPT_DIR}/scripts/update.sh" check 2>&1 | grep -oP 'Disponible: \K.*' || echo "inconnue")
        discord_update "${version}"
    fi
    
    cmd_start
}

cmd_say() {
    local message="$*"
    if [[ -z "${message}" ]]; then
        log_error "Usage: $0 say <message>"
        exit 1
    fi
    send_server_message "${message}"
}

cmd_players() {
    if ! is_running; then
        log_error "Le serveur n'est pas en cours d'exécution."
        exit 1
    fi
    
    echo "============================================"
    echo "   JOUEURS CONNECTÉS"
    echo "============================================"
    
    echo "$(get_players_count)"
    
    echo "============================================"
}

cmd_players_webhook() {
    if ! is_running; then
        log_error "Le serveur n'est pas en cours d'exécution."
        exit 1
    fi
    
    local players_info
    players_info=$(get_players_count)
    
    local count
    count=$(echo "${players_info}" | grep -oP '^[0-9]+' || echo "0")
    
    local names
    names=$(echo "${players_info}" | sed 's/^[0-9]* joueur(s)*: *//' || echo "")
    
    discord_players "${names}" "${count}"
    log_info "Webhook joueurs envoyé: ${players_info}"
}

cmd_log_rotate() {
    log_info "Rotation des logs..."
    discord_maintenance "Rotation des logs en cours..."
    rotate_logs
}

cmd_help() {
    cat <<EOF
Usage: $0 {start|stop|restart|status|console|auth|test-webhook|help}

Commandes de base:
    start              Démarrer le serveur
    stop               Arrêter le serveur proprement
    restart            Redémarrer le serveur (immédiat)
    status             Afficher l'état du serveur
    players            Afficher les joueurs connectés
    console            Accéder à la console du serveur
    auth               Lancer l'authentification Hytale OAuth2

Restart planifié:
    scheduled-restart  Redémarrer avec annonces aux joueurs (5min, 1min, 30s...)
    
Mise à jour:
    check-update       Vérifier si une mise à jour est disponible
    update             Mettre à jour et redémarrer avec annonces

Maintenance:
    log-rotate         Archiver et nettoyer les vieux logs

Utilitaires:
    say <message>      Envoyer un message aux joueurs via /say
    players-webhook    Envoyer la liste des joueurs sur Discord
    test-webhook       Tester les webhooks Discord
    help               Afficher cette aide

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
    players)
        cmd_players
        ;;
    scheduled-restart)
        cmd_scheduled_restart
        ;;
    check-update)
        cmd_check_update
        ;;
    update)
        cmd_update_restart
        ;;
    say)
        shift
        cmd_say "$@"
        ;;
    test-webhook)
        cmd_test_webhook
        ;;
    players-webhook)
        cmd_players_webhook
        ;;
    log-rotate)
        cmd_log_rotate
        ;;
    help|--help|-h)
        cmd_help
        ;;
    *)
        log_error "Commande inconnue: $1"
        cmd_help
        exit 1
        ;;
esac
