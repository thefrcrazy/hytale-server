# 🎮 Hytale Dedicated Server

Script d'installation et de gestion pour serveur Hytale dédié sous Linux.

## ✨ Fonctionnalités

- 📦 **Installation interactive** - Assistant CLI étape par étape
- 🔄 **Téléchargement officiel** - Via hytale-downloader
- 💾 **Backups rapides** - Compression parallèle avec pigz
- 🔔 **Notifications Discord** - Webhooks enrichis
- 🐕 **Watchdog** - Redémarrage automatique si crash
- 📊 **Status Live** - Message Discord mis à jour en temps réel
- ⏰ **Restart planifié** - Avec annonces in-game
- 📥 **Mise à jour automatique** - Vérification et installation
- 🗂️ **Rotation des logs** - Archivage automatique

---

## 📋 Prérequis

| Élément | Requis |
|---------|--------|
| **OS** | Linux (Ubuntu/Debian recommandé) |
| **Java** | Java 25 LTS ([Adoptium Temurin](https://adoptium.net/)) |
| **RAM** | 4 GB minimum, 8 GB recommandé |
| **Port** | UDP 5520 (protocole QUIC) |

### Installer Java 25

```bash
# Ubuntu/Debian
wget -qO- https://packages.adoptium.net/artifactory/api/gpg/key/public | \
    sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/adoptium.gpg
echo "deb https://packages.adoptium.net/artifactory/deb $(lsb_release -cs) main" | \
    sudo tee /etc/apt/sources.list.d/adoptium.list
sudo apt update && sudo apt install -y temurin-25-jdk
```

---

## 🚀 Installation

### Installation rapide

```bash
# Télécharger le script d'installation
curl -fsSL https://raw.githubusercontent.com/thefrcrazy/hytale-server/main/setup-hytale.sh -o setup-hytale.sh
chmod +x setup-hytale.sh

# Lancer l'installation interactive
sudo ./setup-hytale.sh
```

L'assistant vous guidera à travers :
1. Détection du système
2. Choix du répertoire d'installation
3. Configuration utilisateur
4. Installation des dépendances
5. Vérification Java
6. Téléchargement depuis GitHub
7. Configuration automatique
8. Services systemd (optionnel)

### Après l'installation

```bash
# Configurer
nano config/server.conf
nano config/discord.conf

# Télécharger le serveur Hytale
./scripts/update.sh download

# Démarrer
./hytale.sh start
```

---

## 📁 Structure

```
hytale-server/
├── hytale.sh              # Script principal
├── setup-hytale.sh        # Installation
├── lib/
│   └── utils.sh           # Bibliothèque commune
├── scripts/
│   ├── update.sh          # Téléchargement
│   ├── backup.sh          # Backups (pigz)
│   ├── watchdog.sh        # Surveillance
│   ├── status-live.sh     # Discord live
│   └── hytale-auth.sh     # Auth OAuth2
├── config/
│   ├── server.conf        # Configuration serveur
│   └── discord.conf       # Webhooks Discord
├── services/              # Fichiers systemd
├── server/                # HytaleServer.jar
├── assets/                # Assets.zip
├── backups/               # Sauvegardes
└── logs/                  # Journaux
```

---

## 📚 Commandes

### Gestion du serveur

| Commande | Description |
|----------|-------------|
| `./hytale.sh start` | Démarrer le serveur |
| `./hytale.sh stop` | Arrêter le serveur |
| `./hytale.sh restart` | Redémarrer (immédiat) |
| `./hytale.sh status` | Statut (CPU, RAM, joueurs) |
| `./hytale.sh players` | Joueurs connectés |
| `./hytale.sh console` | Console (`Ctrl+A,D` pour quitter) |
| `./hytale.sh say "Message"` | Envoyer un message in-game |

### Restart planifié et mise à jour

| Commande | Description |
|----------|-------------|
| `./hytale.sh scheduled-restart` | Restart avec annonces (5min, 1min...) |
| `./hytale.sh check-update` | Vérifier les mises à jour |
| `./hytale.sh update` | Mettre à jour + restart |
| `./scripts/update.sh download` | Télécharger le serveur |

### Maintenance

| Commande | Description |
|----------|-------------|
| `./hytale.sh log-rotate` | Archiver et nettoyer les logs |
| `./scripts/backup.sh create` | Créer un backup |
| `./scripts/backup.sh list` | Lister les backups |
| `./scripts/backup.sh restore <file>` | Restaurer un backup |
| `./scripts/watchdog.sh check` | Vérifier la santé du serveur |
| `./scripts/status-live.sh init` | Créer message Discord live |

---

## ⚙️ Configuration

### Serveur (`config/server.conf`)

```bash
# Java
JAVA_PATH="/usr/lib/jvm/temurin-25-jdk-amd64/bin/java"
JAVA_OPTS="-Xms4G -Xmx8G"

# Serveur
BIND_ADDRESS="0.0.0.0:5520"
SERVER_NAME="Mon Serveur Hytale"
MAX_PLAYERS=20

# Restart automatique
AUTO_RESTART_TIMES="06:00 18:00"
RESTART_WARNINGS="300 60 30 10 5"
AUTO_UPDATE_ON_RESTART="true"

# Maintenance
USE_PIGZ="true"              # Backups rapides
LOG_RETENTION_DAYS=7         # Rétention logs
MIN_DISK_SPACE_GB=5          # Espace minimum
WATCHDOG_ENABLED="true"      # Auto-restart crash
```

### Discord (`config/discord.conf`)

```bash
WEBHOOK_URL="https://discord.com/api/webhooks/ID/TOKEN"
WEBHOOK_USERNAME="Hytale Bot"
WEBHOOK_AVATAR_URL=""
STATUS_MESSAGE_ID=""         # Généré par status-live.sh init
```

---

## 🔧 Systemd

```bash
# Démarrer/arrêter
sudo systemctl start hytale
sudo systemctl stop hytale
sudo systemctl status hytale

# Logs
journalctl -u hytale -f

# Activer au démarrage
sudo systemctl enable hytale
sudo systemctl enable hytale-backup.timer
sudo systemctl enable hytale-watchdog.timer
```

---

## ⏰ Cron (alternative à systemd)

```bash
crontab -e

# Watchdog - toutes les 2 minutes
*/2 * * * * /opt/hytale/scripts/watchdog.sh check

# Status Discord - toutes les 5 minutes
*/5 * * * * /opt/hytale/scripts/status-live.sh update

# Rotation logs - quotidien
0 4 * * * /opt/hytale/hytale.sh log-rotate
```

---

## 🔐 Authentification OAuth2

Première utilisation de `./scripts/update.sh download` :

1. Une URL et un code s'affichent
2. Visitez : https://accounts.hytale.com/device
3. Entrez le code pour autoriser
4. Le téléchargement démarre automatiquement

En cas d'erreur 403 : `./scripts/update.sh auth-reset`

---

## 🌐 Firewall

```bash
# UFW
sudo ufw allow 5520/udp

# firewalld
sudo firewall-cmd --permanent --add-port=5520/udp
sudo firewall-cmd --reload
```

---

## 🔧 Dépannage

| Problème | Solution |
|----------|----------|
| 403 Forbidden | `./scripts/update.sh auth-reset` |
| Java non trouvé | Définir `JAVA_PATH` dans config |
| Port inaccessible | Ouvrir **UDP 5520** |
| Backup trop lent | Installer `pigz` |
| Crash serveur | Vérifier logs dans `logs/` |

---

## 📖 Liens utiles

- [Hytale Server Manual](https://support.hytale.com/hc/en-us/articles/45326769420827)
- [Authentification Hytale](https://accounts.hytale.com/device)
- [Adoptium Temurin (Java 25)](https://adoptium.net/)

---

## 📜 License

[MIT](LICENSE)
