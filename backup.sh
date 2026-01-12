#!/bin/bash
#===============================================================================
#  HYTALE SERVER - BACKUP SCRIPT
#  Backup manuel ou via cron/systemd timer
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
: "${BACKUPS_DIR:=${SCRIPT_DIR}/backups}"
: "${LOGS_DIR:=${SCRIPT_DIR}/logs}"
: "${MAX_BACKUPS:=7}"
: "${BACKUP_PREFIX:=hytale_backup}"

UNIVERSE_DIR="${SERVER_DIR}/universe"

# ============== FONCTIONS ==============

log() {
    local msg="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[${timestamp}] ${msg}"
}

send_discord_backup() {
    local status="$1"
    local message="$2"
    local color="$3"
    local size="${4:-}"
    
    [[ -z "${WEBHOOKS:-}" ]] && return 0
    
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    local fields=""
    if [[ -n "${size}" ]]; then
        fields=",{\"name\": \"📦 Taille\", \"value\": \"${size}\", \"inline\": true}"
    fi
    
    local payload
    payload=$(cat <<EOF
{
    "embeds": [{
        "title": "${status}",
        "description": "${message}",
        "color": ${color},
        "timestamp": "${timestamp}",
        "footer": {
            "text": "${SERVER_NAME:-Hytale Backup System}"
        },
        "fields": [
            {
                "name": "📁 Dossier",
                "value": "\`${BACKUPS_DIR}\`",
                "inline": true
            }${fields}
        ]
    }]
}
EOF
)
    
    for webhook in "${WEBHOOKS[@]}"; do
        curl -s -H "Content-Type: application/json" -d "${payload}" "${webhook}" &>/dev/null &
    done
}

create_backup() {
    if [[ ! -d "${UNIVERSE_DIR}" ]]; then
        log "ERREUR: Dossier universe introuvable: ${UNIVERSE_DIR}"
        exit 1
    fi
    
    mkdir -p "${BACKUPS_DIR}"
    
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_name="${BACKUP_PREFIX}_${timestamp}.tar.gz"
    local backup_path="${BACKUPS_DIR}/${backup_name}"
    
    log "Création du backup: ${backup_name}"
    
    # Créer le backup
    cd "${SERVER_DIR}"
    if tar -czf "${backup_path}" universe/ 2>/dev/null; then
        local size
        size=$(du -h "${backup_path}" | cut -f1)
        log "Backup créé avec succès: ${backup_path} (${size})"
        send_discord_backup "💾 Backup Créé" "Le backup \`${backup_name}\` a été créé avec succès." "${COLOR_SUCCESS:-3066993}" "${size}"
    else
        log "ERREUR: Échec de la création du backup"
        send_discord_backup "❌ Échec Backup" "Erreur lors de la création du backup." "${COLOR_ALERT:-15158332}"
        exit 1
    fi
}

rotate_backups() {
    log "Rotation des backups (max: ${MAX_BACKUPS})..."
    
    local backup_count
    backup_count=$(find "${BACKUPS_DIR}" -name "${BACKUP_PREFIX}_*.tar.gz" -type f 2>/dev/null | wc -l | tr -d ' ')
    
    if [[ "${backup_count}" -gt "${MAX_BACKUPS}" ]]; then
        local to_delete=$((backup_count - MAX_BACKUPS))
        log "Suppression de ${to_delete} ancien(s) backup(s)..."
        
        # Compatible macOS et Linux
        ls -t "${BACKUPS_DIR}"/${BACKUP_PREFIX}_*.tar.gz 2>/dev/null | \
            tail -n +"$((MAX_BACKUPS + 1))" | \
            xargs -r rm -f 2>/dev/null || true
    fi
    
    log "Rotation terminée."
}

list_backups() {
    echo "============================================"
    echo "   BACKUPS DISPONIBLES"
    echo "============================================"
    
    if [[ ! -d "${BACKUPS_DIR}" ]] || [[ -z "$(ls -A "${BACKUPS_DIR}" 2>/dev/null)" ]]; then
        echo "Aucun backup trouvé."
        return
    fi
    
    ls -lh "${BACKUPS_DIR}"/${BACKUP_PREFIX}_*.tar.gz 2>/dev/null | while read -r line; do
        echo "${line}"
    done
    
    echo "============================================"
    local total
    total=$(du -sh "${BACKUPS_DIR}" 2>/dev/null | cut -f1)
    echo "Total: ${total:-N/A}"
}

restore_backup() {
    local backup_file="$1"
    
    if [[ ! -f "${backup_file}" ]]; then
        # Essayer avec le chemin complet
        backup_file="${BACKUPS_DIR}/${backup_file}"
    fi
    
    if [[ ! -f "${backup_file}" ]]; then
        log "ERREUR: Backup introuvable: ${backup_file}"
        exit 1
    fi
    
    log "ATTENTION: Cette opération va remplacer le dossier universe actuel!"
    read -p "Continuer? (y/N): " confirm
    
    if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
        log "Restauration annulée."
        exit 0
    fi
    
    # Vérifier que le serveur est arrêté
    if pgrep -f "HytaleServer.jar" &>/dev/null; then
        log "ERREUR: Arrêtez le serveur avant de restaurer un backup."
        exit 1
    fi
    
    # Backup du universe actuel avant restauration
    if [[ -d "${UNIVERSE_DIR}" ]]; then
        local pre_restore_backup="${BACKUPS_DIR}/pre_restore_$(date '+%Y%m%d_%H%M%S').tar.gz"
        log "Sauvegarde du universe actuel: ${pre_restore_backup}"
        cd "${SERVER_DIR}"
        tar -czf "${pre_restore_backup}" universe/
    fi
    
    # Restauration
    log "Restauration de: ${backup_file}"
    rm -rf "${UNIVERSE_DIR}"
    cd "${SERVER_DIR}"
    tar -xzf "${backup_file}"
    
    log "Restauration terminée avec succès!"
    send_discord_backup "🔄 Backup Restauré" "Le backup a été restauré avec succès." "${COLOR_INFO:-3447003}"
}

show_help() {
    cat <<EOF
Usage: $0 {create|list|rotate|restore <fichier>|help}

Commandes:
    create          Créer un nouveau backup
    list            Lister les backups disponibles
    rotate          Supprimer les anciens backups (garde les ${MAX_BACKUPS} derniers)
    restore <file>  Restaurer un backup spécifique
    help            Afficher cette aide

Configuration (config/server.conf):
    MAX_BACKUPS=${MAX_BACKUPS}
    BACKUP_PREFIX=${BACKUP_PREFIX}
    
Le backup inclut le dossier universe/ complet.
EOF
}

# ============== MAIN ==============

case "${1:-help}" in
    create)
        create_backup
        rotate_backups
        ;;
    list)
        list_backups
        ;;
    rotate)
        rotate_backups
        ;;
    restore)
        if [[ -z "${2:-}" ]]; then
            log "ERREUR: Spécifiez le fichier de backup à restaurer."
            exit 1
        fi
        restore_backup "$2"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log "ERREUR: Commande inconnue: $1"
        show_help
        exit 1
        ;;
esac
