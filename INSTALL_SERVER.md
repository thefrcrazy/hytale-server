# 🎮 Guide d'Installation - Serveur Hytale Dédié

## 📋 Prérequis

| Élément | Requis |
|---------|--------|
| OS | Linux (Ubuntu/Debian recommandé) |
| Java | **Java 25 LTS** (Adoptium Temurin) |
| RAM | 4 GB minimum, 8 GB recommandé |
| Port | **UDP 5520** (protocole QUIC) |

---

## 1️⃣ Installer Java 25 (Adoptium Temurin)

```bash
# Importer la clé GPG Adoptium
sudo wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | \
    gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/adoptium.gpg > /dev/null

# Ajouter le dépôt
echo "deb https://packages.adoptium.net/artifactory/deb $(awk -F= '/^VERSION_CODENAME/{print$2}' /etc/os-release) main" | \
    sudo tee /etc/apt/sources.list.d/adoptium.list

# Installer
sudo apt update && sudo apt install -y temurin-25-jdk

# Vérifier
java --version
```

**Chemin Java Temurin** : `/usr/lib/jvm/temurin-25-jdk-amd64/bin/java`

---

## 2️⃣ Installation Rapide

```bash
# Créer le dossier du serveur
mkdir -p /home/hytale/myserver
cd /home/hytale/myserver

# Télécharger setup-hytale.sh (votre méthode)
# ...

# Lancer l'installation
sudo chmod +x setup-hytale.sh
sudo ./setup-hytale.sh
```

Le script `setup-hytale.sh` crée automatiquement :
- Tous les scripts (`hytale.sh`, `backup.sh`, `update.sh`, `hytale-auth.sh`)
- Les fichiers de configuration (`config/server.conf`, `config/discord.conf`)
- Les dossiers (`server/`, `assets/`, `backups/`, `logs/`)

---

## 3️⃣ Configurer

```bash
# Configuration principale
sudo nano config/server.conf

# Webhooks Discord (optionnel)
sudo nano config/discord.conf
```

**Variables importantes** (`server.conf`) :
```bash
JAVA_PATH="/usr/lib/jvm/temurin-25-jdk-amd64/bin/java"  # Java personnalisé
JAVA_OPTS="-Xms4G -Xmx8G"                               # Mémoire
BIND_ADDRESS="0.0.0.0:5520"                             # Port

# Restart automatique
AUTO_RESTART_TIMES="06:00 18:00"                        # Heures de restart
RESTART_WARNINGS="300 60 30 10 5"                       # Délais d'annonce (secondes)
AUTO_UPDATE_ON_RESTART="true"                          # MAJ auto avant restart
```

---

## 4️⃣ Télécharger le Serveur

```bash
sudo ./update.sh download
```

**Première utilisation** : authentification OAuth2 requise
1. Une URL et un code s'affichent
2. Visitez : https://accounts.hytale.com/device
3. Entrez le code
4. Le téléchargement démarre automatiquement

---

## 5️⃣ Démarrer

```bash
# Démarrer
sudo ./hytale.sh start

# Statut
sudo ./hytale.sh status

# Console (screen -r, Ctrl+A,D pour quitter)
sudo ./hytale.sh console

# Arrêter
sudo ./hytale.sh stop
```

**Avec systemd** :
```bash
sudo systemctl start hytale
sudo systemctl status hytale
journalctl -u hytale -f
```

---

## 6️⃣ Ouvrir le Firewall

```bash
# UFW
sudo ufw allow 5520/udp

# firewalld
sudo firewall-cmd --permanent --add-port=5520/udp && sudo firewall-cmd --reload
```

---

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
| `sudo ./hytale.sh scheduled-restart` | Restart avec annonces (5min, 1min, 30s...) |
| `sudo ./hytale.sh check-update` | Vérifier les mises à jour |
| `sudo ./hytale.sh update` | Mettre à jour + restart avec annonces |
| `sudo ./update.sh download` | Télécharger le serveur |

### Utilitaires
| Commande | Description |
|----------|-------------|
| `sudo ./hytale.sh say "Message"` | Envoyer un message in-game |
| `sudo ./backup.sh create` | Backup manuel |
| `sudo ./hytale-auth.sh trigger` | Auth OAuth2 |

---

## � Dépannage

| Problème | Solution |
|----------|----------|
| 403 Forbidden | `./update.sh auth-reset` puis réessayer |
| Java non trouvé | Définir `JAVA_PATH` dans `config/server.conf` |
| Port inaccessible | Ouvrir **UDP 5520** (pas TCP !) |

---

## 📖 Liens

- [Hytale Server Manual](https://support.hytale.com/hc/en-us/articles/45326769420827)
- [Authentification](https://accounts.hytale.com/device)
- [Adoptium Temurin](https://adoptium.net/)
