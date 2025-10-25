#!/bin/bash
# shellcheck source=../config/global.conf.example
# Audit Lynis hebdomadaire avec notification si le score de sécurité baisse
# Emplacement : /opt/monitoring/scripts/lynis-audit.sh

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

LOG_FILE="/opt/monitoring/logs/lynis-audit.log"
SCORE_FILE="/opt/monitoring/config/lynis-score.txt"
TEMP_REPORT="/tmp/lynis-report.txt"

# Lancer l'audit complet
/usr/sbin/lynis audit system --quick --quiet > "$TEMP_REPORT" 2>&1

# Extraire le score actuel (hardening index)
CURRENT_SCORE=$(grep "Hardening index" "$TEMP_REPORT" | awk '{print $4}' | tr -d '[]' || echo "0")

# Lire le score précédent s'il existe
if [ -f "$SCORE_FILE" ]; then
    PREVIOUS_SCORE=$(cat "$SCORE_FILE")
else
    PREVIOUS_SCORE="0"
fi

# Sauvegarder le score actuel pour la prochaine fois
echo "$CURRENT_SCORE" > "$SCORE_FILE"

# Calculer la différence
SCORE_DIFF=$((PREVIOUS_SCORE - CURRENT_SCORE))

# Notifier si le score a baissé de plus de 5 points ou premier audit
if [ "$SCORE_DIFF" -gt 5 ] || [ "$PREVIOUS_SCORE" = "0" ]; then
    if [ "$PREVIOUS_SCORE" = "0" ]; then
        SUBJECT="📊 [INFO] Premier audit Lynis sur $HOSTNAME"
        ALERT_LEVEL="INFORMATION"
    else
        SUBJECT="⚠️ [SÉCURITÉ] Baisse du score de sécurité sur $HOSTNAME"
        ALERT_LEVEL="ATTENTION"
    fi

    {
        echo "========================================="
        echo "AUDIT SÉCURITÉ - Lynis"
        echo "========================================="
        echo ""
        echo "Serveur : $HOSTNAME"
        echo "Date : $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Niveau : $ALERT_LEVEL"
        echo ""
        if [ "$PREVIOUS_SCORE" != "0" ]; then
            echo "⚠️ Le score de sécurité a baissé significativement."
        else
            echo "Premier audit de sécurité effectué."
        fi
        echo ""
        echo "========================================="
        echo "SCORES"
        echo "========================================="
        echo ""
        if [ "$PREVIOUS_SCORE" != "0" ]; then
            echo "Score précédent : $PREVIOUS_SCORE"
            echo "Score actuel    : $CURRENT_SCORE"
            echo "Différence      : -$SCORE_DIFF points"
        else
            echo "Score initial   : $CURRENT_SCORE"
        fi
        echo ""
        echo "========================================="
        echo "PRINCIPALES SUGGESTIONS"
        echo "========================================="
        echo ""
        grep -A 50 "Suggestions" "$TEMP_REPORT" | head -30
        echo ""
        echo "========================================="
        echo "ACTIONS RECOMMANDÉES"
        echo "========================================="
        echo ""
        echo "1. Consultez le rapport complet : sudo cat /opt/monitoring/logs/lynis-audit.log"
        echo "2. Relancez un audit manuel : sudo lynis audit system"
        echo "3. Appliquez les suggestions prioritaires"
        echo "4. Suivez les bonnes pratiques : https://cisofy.com/lynis/"
        echo ""
        echo "========================================="
    } | mail -s "$SUBJECT" "$EMAIL"
fi

# Archiver le rapport complet
echo "========================================" >> "$LOG_FILE"
echo "AUDIT DU $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
echo "Score : $CURRENT_SCORE" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"
cat "$TEMP_REPORT" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Nettoyer
rm -f "$TEMP_REPORT"
