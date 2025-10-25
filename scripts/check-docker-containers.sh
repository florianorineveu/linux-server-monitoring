#!/bin/bash
# shellcheck source=../config/global.conf.example
# Script de vérification des conteneurs Docker critiques
# Emplacement : /opt/monitoring/scripts/check-docker-containers.sh

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

LOG_FILE="/opt/monitoring/logs/docker-containers.log"

# Liste des conteneurs critiques à surveiller
CRITICAL_CONTAINERS=(
    "minecraft-bedrock"
    "nextcloud-aio-apache"
    "nextcloud-aio-database"
    "nextcloud-aio-redis"
)

# Vérifier si Docker est actif
if ! systemctl is-active --quiet docker; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - CRITIQUE : Docker n'est pas actif !" >> "$LOG_FILE"
    echo "Docker est arrêté sur $HOSTNAME" | mail -s "🚨 [CRITIQUE] Docker arrêté sur $HOSTNAME" "$EMAIL"
    exit 1
fi

# Vérifier chaque conteneur critique
FAILED_CONTAINERS=""

for container in "${CRITICAL_CONTAINERS[@]}"; do
    # Vérifier si le conteneur existe
    if ! docker ps -a --format "{{.Names}}" | grep -q "^${container}$"; then
        continue  # Conteneur non trouvé, on ignore
    fi
    
    # Vérifier si le conteneur est en cours d'exécution
    if ! docker ps --format "{{.Names}}" | grep -q "^${container}$"; then
        FAILED_CONTAINERS="${FAILED_CONTAINERS}- ${container}\n"
    fi
done

# Si des conteneurs critiques sont arrêtés
if [ ! -z "$FAILED_CONTAINERS" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ALERTE : Conteneurs arrêtés" >> "$LOG_FILE"
    echo -e "$FAILED_CONTAINERS" >> "$LOG_FILE"
    
    {
        echo "========================================="
        echo "⚠️ ALERTE - Conteneurs Docker arrêtés"
        echo "========================================="
        echo ""
        echo "Serveur : $HOSTNAME"
        echo "Date : $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        echo "Les conteneurs critiques suivants sont arrêtés :"
        echo ""
        echo -e "$FAILED_CONTAINERS"
        echo ""
        echo "Actions immédiates :"
        echo "1. Connexion : ssh -p 4092 florianorineveu@$HOSTNAME"
        echo "2. Vérifier : docker ps -a"
        echo "3. Logs : docker logs [nom_conteneur]"
        echo "4. Redémarrer : docker start [nom_conteneur]"
        echo ""
        echo "========================================="
    } | mail -s "⚠️ [ALERTE] Conteneurs Docker arrêtés sur $HOSTNAME" "$EMAIL"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Tous les conteneurs critiques sont actifs" >> "$LOG_FILE"
fi
