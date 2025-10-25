#!/bin/bash
# shellcheck source=../config/global.conf.example
# Script de scan rkhunter avec notification intelligente
# Emplacement : /opt/monitoring/scripts/rkhunter-scan.sh
# Version 2.0 - Configuration externe + filtrage

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

# Fichiers
CONFIG_FILE="/opt/monitoring/config/rkhunter.conf"
LOG_FILE="/opt/monitoring/logs/rkhunter-scan.log"
TEMP_FILE="/tmp/rkhunter-scan-temp.log"

# Valeurs par défaut
MODE="strict"
IGNORE_PATTERNS=()

# Charger la configuration
if [ -f "$CONFIG_FILE" ]; then
    while IFS= read -r line; do
        # Ignorer les lignes vides et les commentaires
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

        # Lire les paramètres
        if [[ "$line" =~ ^MODE= ]]; then
            MODE=$(echo "$line" | cut -d'=' -f2)
        elif [[ "$line" =~ ^EMAIL= ]]; then
            EMAIL=$(echo "$line" | cut -d'=' -f2)
        elif [[ "$line" =~ ^HOSTNAME= ]]; then
            HOSTNAME=$(echo "$line" | cut -d'=' -f2)
        elif [[ "$line" =~ ^IGNORE: ]]; then
            PATTERN="${line#IGNORE:}"
            IGNORE_PATTERNS+=("$PATTERN")
        fi
    done < "$CONFIG_FILE"
fi

# Mise à jour silencieuse de la base de données
/usr/bin/rkhunter --update --quiet 2>&1

# Scan du système - ne rapporte que les warnings
/usr/bin/rkhunter --check --skip-keypress --report-warnings-only > "$TEMP_FILE" 2>&1

if [ "$MODE" = "strict" ]; then
    # Mode STRICT : Filtrer les warnings connus
    TEMP_FILTERED="/tmp/rkhunter-filtered.log"
    cp "$TEMP_FILE" "$TEMP_FILTERED"
    
    # Appliquer les patterns d'exclusion
    for pattern in "${IGNORE_PATTERNS[@]}"; do
        grep -v "$pattern" "$TEMP_FILTERED" > "$TEMP_FILTERED.tmp" 2>/dev/null || true
        mv "$TEMP_FILTERED.tmp" "$TEMP_FILTERED"
    done
    
    # Vérifier s'il reste des warnings après filtrage
    if [ -s "$TEMP_FILTERED" ] && [ "$(cat "$TEMP_FILTERED" | wc -l)" -gt 0 ]; then
        # Anomalies détectées après filtrage
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Anomalies détectées (mode: $MODE)" >> "$LOG_FILE"
        cat "$TEMP_FILTERED" >> "$LOG_FILE"
        echo "========================================" >> "$LOG_FILE"
        
        {
            echo "========================================="
            echo "⚠️ ALERTE SÉCURITÉ - rkhunter"
            echo "========================================="
            echo ""
            echo "Serveur : $HOSTNAME"
            echo "Date : $(date '+%Y-%m-%d %H:%M:%S')"
            echo "Mode : STRICT (warnings bénins filtrés)"
            echo ""
            echo "rkhunter a détecté des anomalies inhabituelles."
            echo ""
            echo "========================================="
            echo "WARNINGS DÉTECTÉS (après filtrage)"
            echo "========================================="
            echo ""
            cat "$TEMP_FILTERED"
            echo ""
            echo "========================================="
            echo "RAPPORT COMPLET"
            echo "========================================="
            echo ""
            cat "$TEMP_FILE"
            echo ""
            echo "========================================="
            echo "ACTIONS RECOMMANDÉES"
            echo "========================================="
            echo ""
            echo "1. Connexion : ssh -p 4092 florianorineveu@$HOSTNAME"
            echo "2. Log complet : sudo cat /opt/monitoring/logs/rkhunter-scan.log"
            echo "3. Relancer manuellement : sudo rkhunter --check"
            echo "4. Si faux positif confirmé : sudo rkhunter --propupd"
            echo "5. Ajouter au fichier de config : sudo nano /opt/monitoring/config/rkhunter.conf"
            echo ""
            echo "========================================="
        } | mail -s "⚠️ [SÉCURITÉ] Anomalies rkhunter sur $HOSTNAME" "$EMAIL"
    else
        # Aucune anomalie après filtrage
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Scan terminé (mode: $MODE) - Aucune anomalie détectée" >> "$LOG_FILE"
    fi
    
    rm -f "$TEMP_FILTERED"

elif [ "$MODE" = "paranoid" ]; then
    # Mode PARANOID : Notifier sur tous les warnings
    if [ -s "$TEMP_FILE" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Warnings détectés (mode: $MODE)" >> "$LOG_FILE"
        cat "$TEMP_FILE" >> "$LOG_FILE"
        echo "========================================" >> "$LOG_FILE"
        
        {
            echo "========================================="
            echo "⚠️ ALERTE SÉCURITÉ - rkhunter"
            echo "========================================="
            echo ""
            echo "Serveur : $HOSTNAME"
            echo "Date : $(date '+%Y-%m-%d %H:%M:%S')"
            echo "Mode : PARANOID (tous les warnings)"
            echo ""
            echo "rkhunter a détecté des anomalies."
            echo ""
            echo "========================================="
            echo "WARNINGS DÉTECTÉS"
            echo "========================================="
            echo ""
            cat "$TEMP_FILE"
            echo ""
            echo "========================================="
            echo "ACTIONS RECOMMANDÉES"
            echo "========================================="
            echo ""
            echo "1. Connexion : ssh -p 4092 florianorineveu@$HOSTNAME"
            echo "2. Analyser si faux positifs ou menaces réelles"
            echo "3. Ajuster /opt/monitoring/config/rkhunter.conf si nécessaire"
            echo "4. Passer en mode strict : MODE=strict"
            echo ""
            echo "========================================="
        } | mail -s "⚠️ [SÉCURITÉ] Warnings rkhunter sur $HOSTNAME" "$EMAIL"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Scan terminé (mode: $MODE) - Aucun warning détecté" >> "$LOG_FILE"
    fi
fi

# Nettoyer
rm -f "$TEMP_FILE"

