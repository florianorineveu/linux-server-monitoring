#!/bin/bash
# shellcheck source=../config/global.conf.example
# Script de scan chkrootkit avec notification intelligente
# Emplacement : /opt/monitoring/scripts/chkrootkit-scan.sh
# Version 3.1 - Configuration externe

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
CONFIG_FILE="/opt/monitoring/config/chkrootkit.conf"
LOG_FILE="/opt/monitoring/logs/chkrootkit-scan.log"
TEMP_FILE="/tmp/chkrootkit-scan-temp.log"

# Valeurs par défaut (si config absente)
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

# Exécuter chkrootkit
/usr/sbin/chkrootkit > "$TEMP_FILE" 2>&1

# MODE STRICT : Détecter uniquement les infections réelles
if [ "$MODE" = "strict" ]; then
    # Chercher UNIQUEMENT "INFECTED" (sans "not infected")
    INFECTED=$(grep -i "INFECTED" "$TEMP_FILE" | grep -v "not infected" || true)

    if [ ! -z "$INFECTED" ]; then
        # INFECTION DÉTECTÉE - ALERTE CRITIQUE
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ⚠️ INFECTION DÉTECTÉE !" >> "$LOG_FILE"
        echo "$INFECTED" >> "$LOG_FILE"
        echo "========================================" >> "$LOG_FILE"

        {
            echo "========================================="
            echo "🚨 ALERTE SÉCURITÉ CRITIQUE - chkrootkit"
            echo "========================================="
            echo ""
            echo "Serveur : $HOSTNAME"
            echo "Date : $(date '+%Y-%m-%d %H:%M:%S')"
            echo "Mode : STRICT (infections réelles uniquement)"
            echo ""
            echo "⚠️ INFECTION DÉTECTÉE SUR VOTRE VPS"
            echo ""
            echo "========================================="
            echo "FICHIERS INFECTÉS"
            echo "========================================="
            echo ""
            echo "$INFECTED"
            echo ""
            echo "========================================="
            echo "RAPPORT COMPLET"
            echo "========================================="
            echo ""
            cat "$TEMP_FILE"
            echo ""
            echo "========================================="
            echo "ACTIONS IMMÉDIATES"
            echo "========================================="
            echo ""
            echo "1. 🛑 ISOLER LE SERVEUR (déconnexion réseau si possible)"
            echo "2. 🔍 Connexion : ssh -p 4092 florianorineveu@$HOSTNAME"
            echo "3. 📋 Log complet : sudo cat /opt/monitoring/logs/chkrootkit-scan.log"
            echo "4. 📞 Contacter un expert en sécurité"
            echo "5. ⛔ NE PAS utiliser le serveur avant désinfection complète"
            echo ""
            echo "========================================="
        } | mail -s "🚨🚨🚨 [URGENT] INFECTION DÉTECTÉE sur $HOSTNAME" "$EMAIL"
    else
        # Aucune infection - log silencieux
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Scan terminé (mode: $MODE) - Aucune infection détectée" >> "$LOG_FILE"
    fi

# MODE PARANOID : Détecter infections + warnings après filtrage
elif [ "$MODE" = "paranoid" ]; then
    # Filtrer les faux positifs connus
    TEMP_FILTERED="/tmp/chkrootkit-filtered.log"
    cp "$TEMP_FILE" "$TEMP_FILTERED"

    # Appliquer les patterns d'exclusion
    for pattern in "${IGNORE_PATTERNS[@]}"; do
        grep -v "$pattern" "$TEMP_FILTERED" > "$TEMP_FILTERED.tmp" || true
        mv "$TEMP_FILTERED.tmp" "$TEMP_FILTERED"
    done

    # Chercher infections et warnings
    INFECTED=$(grep -i "INFECTED" "$TEMP_FILTERED" | grep -v "not infected" || true)
    WARNINGS=$(grep -i "WARNING" "$TEMP_FILTERED" || true)

    ANOMALIES="${INFECTED}${WARNINGS}"

    if [ ! -z "$ANOMALIES" ] && [ "$ANOMALIES" != " " ]; then
        # Anomalies détectées
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Anomalies détectées (mode: $MODE)" >> "$LOG_FILE"
        echo "$ANOMALIES" >> "$LOG_FILE"
        echo "========================================" >> "$LOG_FILE"

        {
            echo "========================================="
            echo "⚠️ ALERTE SÉCURITÉ - chkrootkit"
            echo "========================================="
            echo ""
            echo "Serveur : $HOSTNAME"
            echo "Date : $(date '+%Y-%m-%d %H:%M:%S')"
            echo "Mode : PARANOID (infections + warnings)"
            echo ""
            echo "⚠️ Anomalies détectées après filtrage des faux positifs"
            echo ""
            echo "========================================="
            echo "DÉTECTIONS"
            echo "========================================="
            echo ""
            echo "$ANOMALIES"
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
            echo "2. Vérifier : sudo cat /opt/monitoring/logs/chkrootkit-scan.log"
            echo "3. Analyser si faux positif ou menace réelle"
            echo "4. Ajuster /opt/monitoring/config/chkrootkit.conf si nécessaire"
            echo ""
            echo "Pour passer en mode strict (infections uniquement) :"
            echo "  sudo nano /opt/monitoring/config/chkrootkit.conf"
            echo "  MODE=strict"
            echo ""
            echo "========================================="
        } | mail -s "⚠️ [SÉCURITÉ] Anomalies chkrootkit sur $HOSTNAME" "$EMAIL"
    else
        # Aucune anomalie
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Scan terminé (mode: $MODE) - Aucune anomalie détectée" >> "$LOG_FILE"
    fi

    # Nettoyer fichier filtré
    rm -f "$TEMP_FILTERED"
fi

# Nettoyer
rm -f "$TEMP_FILE"
