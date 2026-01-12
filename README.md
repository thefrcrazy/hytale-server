# 🎮 Hytale Dedicated Server

Script d'installation automatique pour serveur Hytale dédié sous Linux.

## ✨ Fonctionnalités

- 📦 **Installation automatique** - Un seul script génère tout
- 🔄 **Téléchargement officiel** - Via hytale-downloader
- 💾 **Backups automatiques** - Avec rotation
- 🔔 **Notifications Discord** - Webhooks intégrés
- 🔐 **Auth OAuth2** - Support authentification Hytale
- ⚙️ **Systemd** - Services Linux inclus

## 📋 Prérequis

- **Linux** (Ubuntu/Debian recommandé)
- **Java 25+** ([Adoptium Temurin](https://adoptium.net/))
- **Port UDP 5520** ouvert

## 🚀 Installation Rapide

```sh
# 1. Télécharger et extraire
mkdir -p hytale-server && cd hytale-server
wget https://github.com/thefrcrazy/hytale-server/releases/latest/download/hytale-server.zip
unzip hytale-server.zip && rm hytale-server.zip

# 2. Lancer l'installation
chmod +x setup-hytale.sh
./setup-hytale.sh

# 3. Configurer
nano config/server.conf
nano config/discord.conf

# 4. Télécharger le serveur Hytale
./update.sh download

# 5. Démarrer
./hytale.sh start
```

## 📚 Commandes

| Commande | Description |
|----------|-------------|
| `./update.sh download` | Télécharger le serveur |
| `./hytale.sh start` | Démarrer |
| `./hytale.sh stop` | Arrêter |
| `./hytale.sh status` | Statut |
| `./hytale.sh console` | Console (Ctrl+A,D pour quitter) |
| `./backup.sh create` | Backup manuel |
| `./hytale-auth.sh trigger` | Authentification |

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

### Discord (`config/discord.conf`)
```sh
WEBHOOK_URL="https://discord.com/api/webhooks/VOTRE_ID/VOTRE_TOKEN"
```

## 🔐 Authentification

1. `./update.sh download`
2. Visitez l'URL affichée
3. Entrez le code sur https://accounts.hytale.com/device

## � Documentation

Voir [INSTALL_SERVER.md](INSTALL_SERVER.md) pour le guide complet.

## � License

[MIT](LICENSE)
