#!/bin/bash
# shellcheck source=../config/global.conf.example
# Vérification que les backups Minecraft sont récents
# Emplacement : /opt/monitoring/scripts/check-minecraft-backup.sh

# Charger la configuration globale
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")/config"

if [ -f "$CONFIG_DIR/global.conf" ]; then
    source "$CONFIG_DIR/global.conf"
else
    echo "ERROR: Configuration file not found: $CONFIG_DIR/global.conf"
    echo "Please copy global.conf.example to global.conf and configure it."
    exit 1
fi

LOG_FILE="/opt/monitoring/logs/minecraft-backup-check.log"
BACKUP_DIR="/opt/docker/minecraft-bedrock/backups"

# Seuil : alerte si aucun backup depuis plus de 25 heures
MAX_AGE_HOURS=25

# Trouver le backup le plus récent
LATEST_BACKUP=$(find "$BACKUP_DIR" -name "minecraft-backup-*.tar.gz" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)

if [ -z "$LATEST_BACKUP" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ALERTE : Aucun backup Minecraft trouvé" >> "$LOG_FILE"
    
    echo "Aucun backup Minecraft trouvé dans $BACKUP_DIR" | \
        mail -s "⚠️ [ALERTE] Aucun backup Minecraft sur $HOSTNAME" "$EMAIL"
    exit 1
fi

# Calculer l'âge du dernier backup en heures
BACKUP_AGE_SECONDS=$(( $(date +%s) - $(stat -c %Y "$LATEST_BACKUP") ))
BACKUP_AGE_HOURS=$(( BACKUP_AGE_SECONDS / 3600 ))

if [ "$BACKUP_AGE_HOURS" -gt "$MAX_AGE_HOURS" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ALERTE : Backup Minecraft trop ancien ($BACKUP_AGE_HOURS heures)" >> "$LOG_FILE"
    
    {
        echo "========================================="
        echo "⚠️ ALERTE - Backup Minecraft obsolète"
        echo "========================================="
        echo ""
        echo "Serveur : $HOSTNAME"
        echo "Date : $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        echo "Le dernier backup Minecraft date de $BACKUP_AGE_HOURS heures."
        echo "Seuil d'alerte : $MAX_AGE_HOURS heures"
        echo ""
        echo "Dernier backup : $(basename "$LATEST_BACKUP")"
        echo ""
        echo "Actions recommandées :"
        echo "1. Vérifier le cron de backup : crontab -l | grep minecraft"
        echo "2. Tester manuellement : /opt/docker/minecraft-bedrock/backup.sh"
        echo "3. Vérifier les logs : cat /var/log/syslog | grep minecraft"
        echo ""
        echo "========================================="
    } | mail -s "⚠️ [ALERTE] Backup Minecraft obsolète sur $HOSTNAME" "$EMAIL"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Backup Minecraft OK (âge : $BACKUP_AGE_HOURS heures)" >> "$LOG_FILE"
fi
