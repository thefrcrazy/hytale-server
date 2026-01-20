#!/bin/bash
#===============================================================================
#  HYTALE SERVER - STATUS LIVE DISCORD
#  Mise à jour périodique d'un message Discord avec le statut du serveur
#  Usage: ./status-live.sh [update|init|status]
#  Recommandé: cron toutes les 5 minutes
#===============================================================================

set -eu

# Charger la bibliothèque commune
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/utils.sh"

# Fichier pour stocker l'ID du message
MESSAGE_ID_FILE="${CONFIG_DIR}/.status_message_id"

# ============== FONCTIONS ==============

get_status_message_id() {
    # Priorité: config > fichier
    if [[ -n "${STATUS_MESSAGE_ID:-}" ]]; then
        echo "${STATUS_MESSAGE_ID}"
    elif [[ -f "${MESSAGE_ID_FILE}" ]]; then
        cat "${MESSAGE_ID_FILE}" 2>/dev/null
    else
        echo ""
    fi
}

save_message_id() {
    local msg_id="$1"
    echo "${msg_id}" > "${MESSAGE_ID_FILE}"
    log_info "Message ID sauvegardé: ${msg_id}"
}

build_status_description() {
    local status_icon status_text
    
    if is_running; then
        if is_process_healthy; then
            status_icon="🟢"
            status_text="En ligne"
        else
            status_icon="🟡"
            status_text="Dégradé"
        fi
    else
        status_icon="🔴"
        status_text="Hors ligne"
    fi
    
    local description="${status_icon} **État:** ${status_text}"
    
    if is_running; then
        local players cpu mem uptime_str
        players=$(get_players_count 2>/dev/null || echo "N/A")
        cpu=$(get_cpu_usage)
        mem=$(get_memory_usage)
        uptime_str=$(get_uptime)
        
        description="${description}\\n\\n"
        description="${description}👥 **Joueurs:** ${players}\\n"
        description="${description}💻 **CPU:** ${cpu}%\\n"
        description="${description}🧠 **RAM:** ${mem}%\\n"
        description="${description}⏱️ **Uptime:** ${uptime_str}"
    fi
    
    description="${description}\\n\\n📍 **Adresse:** \`${BIND_ADDRESS:-0.0.0.0:5520}\`"
    description="${description}\\n🔄 **Dernière MAJ:** $(date '+%H:%M:%S')"
    
    echo "${description}"
}

cmd_update() {
    local msg_id
    msg_id=$(get_status_message_id)
    
    if [[ -z "${msg_id}" ]]; then
        log_warn "Aucun message ID configuré. Utilisez '$0 init' pour créer le message."
        return 1
    fi
    
    if [[ -z "${WEBHOOK_URL:-}" ]]; then
        log_error "WEBHOOK_URL non configuré dans config/discord.conf"
        return 1
    fi
    
    local description color
    description=$(build_status_description)
    
    if is_running && is_process_healthy; then
        color="${COLOR_SUCCESS}"
    elif is_running; then
        color="${COLOR_RESTART}"  # Jaune pour dégradé
    else
        color="${COLOR_STOP}"
    fi
    
    if edit_discord_message "${msg_id}" "📊 Statut du Serveur" "${description}" "${color}"; then
        log_info "Message de statut mis à jour"
    else
        log_error "Échec de la mise à jour du message"
        return 1
    fi
}

cmd_init() {
    if [[ -z "${WEBHOOK_URL:-}" ]]; then
        log_error "WEBHOOK_URL non configuré dans config/discord.conf"
        return 1
    fi
    
    log_info "Création du message de statut initial..."
    
    local description
    description=$(build_status_description)
    
    local color
    if is_running; then
        color="${COLOR_SUCCESS}"
    else
        color="${COLOR_STOP}"
    fi
    
    local msg_id
    msg_id=$(create_discord_message "📊 Statut du Serveur" "${description}" "${color}")
    
    if [[ -n "${msg_id}" ]]; then
        save_message_id "${msg_id}"
        log_success "Message créé avec ID: ${msg_id}"
        echo ""
        echo "============================================"
        echo "   MESSAGE DE STATUT CRÉÉ"
        echo "============================================"
        echo ""
        echo "Message ID: ${msg_id}"
        echo ""
        echo "Pour les mises à jour automatiques, ajoutez à crontab:"
        echo "*/5 * * * * ${SCRIPT_DIR}/status-live.sh update >> ${LOGS_DIR}/status-live.log 2>&1"
        echo ""
        echo "Ou ajoutez dans config/discord.conf:"
        echo "STATUS_MESSAGE_ID=\"${msg_id}\""
        echo ""
        echo "============================================"
    else
        log_error "Échec de la création du message"
        return 1
    fi
}

cmd_status() {
    echo "============================================"
    echo "   STATUS LIVE CONFIG"
    echo "============================================"
    
    local msg_id
    msg_id=$(get_status_message_id)
    
    if [[ -n "${msg_id}" ]]; then
        echo "Message ID:    ${msg_id}"
    else
        echo "Message ID:    ⚠️  Non configuré"
    fi
    
    if [[ -n "${WEBHOOK_URL:-}" ]]; then
        echo "Webhook:       ✅ Configuré"
    else
        echo "Webhook:       ❌ Non configuré"
    fi
    
    echo "============================================"
}

show_help() {
    cat <<EOF
Usage: $0 {init|update|status|help}

Commandes:
    init        Créer un nouveau message de statut sur Discord
    update      Mettre à jour le message existant
    status      Afficher la configuration
    help        Afficher cette aide

Configuration (config/discord.conf):
    WEBHOOK_URL         - URL du webhook Discord (requis)
    STATUS_MESSAGE_ID   - ID du message à éditer (optionnel, créé par init)
    WEBHOOK_USERNAME    - Nom personnalisé du bot
    WEBHOOK_AVATAR_URL  - Avatar personnalisé

Le message affiche:
- État du serveur (En ligne/Hors ligne)
- Nombre de joueurs
- Utilisation CPU/RAM
- Uptime
- Adresse du serveur

Recommandé: Exécuter 'update' toutes les 5 minutes via cron.
EOF
}

cmd_setup_cron() {
    echo "============================================"
    echo "   CONFIGURATION CRON STATUS LIVE"
    echo "============================================"
    echo ""
    echo "Ajoutez cette ligne à votre crontab (crontab -e):"
    echo ""
    echo "# Status Live Hytale - toutes les 5 minutes"
    echo "*/5 * * * * ${SCRIPT_DIR}/status-live.sh update >> ${LOGS_DIR}/status-live.log 2>&1"
    echo ""
    echo "============================================"
}

# ============== MAIN ==============

case "${1:-help}" in
    init)
        cmd_init
        ;;
    update)
        cmd_update
        ;;
    status)
        cmd_status
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
