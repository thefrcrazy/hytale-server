#!/bin/bash
#===============================================================================
#  HYTALE SERVER - WATCHDOG
#  Surveillance et redémarrage automatique en cas de crash
#  Usage: ./watchdog.sh [check|start|stop|status]
#  Recommandé: cron toutes les 2 minutes
#===============================================================================

set -eu

# Charger la bibliothèque commune
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/utils.sh"

# Fichier de lock pour éviter les exécutions multiples
LOCK_FILE="${SCRIPT_DIR}/.watchdog.lock"
STATE_FILE="${SCRIPT_DIR}/.watchdog_state"

# ============== FONCTIONS ==============

acquire_lock() {
    if [[ -f "${LOCK_FILE}" ]]; then
        local pid
        pid=$(cat "${LOCK_FILE}" 2>/dev/null)
        if [[ -n "${pid}" ]] && kill -0 "${pid}" 2>/dev/null; then
            log_warn "Watchdog déjà en cours d'exécution (PID: ${pid})"
            return 1
        fi
        rm -f "${LOCK_FILE}"
    fi
    echo $$ > "${LOCK_FILE}"
    return 0
}

release_lock() {
    rm -f "${LOCK_FILE}"
}

get_crash_count() {
    if [[ -f "${STATE_FILE}" ]]; then
        local count
        count=$(grep "crash_count=" "${STATE_FILE}" 2>/dev/null | cut -d= -f2)
        echo "${count:-0}"
    else
        echo "0"
    fi
}

increment_crash_count() {
    local count
    count=$(get_crash_count)
    count=$((count + 1))
    echo "crash_count=${count}" > "${STATE_FILE}"
    echo "last_crash=$(date '+%Y-%m-%d %H:%M:%S')" >> "${STATE_FILE}"
    echo "${count}"
}

reset_crash_count() {
    echo "crash_count=0" > "${STATE_FILE}"
}

check_and_restart() {
    if [[ "${WATCHDOG_ENABLED}" != "true" ]]; then
        log_info "Watchdog désactivé dans la configuration"
        return 0
    fi
    
    # Vérifier si le serveur devrait être actif
    if ! is_running; then
        log_info "Serveur non actif, rien à surveiller"
        return 0
    fi
    
    # Vérifier la santé du processus
    if is_process_healthy; then
        # Tout va bien, réinitialiser le compteur si on a eu des crashes
        local crash_count
        crash_count=$(get_crash_count)
        if [[ "${crash_count}" -gt 0 ]]; then
            log_info "Serveur stable depuis le dernier crash, réinitialisation du compteur"
            reset_crash_count
        fi
        return 0
    fi
    
    # Le serveur est actif (screen) mais le processus Java ne répond plus
    log_error "⚠️ Processus Java non responsive détecté!"
    
    local crash_count
    crash_count=$(increment_crash_count)
    
    # Notification Discord
    discord_watchdog "Crash détecté! Tentative de redémarrage #${crash_count}"
    
    # Éviter les boucles de redémarrage infinies
    if [[ "${crash_count}" -gt 5 ]]; then
        log_error "Trop de crashes consécutifs (${crash_count}). Arrêt du watchdog."
        discord_alert "🚨 CRITIQUE: ${crash_count} crashes consécutifs. Intervention manuelle requise!"
        return 1
    fi
    
    log_info "Tentative de redémarrage du serveur..."
    
    # Arrêt forcé
    screen -S "${SCREEN_NAME}" -X quit 2>/dev/null || true
    local pid
    pid=$(get_pid)
    [[ -n "${pid}" ]] && kill -9 "${pid}" 2>/dev/null || true
    
    sleep 5
    
    # Vérifier l'espace disque avant de redémarrer
    if ! check_disk_space; then
        log_error "Espace disque insuffisant, redémarrage annulé"
        discord_alert "🚨 Redémarrage annulé: espace disque insuffisant"
        return 1
    fi
    
    # Redémarrage
    "${SCRIPT_DIR}/hytale.sh" start
    
    if is_running; then
        log_success "Serveur redémarré avec succès par le watchdog"
        discord_watchdog "Serveur redémarré avec succès (crash #${crash_count})"
    else
        log_error "Échec du redémarrage par le watchdog"
        discord_alert "🚨 Échec du redémarrage automatique"
    fi
}

cmd_check() {
    if ! acquire_lock; then
        exit 1
    fi
    trap release_lock EXIT
    
    check_and_restart
}

cmd_status() {
    echo "============================================"
    echo "   WATCHDOG STATUS"
    echo "============================================"
    
    if [[ "${WATCHDOG_ENABLED}" == "true" ]]; then
        echo "État:          🟢 Activé"
    else
        echo "État:          🔴 Désactivé"
    fi
    
    local crash_count
    crash_count=$(get_crash_count)
    echo "Crashes:       ${crash_count}"
    
    if [[ -f "${STATE_FILE}" ]]; then
        local last_crash
        last_crash=$(grep "last_crash=" "${STATE_FILE}" 2>/dev/null | cut -d= -f2)
        [[ -n "${last_crash}" ]] && echo "Dernier crash: ${last_crash}"
    fi
    
    if is_running; then
        if is_process_healthy; then
            echo "Processus:     🟢 Sain"
        else
            echo "Processus:     🔴 Non responsive"
        fi
    else
        echo "Serveur:       ⚪ Non actif"
    fi
    
    echo "============================================"
}

cmd_reset() {
    reset_crash_count
    log_info "Compteur de crashes réinitialisé"
}

show_help() {
    cat <<EOF
Usage: $0 {check|status|reset|setup-cron|help}

Commandes:
    check       Vérifier le serveur et redémarrer si nécessaire
    status      Afficher l'état du watchdog
    reset       Réinitialiser le compteur de crashes
    setup-cron  Afficher les instructions pour cron
    help        Afficher cette aide

Configuration (config/server.conf):
    WATCHDOG_ENABLED=${WATCHDOG_ENABLED}

Le watchdog vérifie que le processus Java répond toujours.
En cas de crash, il redémarre automatiquement le serveur.
Limite: 5 crashes consécutifs avant arrêt.
EOF
}

cmd_setup_cron() {
    echo "============================================"
    echo "   CONFIGURATION CRON WATCHDOG"
    echo "============================================"
    echo ""
    echo "Ajoutez cette ligne à votre crontab (crontab -e):"
    echo ""
    echo "# Watchdog Hytale - toutes les 2 minutes"
    echo "*/2 * * * * ${SCRIPT_DIR}/watchdog.sh check >> ${LOGS_DIR}/watchdog.log 2>&1"
    echo ""
    echo "============================================"
}

# ============== MAIN ==============

case "${1:-help}" in
    check)
        cmd_check
        ;;
    status)
        cmd_status
        ;;
    reset)
        cmd_reset
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
