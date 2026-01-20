#!/bin/bash
#===============================================================================
#  HYTALE SERVER - AUTHENTIFICATION OAUTH2
#  Aide à l'authentification et rappels automatiques
#===============================================================================

set -eu

# ============== CHARGEMENT BIBLIOTHÈQUE COMMUNE ==============
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "${SCRIPT_DIR}/../lib/utils.sh" ]]; then
    source "${SCRIPT_DIR}/../lib/utils.sh"
else
    echo "[ERROR] Bibliothèque lib/utils.sh introuvable. Exécutez ./setup-hytale.sh"
    exit 1
fi

AUTH_STATE_FILE="${CONFIG_DIR}/.auth_state"

# ============== FONCTIONS ==============

send_discord_auth() {
    local title="$1"
    local description="$2"
    local color="$3"
    
    [[ -z "${WEBHOOK_URL:-}" ]] && return 0
    
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    local payload
    payload="{\"embeds\":[{\"title\":\"${title}\",\"description\":\"${description}\",\"color\":${color},\"timestamp\":\"${timestamp}\",\"footer\":{\"text\":\"${SERVER_NAME:-Hytale Auth System}\"},\"fields\":[{\"name\":\"🔗 Lien d'authentification\",\"value\":\"[accounts.hytale.com/device](https://accounts.hytale.com/device)\",\"inline\":false}]}]"
    
    # Ajouter username/avatar si définis
    if [[ -n "${WEBHOOK_USERNAME:-}" ]]; then
        payload="${payload%\}*},\"username\":\"${WEBHOOK_USERNAME}\"}"
    fi
    if [[ -n "${WEBHOOK_AVATAR_URL:-}" ]]; then
        payload="${payload%\}*},\"avatar_url\":\"${WEBHOOK_AVATAR_URL}\"}"
    fi
    
    payload="${payload}}"
    
    curl -s -H "Content-Type: application/json" -d "${payload}" "${WEBHOOK_URL}" &>/dev/null &
}

check_auth_status() {
    local log_file="${LOGS_DIR}/server.log"
    
    if [[ -f "${log_file}" ]]; then
        local recent_logs
        recent_logs=$(tail -n 100 "${log_file}" 2>/dev/null)

        if echo "$recent_logs" | grep -qi "Server session token not available\|Server authentication unavailable"; then
            return 1
        fi

        if echo "$recent_logs" | grep -v "Starting authenticated flow" | grep -qi "authenticated\|auth.*success\|license.*valid"; then
            return 0
        fi
    fi
    
    return 1
}

get_last_auth_date() {
    if [[ -f "${AUTH_STATE_FILE}" ]]; then
        cat "${AUTH_STATE_FILE}" 2>/dev/null || echo "Jamais"
    else
        echo "Jamais"
    fi
}

set_auth_date() {
    mkdir -p "${CONFIG_DIR}"
    date '+%Y-%m-%d %H:%M:%S' > "${AUTH_STATE_FILE}"
}

cmd_status() {
    echo "============================================"
    echo "   HYTALE AUTHENTICATION STATUS"
    echo "============================================"
    
    local last_auth
    last_auth=$(get_last_auth_date)
    echo "Dernière auth: ${last_auth}"
    
    if check_auth_status; then
        echo "État actuel:   🟢 Authentifié"
    else
        echo "État actuel:   🟡 Vérification requise"
    fi
    
    echo "============================================"
    echo ""
    echo "Pour vous authentifier:"
    echo "1. Lancez le serveur: ./hytale.sh start"
    echo "2. Accédez à la console: ./hytale.sh console"
    echo "3. Tapez: /auth login device"
    echo "4. Visitez: https://accounts.hytale.com/device"
    echo "5. Entrez le code affiché dans la console"
    echo "============================================"
}

cmd_remind() {
    log_info "Envoi d'un rappel d'authentification sur Discord..."
    
    local last_auth
    last_auth=$(get_last_auth_date)
    
    send_discord_auth \
        "🔑 Rappel d'Authentification Hytale" \
        "N'oubliez pas de vérifier que votre serveur Hytale est authentifié.\\n\\nDernière authentification: ${last_auth}" \
        "${COLOR_RESTART}"
    
    log_info "Rappel envoyé."
}

cmd_trigger() {
    if ! is_running; then
        log_error "Le serveur n'est pas en cours d'exécution."
        log_info "Démarrez le serveur avec: ./hytale.sh start"
        exit 1
    fi
    
    log_info "Envoi de la commande /auth login device..."
    screen -S "${SCREEN_NAME}" -p 0 -X stuff "/auth login device$(printf '\r')"
    
    echo ""
    echo "============================================"
    echo "  AUTHENTIFICATION INITIÉE"
    echo "============================================"
    echo ""
    echo "1. Accédez à la console: ./hytale.sh console"
    echo "2. Notez le code affiché"
    echo "3. Visitez: https://accounts.hytale.com/device"
    echo "4. Entrez le code pour valider"
    echo ""
    echo "============================================"
    
    send_discord_auth \
        "🔐 Authentification Requise" \
        "Une authentification OAuth2 a été initiée. Veuillez compléter le processus dans les 15 prochaines minutes." \
        "${COLOR_INFO}"
}

cmd_confirm() {
    log_info "Confirmation de l'authentification..."
    set_auth_date
    
    send_discord_auth \
        "✅ Authentification Réussie" \
        "Le serveur Hytale a été authentifié avec succès." \
        "${COLOR_SUCCESS}"
    
    log_info "Authentification confirmée et enregistrée."
}

cmd_setup_cron() {
    echo "============================================"
    echo "  CONFIGURATION DU RAPPEL AUTOMATIQUE"
    echo "============================================"
    echo ""
    echo "Pour configurer un rappel hebdomadaire, ajoutez cette ligne à votre crontab:"
    echo ""
    echo "# Rappel d'auth Hytale tous les lundis à 10h"
    echo "0 10 * * 1 ${SCRIPT_DIR}/hytale-auth.sh remind"
    echo ""
    echo "Pour éditer votre crontab: crontab -e"
    echo ""
    echo "============================================"
}

show_help() {
    cat <<EOF
Usage: $0 {status|trigger|remind|confirm|setup-cron|help}

Commandes:
    status      Afficher l'état de l'authentification
    trigger     Lancer le processus d'authentification OAuth2
    remind      Envoyer un rappel Discord
    confirm     Confirmer une authentification réussie
    setup-cron  Afficher les instructions pour cron
    help        Afficher cette aide

Configuration (config/server.conf):
    SCREEN_NAME=${SCREEN_NAME}

Processus OAuth2 Hytale:
1. Le serveur génère un code
2. Visitez https://accounts.hytale.com/device
3. Entrez le code pour autoriser

Note: Limite de 100 serveurs par licence.
EOF
}

# ============== MAIN ==============

case "${1:-help}" in
    status)
        cmd_status
        ;;
    trigger)
        cmd_trigger
        ;;
    remind)
        cmd_remind
        ;;
    confirm)
        cmd_confirm
        ;;
    setup-cron)
        cmd_setup_cron
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Commande inconnue: $1"
        show_help
        exit 1
        ;;
esac
