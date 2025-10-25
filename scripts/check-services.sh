#!/bin/bash
# shellcheck source=../config/global.conf.example
# Vérification de l'état des services critiques du système
# Emplacement : /opt/monitoring/scripts/check-services.sh

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

FROM=EMAIL
LOG_FILE="/opt/monitoring/logs/services-check.log"
CONFIG_FILE="/opt/monitoring/config/services.conf"

# Vérifier que le fichier de configuration existe
if [ ! -f "$CONFIG_FILE" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERREUR : Fichier de configuration $CONFIG_FILE introuvable" >> "$LOG_FILE"
    echo "ERREUR : Fichier de configuration introuvable : $CONFIG_FILE" | \
        mail -s "🚨 [ERREUR] Configuration monitoring manquante sur $HOSTNAME" \
        -a "From: $FROM" "$EMAIL"
    exit 1
fi

# Lire les services depuis le fichier de configuration
# Ignorer les lignes vides et les commentaires (#)
SERVICES=()
while IFS= read -r line; do
    # Ignorer les lignes vides et les commentaires
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    # Supprimer les espaces avant/après
    line=$(echo "$line" | xargs)
    SERVICES+=("$line")
done < "$CONFIG_FILE"

# Vérifier qu'il y a au moins un service à surveiller
if [ ${#SERVICES[@]} -eq 0 ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ATTENTION : Aucun service configuré" >> "$LOG_FILE"
    exit 0
fi

FAILED_SERVICES=""

# Vérifier chaque service
for service in "${SERVICES[@]}"; do
    if ! systemctl is-active --quiet "$service"; then
        FAILED_SERVICES="$FAILED_SERVICES $service"
    fi
done

# Si au moins un service est arrêté, envoyer une alerte
if [ ! -z "$FAILED_SERVICES" ]; then
    # Logger l'incident
    echo "$(date '+%Y-%m-%d %H:%M:%S') - SERVICES ARRÊTÉS :$FAILED_SERVICES" >> "$LOG_FILE"

    {
        echo "========================================="
        echo "ALERTE SERVICES CRITIQUES"
        echo "========================================="
        echo ""
        echo "Serveur : $HOSTNAME"
        echo "Date : $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        echo "🚨 Un ou plusieurs services critiques sont arrêtés !"
        echo ""
        echo "========================================="
        echo "SERVICES EN ÉCHEC"
        echo "========================================="
        echo ""
        for service in $FAILED_SERVICES; do
            echo "❌ $service"
            echo ""
            echo "Statut détaillé :"
            systemctl status "$service" --no-pager -l || true
            echo ""
            echo "Dernières lignes du journal :"
            journalctl -u "$service" -n 20 --no-pager || true
            echo ""
            echo "----------------------------------------"
        done
        echo ""
        echo "========================================="
        echo "ACTIONS IMMÉDIATES"
        echo "========================================="
        echo ""
        echo "1. Connectez-vous IMMÉDIATEMENT : ssh -p 4092 florianorineveu@$HOSTNAME"
        echo "2. Vérifiez les logs : sudo journalctl -xe"
        echo "3. Tentez de redémarrer le service : sudo systemctl restart [service]"
        echo "4. Consultez le log : sudo cat /opt/monitoring/logs/services-check.log"
        echo "5. Si SSH est arrêté, utilisez la console OVH en urgence"
        echo ""
        echo "========================================="
    } | mail -s "🚨 [CRITIQUE] Service(s) arrêté(s) sur $HOSTNAME" \
        -a "From: $FROM" "$EMAIL"
fi
