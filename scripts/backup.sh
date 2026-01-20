#!/bin/bash
#===============================================================================
#  HYTALE SERVER - BACKUP SCRIPT
#  Backup manuel ou via cron/systemd timer
#  Supporte pigz pour des backups plus rapides
#===============================================================================

set -eu

# ============== CHARGEMENT BIBLIOTHÈQUE COMMUNE ==============
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "${SCRIPT_DIR}/lib/utils.sh" ]]; then
    source "${SCRIPT_DIR}/lib/utils.sh"
else
    echo "[ERROR] Bibliothèque lib/utils.sh introuvable. Exécutez ./setup-hytale.sh"
    exit 1
fi

UNIVERSE_DIR="${SERVER_DIR}/universe"

# ============== FONCTIONS ==============

create_backup() {
    if [[ ! -d "${UNIVERSE_DIR}" ]]; then
        log_error "Dossier universe introuvable: ${UNIVERSE_DIR}"
        exit 1
    fi
    
    # Vérifier l'espace disque (estimer ~2x la taille du universe pour être sûr)
    local universe_size_gb
    universe_size_gb=$(du -sg "${UNIVERSE_DIR}" 2>/dev/null | cut -f1 || echo "1")
    local required_space=$((universe_size_gb * 2 + 1))
    
    if ! check_disk_space "${required_space}"; then
        log_error "Espace disque insuffisant pour le backup"
        discord_alert "Backup échoué: espace disque insuffisant"
        exit 1
    fi
    
    mkdir -p "${BACKUPS_DIR}"
    
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_name="${BACKUP_PREFIX}_${timestamp}.tar.gz"
    local backup_path="${BACKUPS_DIR}/${backup_name}"
    
    log_info "Création du backup: ${backup_name}"
    discord_maintenance "Création du backup en cours..."
    
    cd "${SERVER_DIR}"
    
    # Utiliser pigz si disponible et activé
    local compress_result=0
    if [[ "${USE_PIGZ:-true}" == "true" ]] && command -v pigz &>/dev/null; then
        log_info "Utilisation de pigz pour compression parallèle"
        tar -cf - universe/ | pigz -p $(nproc 2>/dev/null || echo 4) > "${backup_path}" 2>/dev/null || compress_result=$?
    else
        tar -czf "${backup_path}" universe/ 2>/dev/null || compress_result=$?
    fi
    
    if [[ ${compress_result} -eq 0 ]]; then
        local size
        size=$(du -h "${backup_path}" | cut -f1)
        log_success "Backup créé avec succès: ${backup_path} (${size})"
        discord_backup "✅ Créé" "Le backup \`${backup_name}\` a été créé avec succès.\\n📦 Taille: ${size}"
    else
        log_error "Échec de la création du backup"
        discord_backup "❌ Échec" "Erreur lors de la création du backup."
        rm -f "${backup_path}"
        exit 1
    fi
}

rotate_backups() {
    log_info "Rotation des backups (max: ${MAX_BACKUPS})..."
    
    local backup_count
    backup_count=$(find "${BACKUPS_DIR}" -name "${BACKUP_PREFIX}_*.tar.gz" -type f 2>/dev/null | wc -l | tr -d ' ')
    
    if [[ "${backup_count}" -gt "${MAX_BACKUPS}" ]]; then
        local to_delete=$((backup_count - MAX_BACKUPS))
        log_info "Suppression de ${to_delete} ancien(s) backup(s)..."
        
        # Compatible macOS et Linux
        ls -t "${BACKUPS_DIR}"/${BACKUP_PREFIX}_*.tar.gz 2>/dev/null | \
            tail -n +$((MAX_BACKUPS + 1)) | \
            xargs rm -f 2>/dev/null || true
    fi
    
    log_info "Rotation terminée."
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
    local count
    count=$(find "${BACKUPS_DIR}" -name "${BACKUP_PREFIX}_*.tar.gz" -type f 2>/dev/null | wc -l | tr -d ' ')
    echo "Total: ${count} backup(s), ${total:-N/A}"
    echo "Espace disque disponible: $(get_available_disk_space_gb)GB"
}

restore_backup() {
    local backup_file="$1"
    
    if [[ ! -f "${backup_file}" ]]; then
        backup_file="${BACKUPS_DIR}/${backup_file}"
    fi
    
    if [[ ! -f "${backup_file}" ]]; then
        log_error "Backup introuvable: ${backup_file}"
        exit 1
    fi
    
    log_warn "ATTENTION: Cette opération va remplacer le dossier universe actuel!"
    read -p "Continuer? (y/N): " confirm
    
    if [[ "${confirm}" != "y" && "${confirm}" != "Y" ]]; then
        log_info "Restauration annulée."
        exit 0
    fi
    
    # Vérifier que le serveur est arrêté
    if is_running; then
        log_error "Arrêtez le serveur avant de restaurer un backup."
        exit 1
    fi
    
    # Backup du universe actuel avant restauration
    if [[ -d "${UNIVERSE_DIR}" ]]; then
        local pre_restore_backup="${BACKUPS_DIR}/pre_restore_$(date '+%Y%m%d_%H%M%S').tar.gz"
        log_info "Sauvegarde du universe actuel: ${pre_restore_backup}"
        cd "${SERVER_DIR}"
        
        if [[ "${USE_PIGZ:-true}" == "true" ]] && command -v pigz &>/dev/null; then
            tar -cf - universe/ | pigz > "${pre_restore_backup}"
        else
            tar -czf "${pre_restore_backup}" universe/
        fi
    fi
    
    # Restauration
    log_info "Restauration de: ${backup_file}"
    discord_maintenance "Restauration d'un backup en cours..."
    
    rm -rf "${UNIVERSE_DIR}"
    cd "${SERVER_DIR}"
    
    # Décompresser avec pigz si disponible
    if [[ "${USE_PIGZ:-true}" == "true" ]] && command -v pigz &>/dev/null; then
        pigz -dc "${backup_file}" | tar -xf -
    else
        tar -xzf "${backup_file}"
    fi
    
    log_success "Restauration terminée avec succès!"
    discord_backup "🔄 Restauré" "Le backup a été restauré avec succès."
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
    USE_PIGZ=${USE_PIGZ:-true}
    MIN_DISK_SPACE_GB=${MIN_DISK_SPACE_GB}
    
Le backup inclut le dossier universe/ complet.
Utilise pigz pour compression parallèle si installé.
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
            log_error "Spécifiez le fichier de backup à restaurer."
            exit 1
        fi
        restore_backup "$2"
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
