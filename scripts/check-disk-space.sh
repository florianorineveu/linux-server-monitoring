#!/bin/bash
# shellcheck source=../config/global.conf.example
# Surveillance de l'espace disque avec seuils d'alerte progressifs
# Emplacement : /opt/monitoring/scripts/check-disk-space.sh

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

LOG_FILE="/opt/monitoring/logs/disk-space.log"
THRESHOLD_CRITICAL=90
THRESHOLD_WARNING=80

send_alert() {
    local LEVEL=$1
    local PARTITION=$2
    local MOUNTPOINT=$3
    local USAGE=$4
    local EMOJI=$5
    
    # Logger l'alerte
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $LEVEL : $MOUNTPOINT à $USAGE%" >> "$LOG_FILE"
    
    {
        echo "========================================="
        echo "ALERTE ESPACE DISQUE - $LEVEL"
        echo "========================================="
        echo ""
        echo "Serveur : $HOSTNAME"
        echo "Date : $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        echo "$EMOJI Le point de montage $MOUNTPOINT est plein à $USAGE%"
        echo ""
        echo "========================================="
        echo "DÉTAILS"
        echo "========================================="
        echo ""
        echo "Partition : $PARTITION"
        echo "Point de montage : $MOUNTPOINT"
        echo "Utilisation : $USAGE%"
        echo ""
        echo "État complet du disque :"
        echo ""
        df -h
        echo ""
        echo "========================================="
        echo "FICHIERS LES PLUS VOLUMINEUX (top 10)"
        echo "========================================="
        echo ""
        du -ah "$MOUNTPOINT" 2>/dev/null | sort -rh | head -10
        echo ""
        echo "========================================="
        echo "ACTIONS RECOMMANDÉES"
        echo "========================================="
        echo ""
        echo "1. Connectez-vous : ssh -p 4092 florianorineveu@$HOSTNAME"
        echo "2. Analysez l'utilisation : sudo ncdu $MOUNTPOINT"
        echo "3. Nettoyez les fichiers temporaires : sudo apt clean && sudo apt autoremove"
        echo "4. Vérifiez les logs volumineux : sudo journalctl --disk-usage"
        echo "5. Consultez le log : sudo cat /opt/monitoring/logs/disk-space.log"
        echo ""
        echo "========================================="
    } | mail -s "$EMOJI [$LEVEL] Espace disque à $USAGE% sur $MOUNTPOINT - $HOSTNAME" "$EMAIL"
}

df -h | grep -vE '^Filesystem|tmpfs|cdrom|devtmpfs|overlay' | awk '{print $5 " " $1 " " $6}' | while read -r output;
do
    usage=$(echo "$output" | awk '{print $1}' | sed 's/%//g')
    partition=$(echo "$output" | awk '{print $2}')
    mountpoint=$(echo "$output" | awk '{print $3}')

    if [ "$usage" -ge "$THRESHOLD_CRITICAL" ]; then
        send_alert "CRITIQUE" "$partition" "$mountpoint" "$usage" "🚨"
    elif [ "$usage" -ge "$THRESHOLD_WARNING" ]; then
        send_alert "ATTENTION" "$partition" "$mountpoint" "$usage" "⚠️"
    fi
done
