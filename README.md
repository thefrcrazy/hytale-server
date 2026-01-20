# 🎮 Hytale Dedicated Server

Script d'installation automatique pour serveur Hytale dédié sous Linux.

## ✨ Fonctionnalités

- 📦 **Installation automatique** - Un seul script génère tout
- 🔄 **Téléchargement officiel** - Via hytale-downloader
- 💾 **Backups automatiques** - Avec rotation
- 🔔 **Notifications Discord** - Webhooks intégrés
- 🔐 **Auth OAuth2** - Support authentification Hytale
- ⚙️ **Systemd** - Services Linux inclus
- ⏰ **Restart planifié** - Avec annonces in-game aux joueurs
- 📥 **Mise à jour automatique** - Vérification et installation des updates

## 📋 Prérequis

- **Linux** (Ubuntu/Debian recommandé)
- **Java 25+** ([Adoptium Temurin](https://adoptium.net/))
- **Port UDP 5520** ouvert

## 🚀 Installation Rapide
### Étape 3 : Plus de détails sur la configuration [INSTALL_SERVER.md](INSTALL_SERVER.md).

```sh
# 0. Prérequis
sudo apt update && sudo apt upgrade -y
sudo apt install wget unzip -y

# 1. Télécharger et extraire
sudo mkdir -p hytale-server && cd hytale-server
sudo wget https://github.com/thefrcrazy/hytale-server/releases/latest/download/hytale-server.zip
sudo unzip hytale-server.zip && rm hytale-server.zip

# 2. Lancer l'installation
sudo chmod +x setup-hytale.sh
sudo ./setup-hytale.sh

# 3. Configurer 
sudo nano config/server.conf
sudo nano config/discord.conf

# 4. Télécharger le serveur Hytale
sudo ./update.sh download

# 5. Démarrer
sudo ./hytale.sh start
```

## 📚 Commandes

### Commandes de base
| Commande | Description |
|----------|-------------|
| `sudo ./hytale.sh start` | Démarrer le serveur |
| `sudo ./hytale.sh stop` | Arrêter le serveur |
| `sudo ./hytale.sh restart` | Redémarrer (immédiat) |
| `sudo ./hytale.sh status` | Statut (CPU, RAM, joueurs) |
| `sudo ./hytale.sh players` | Afficher les joueurs connectés |
| `sudo ./hytale.sh console` | Console (`Ctrl+A,D` pour quitter) |

### Restart planifié et mise à jour
| Commande | Description |
|----------|-------------|
| `sudo ./hytale.sh scheduled-restart` | Restart avec annonces aux joueurs (5min, 1min, 30s...) |
| `sudo ./hytale.sh check-update` | Vérifier si une mise à jour est disponible |
| `sudo ./hytale.sh update` | Mettre à jour + restart avec annonces |
| `sudo ./update.sh download` | Télécharger le serveur |

### Utilitaires
| Commande | Description |
|----------|-------------|
| `sudo ./hytale.sh say "Message"` | Envoyer un message aux joueurs via /say |
| `sudo ./backup.sh create` | Backup manuel |
| `sudo ./hytale-auth.sh trigger` | Authentification OAuth2 |

## 📁 Structure

```
hytale-server/
├── setup-hytale.sh        # Installation
├── hytale.sh              # Script principal
├── update.sh              # Téléchargement
├── backup.sh              # Backups
├── hytale-auth.sh         # Auth OAuth2
├── config/
│   ├── server.conf        # Configuration
│   └── discord.conf       # Webhooks
├── server/                # HytaleServer.jar
├── assets/                # Assets.zip
├── backups/               # Sauvegardes
└── logs/                  # Journaux
```

## ⚙️ Configuration

### Java personnalisé (`config/server.conf`)
```sh
JAVA_PATH="/usr/lib/jvm/temurin-25-jdk-amd64/bin/java"
JAVA_OPTS="-Xms4G -Xmx8G"
```

### Restart automatique (`config/server.conf`)
```sh
# Heures de restart (format 24h, séparées par espaces)
AUTO_RESTART_TIMES="06:00 18:00"

# Délais d'annonce avant restart (secondes)
RESTART_WARNINGS="300 60 30 10 5"

# Mise à jour automatique avant restart
AUTO_UPDATE_ON_RESTART="true"
```

### Discord (`config/discord.conf`)
```sh
WEBHOOK_URL="https://discord.com/api/webhooks/VOTRE_ID/VOTRE_TOKEN"
```

## 🔐 Authentification

1. `sudo ./update.sh download`
2. Visitez l'URL affichée
3. Entrez le code sur https://accounts.hytale.com/device

## � Documentation

Voir [INSTALL_SERVER.md](INSTALL_SERVER.md) pour le guide complet.

## � License

[MIT](LICENSE)
