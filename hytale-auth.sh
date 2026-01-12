#!/bin/bash
#===============================================================================
#  HYTALE SERVER - AUTHENTIFICATION OAUTH2
#  Aide à l'authentification et rappels automatiques
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
: "${LOGS_DIR:=${SCRIPT_DIR}/logs}"
: "${SCREEN_NAME:=hytale}"

AUTH_STATE_FILE="${CONFIG_DIR}/.auth_state"

# ============== FONCTIONS ==============

log() {
    local level="$1"
    shift
    local msg="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] [${level}] ${msg}"
}

send_discord_auth() {
    local title="$1"
    local description="$2"
    local color="$3"
    
    [[ -z "${WEBHOOKS:-}" ]] && return 0
    
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    local payload
    payload=$(cat <<EOF
{
    "embeds": [{
        "title": "${title}",
        "description": "${description}",
        "color": ${color},
        "timestamp": "${timestamp}",
        "footer": {
            "text": "${SERVER_NAME:-Hytale Auth System}"
        },
        "fields": [
            {
                "name": "🔗 Lien d'authentification",
                "value": "[accounts.hytale.com/device](https://accounts.hytale.com/device)",
                "inline": false
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

check_auth_status() {
    # Vérifier si le serveur est authentifié en regardant les logs
    local log_file="${LOGS_DIR}/server.log"
    
    if [[ -f "${log_file}" ]]; then
        # Chercher des indicateurs d'authentification réussie dans les logs récents
        if tail -100 "${log_file}" 2>/dev/null | grep -qi "authenticated\|auth.*success\|license.*valid"; then
            return 0  # Authentifié
        fi
    fi
    
    return 1  # Non authentifié ou inconnu
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
    log "INFO" "Envoi d'un rappel d'authentification sur Discord..."
    
    local last_auth
    last_auth=$(get_last_auth_date)
    
    send_discord_auth \
        "🔑 Rappel d'Authentification Hytale" \
        "N'oubliez pas de vérifier que votre serveur Hytale est authentifié.\n\nDernière authentification: ${last_auth}" \
        "${COLOR_RESTART:-15844367}"
    
    log "INFO" "Rappel envoyé."
}

cmd_trigger() {
    # Déclencher l'authentification via la console du serveur
    if ! screen -list | grep -q "\.${SCREEN_NAME}[[:space:]]"; then
        log "ERROR" "Le serveur n'est pas en cours d'exécution."
        log "INFO" "Démarrez le serveur avec: ./hytale.sh start"
        exit 1
    fi
    
    log "INFO" "Envoi de la commande /auth login device..."
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
    
    # Notification Discord
    send_discord_auth \
        "🔐 Authentification Requise" \
        "Une authentification OAuth2 a été initiée. Veuillez compléter le processus dans les 15 prochaines minutes." \
        "${COLOR_INFO:-3447003}"
}

cmd_confirm() {
    log "INFO" "Confirmation de l'authentification..."
    set_auth_date
    
    send_discord_auth \
        "✅ Authentification Réussie" \
        "Le serveur Hytale a été authentifié avec succès." \
        "${COLOR_SUCCESS:-3066993}"
    
    log "INFO" "Authentification confirmée et enregistrée."
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
        log "ERROR" "Commande inconnue: $1"
        show_help
        exit 1
        ;;
esac
