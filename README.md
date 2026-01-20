# 🎮 Hytale Dedicated Server

Script d'installation et de gestion pour serveur Hytale dédié sous Linux.

## ✨ Fonctionnalités

- 📦 **Installation interactive CLI** - FR/EN, configuration guidée
- 🔄 **Téléchargement officiel** - Via hytale-downloader avec OAuth2
- 💾 **Backups rapides** - Compression parallèle avec pigz
- 🔔 **Notifications Discord** - Webhooks enrichis
- 🐕 **Watchdog** - Redémarrage automatique si crash
- 📊 **Status Live** - Message Discord mis à jour en temps réel
- ⏰ **Restart planifié** - Avec annonces in-game
- 🌐 **Multilingue** - Français et Anglais

---

## 📋 Prérequis

| Élément | Requis |
|---------|--------|
| **OS** | Linux (Ubuntu/Debian recommandé) |
| **Java** | Java 25+ ([Adoptium Temurin](https://adoptium.net/)) |
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

```bash
# Télécharger et lancer l'installation interactive
curl -fsSL https://raw.githubusercontent.com/thefrcrazy/hytale-server/main/setup-hytale.sh -o setup-hytale.sh
chmod +x setup-hytale.sh
./setup-hytale.sh
```

L'assistant vous guide à travers 10 étapes :
1. 🌐 Choix de la langue (FR/EN)
2. 🖥️ Détection du système
3. 📁 Répertoire d'installation
4. 👤 Configuration utilisateur (auto)
5. 📦 Dépendances
6. ☕ Vérification Java
7. ⚙️ Configuration serveur (port, nom)
8. 💬 Configuration Discord (optionnel)
9. 📥 Téléchargement des scripts
10. 🔧 Services systemd

### Après l'installation

```bash
# Démarrer le serveur (téléchargement auto si nécessaire)
./hytale.sh start
```

### Mise à jour

```bash
./setup-hytale.sh update
```

---

## 📁 Structure

```
hytale-server/
├── hytale.sh              # Script principal
├── setup-hytale.sh        # Installation & mise à jour
├── lib/
│   └── utils.sh           # Bibliothèque commune (traductions)
├── scripts/
│   ├── update.sh          # Téléchargement serveur
│   ├── backup.sh          # Backups
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
| `./hytale.sh start` | Démarrer (télécharge auto si nécessaire) |
| `./hytale.sh stop` | Arrêter |
| `./hytale.sh restart` | Redémarrer |
| `./hytale.sh status` | Statut (CPU, RAM, uptime) |
| `./hytale.sh players` | Joueurs connectés |
| `./hytale.sh console` | Console (`Ctrl+A,D` pour quitter) |
| `./hytale.sh say "Message"` | Message in-game |

### Mise à jour et maintenance

| Commande | Description |
|----------|-------------|
| `./setup-hytale.sh update` | Mettre à jour les scripts |
| `./hytale.sh scheduled-restart` | Restart avec annonces |
| `./hytale.sh check-update` | Vérifier mises à jour serveur |
| `./hytale.sh update` | Mettre à jour + restart |
| `./scripts/update.sh download` | Télécharger le serveur |

### Backups

| Commande | Description |
|----------|-------------|
| `./scripts/backup.sh create` | Créer un backup |
| `./scripts/backup.sh list` | Lister les backups |
| `./scripts/backup.sh restore <file>` | Restaurer |

---

## ⚙️ Configuration

### Serveur (`config/server.conf`)

```bash
# Langue (fr/en)
LANG_CODE="fr"

# Serveur
BIND_ADDRESS="0.0.0.0:5520"
SCREEN_NAME="hytale_XXXXXX"  # Généré automatiquement

# Java
JAVA_PATH="/usr/lib/jvm/temurin-25-jdk-amd64/bin/java"
JAVA_OPTS="-Xms4G -Xmx8G"

# Maintenance
WATCHDOG_ENABLED="true"
LOG_RETENTION_DAYS=7
MIN_DISK_SPACE_GB=5
```

### Discord (`config/discord.conf`)

```bash
# Array de webhooks (sans virgules !)
WEBHOOKS=(
    "https://discord.com/api/webhooks/ID/TOKEN"
)
WEBHOOK_USERNAME="Hytale Bot"
```

---

## 🔧 Systemd

```bash
# Gestion
sudo systemctl start|stop|restart hytale
sudo systemctl status hytale

# Activer au démarrage
sudo systemctl enable hytale
sudo systemctl enable hytale-backup.timer
sudo systemctl enable hytale-watchdog.timer

# Logs
journalctl -u hytale -f
```

---

## 🔐 Authentification OAuth2

Lors du premier téléchargement :

1. Une URL et un code s'affichent
2. Visitez l'URL dans votre navigateur
3. Connectez-vous avec votre compte Hytale
4. Le téléchargement démarre automatiquement

```bash
# En cas d'erreur 403
./scripts/update.sh auth-reset
```

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
| Erreur 403 | `./scripts/update.sh auth-reset` |
| Java non trouvé | Définir `JAVA_PATH` dans config |
| Port inaccessible | Ouvrir **UDP 5520** |
| Backup lent | Installer `pigz` |

---

## 📖 Liens

- [Hytale Server Manual](https://support.hytale.com/hc/en-us/articles/45326769420827)
- [Adoptium Temurin (Java 25)](https://adoptium.net/)

---

## 📜 License

[MIT](LICENSE)
