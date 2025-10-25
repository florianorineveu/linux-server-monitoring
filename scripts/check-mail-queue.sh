#!/bin/bash
# shellcheck source=../config/global.conf.example
# Surveillance de la file d'attente Postfix
# Emplacement : /opt/monitoring/scripts/check-mail-queue.sh

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

LOG_FILE="/opt/monitoring/logs/mail-queue.log"
THRESHOLD=20

# Récupère proprement la taille de la queue
QUEUE_SIZE=$(mailq 2>/dev/null | grep -c "^[A-F0-9]" || true)
QUEUE_SIZE=${QUEUE_SIZE:-0}
QUEUE_SIZE=$(echo "$QUEUE_SIZE" | head -n1 | tr -d '[:space:]')

if [ "$QUEUE_SIZE" -gt "$THRESHOLD" ]; then
    # Logger l'incident
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Queue saturée : $QUEUE_SIZE messages" >> "$LOG_FILE"

    {
        echo "========================================="
        echo "ALERTE FILE D'ATTENTE MAIL"
        echo "========================================="
        echo ""
        echo "Serveur : $HOSTNAME"
        echo "Date : $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        echo "⚠️ La file d'attente mail contient $QUEUE_SIZE messages en attente"
        echo "Seuil d'alerte : $THRESHOLD messages"
        echo ""
        echo "========================================="
        echo "CONTENU DE LA QUEUE"
        echo "========================================="
        echo ""
        mailq
        echo ""
        echo "========================================="
        echo "DERNIÈRES ERREURS MAIL"
        echo "========================================="
        echo ""
        tail -50 /var/log/mail.log | grep -i "error\|warning\|deferred\|bounced"
        echo ""
        echo "========================================="
        echo "ACTIONS RECOMMANDÉES"
        echo "========================================="
        echo ""
        echo "1. Connectez-vous : ssh -p 4092 florianorineveu@$HOSTNAME"
        echo "2. Consultez les logs : sudo tail -100 /var/log/mail.log"
        echo "3. Consultez le log monitoring : sudo cat /opt/monitoring/logs/mail-queue.log"
        echo "4. Vérifiez la configuration : sudo postconf -n"
        echo "5. Forcer l'envoi : sudo postfix flush"
        echo ""
        echo "========================================="
    } | mail -s "⚠️ [ATTENTION] File mail saturée ($QUEUE_SIZE messages) - $HOSTNAME" "$EMAIL"
fi
