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
wget -qO - https://packages.adoptium.net/artifactory/api/gpg/key/public | \
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
chmod +x setup-hytale.sh
./setup-hytale.sh           # Sans systemd
sudo ./setup-hytale.sh      # Avec systemd
```

Le script `setup-hytale.sh` crée automatiquement :
- Tous les scripts (`hytale.sh`, `backup.sh`, `update.sh`, `hytale-auth.sh`)
- Les fichiers de configuration (`config/server.conf`, `config/discord.conf`)
- Les dossiers (`server/`, `assets/`, `backups/`, `logs/`)

---

## 3️⃣ Configurer

```bash
# Configuration principale
nano config/server.conf

# Webhooks Discord (optionnel)
nano config/discord.conf
```

**Variables importantes** (`server.conf`) :
```bash
JAVA_PATH="/usr/lib/jvm/temurin-25-jdk-amd64/bin/java"  # Java personnalisé
JAVA_OPTS="-Xms4G -Xmx8G"                               # Mémoire
BIND_ADDRESS="0.0.0.0:5520"                             # Port
```

---

## 4️⃣ Télécharger le Serveur

```bash
./update.sh download
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
./hytale.sh start

# Statut
./hytale.sh status

# Console (Ctrl+A,D pour quitter)
./hytale.sh console

# Arrêter
./hytale.sh stop
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

| Commande | Description |
|----------|-------------|
| `./update.sh download` | Télécharger le serveur |
| `./hytale.sh start` | Démarrer |
| `./hytale.sh stop` | Arrêter |
| `./hytale.sh console` | Console |
| `./backup.sh create` | Backup manuel |
| `./hytale-auth.sh trigger` | Auth OAuth2 |

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
