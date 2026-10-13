# Stratégie de sauvegarde et de restauration sécurisée pour une PME

> Travail de Fin d'Études — Bachelier en Informatique, orientation Sécurité des Systèmes
> EPHEC (ITSCM) · 2025–2026 · Sifdine Hamoumi

Conception et implémentation d'une stratégie de sauvegarde **chiffrée, automatisée et testée** pour une PME fictive de services numériques (infogérance, 8 employés), basée entièrement sur des outils **open source**.

**Idée directrice :** sauvegarder ne suffit pas — l'enjeu est de pouvoir **restaurer** vite et de façon fiable après un incident (erreur humaine, panne, ransomware, sinistre physique).

---

## Architecture

La solution applique la règle **3-2-1** : 3 copies des données, sur 2 supports différents, dont 1 copie hors site.

```
LENOVO (serveur principal)                    HETZNER (serveur distant)
┌────────────────────────────┐                ┌──────────────────────────┐
│  Données de production      │                │                          │
│  data/{clients,             │                │                          │
│        administratif,       │                │                          │
│        configs}             │                │                          │
│            │                │                │                          │
│            ▼                │   SSH chiffré  │                          │
│  ┌──────────────────────┐   │   (ED25519)    │   ┌──────────────────┐   │
│  │ Conteneur Docker     │   │ ─────────────► │   │ Dépôt Borg       │   │
│  │ Borgmatic            │   │                │   │ distant          │   │
│  │ (orchestration)      │   │                │   │ (append-only)    │   │
│  └──────────┬───────────┘   │                │   └──────────────────┘   │
│             ▼                │                │                          │
│  Dépôt Borg local            │                │                          │
│  /var/backup/borg-local      │                │                          │
└────────────────────────────┘                └──────────────────────────┘
      copie 1 + copie 2                                  copie 3
```

- **Lenovo** = serveur principal (source des données + dépôt local pour restauration rapide)
- **Conteneur Docker Borgmatic** = moteur qui orchestre les sauvegardes (il ne stocke rien lui-même)
- **Hetzner** = copie hors site, chiffrée, en append-only

---

## Stack technique

| Composant | Rôle |
|-----------|------|
| **BorgBackup** | Moteur de sauvegarde : chiffrement AES-256, déduplication par blocs |
| **Borgmatic** | Orchestration : automatisation, politiques de rétention |
| **Docker Compose** | Portabilité et isolation (volumes en lecture seule) |
| **Hetzner (CX22)** | Serveur distant Ubuntu 24.04 pour la copie hors site |

---

## Sécurité — défense en profondeur

- **Chiffrement** : mode `repokey-blake2` (AES-256 + intégrité BLAKE2). Les données sont chiffrées **avant** l'envoi — l'hébergeur ne voit jamais les données en clair.
- **Chiffrement en transit** : tunnel SSH (clés ED25519, sans mot de passe).
- **Append-only** : l'utilisateur de sauvegarde ne peut pas supprimer les archives existantes (protection anti-ransomware), imposé via `borg serve --append-only` dans `authorized_keys`.
- **Moindre privilège** : utilisateur `borgbackup` restreint à `borg serve --restrict-to-path`, accès root SSH désactivé.
- **Secret Docker** : la passphrase n'apparaît jamais en clair ni sur Git (`/run/secrets/borg_passphrase`).
- **Pare-feu UFW** : seul le port SSH (22) est ouvert.
- **Fail2ban** : bannissement automatique des IP après 3 tentatives échouées.

---

## Politique de sauvegarde

- **Fréquence** : quotidienne automatique à 2h (planifiée via le scheduler Borgmatic)
- **Rétention** : 7 quotidiennes · 4 hebdomadaires · 6 mensuelles
- **Répertoires sauvegardés** : `data/administratif`, `data/clients`, `data/configs`

---

## Objectifs de récupération (RTO / RPO)

Définis via une Business Impact Analysis :

| Indicateur | Cible | Mesuré lors des tests |
|-----------|-------|----------------------|
| RTO local | < 4 h | **< 2 min** |
| RTO distant | < 24 h | **4 min 17 s** |
| RPO | 24 h | Respecté (sauvegarde quotidienne) |

---

## Installation et utilisation

### Prérequis
- Docker et Docker Compose installés sur le serveur principal
- Un serveur distant accessible par SSH (clé ED25519)
- Un fichier `secrets/borg_passphrase` contenant la passphrase de chiffrement (non versionné)

### Démarrage

```bash
# Cloner le dépôt
git clone git@github.com:Sifdineha/tfe-backup-securise.git
cd tfe-backup-securise

# Lancer le conteneur (il tourne en continu et sauvegarde chaque nuit à 2h)
docker compose up -d
```

### Commandes utiles

```bash
# Lister les archives (dépôt local et distant)
docker exec borgmatic borgmatic list

# Lancer une sauvegarde manuelle
docker exec borgmatic borgmatic create --verbosity 1

# Vérifier le chiffrement d'un dépôt
docker exec borgmatic sh -c 'BORG_PASSPHRASE=$(cat /run/secrets/borg_passphrase) borg info /var/backup/borg-local'
```

### Restauration

```bash
# Depuis le dépôt local (restauration rapide)
docker exec borgmatic borgmatic extract --repository local --archive latest --destination /tmp/restauration

# Depuis le dépôt distant Hetzner (perte totale du serveur principal)
docker exec borgmatic borgmatic extract --repository distant --archive latest --destination /tmp/restauration-distante
```

---

## Gouvernance et référentiels

Le projet s'appuie sur des référentiels reconnus :

- **NIST Cybersecurity Framework 2.0** — fonctions Identify, Protect, Respond, Recover
- **NIST SP 800-37 Rev. 2 (RMF)** — cadre structurant de gestion des risques
- **CIS Controls v8.1** — Control 11 (Data Recovery)
- **CyberFundamentals Framework (CyFun)** — cadre belge lié à NIS2, niveau Basic

---

## Structure du dépôt

```
tfe-backup-securise/
├── data/                   # Données de l'entreprise fictive (3 catégories)
├── borgmatic/
│   └── config.yaml         # Configuration Borgmatic (dépôts, rétention, chiffrement)
├── docker-compose.yml      # Définition du conteneur et des secrets
├── ssh-init.sh             # Initialisation des clés SSH dans le conteneur
├── secrets/                # Passphrase (non versionné)
├── ssh/                    # Clés SSH (non versionné)
├── logs/                   # Journaux des sauvegardes (non versionné)
└── README.md
```

---

## Limites et perspectives

**Limites identifiées :** dépendance à la connectivité réseau pour la restauration distante, absence d'alertes automatiques en cas d'échec, gestion des clés de chiffrement à sécuriser davantage en production.

**Évolutions possibles :** gestion multi-clients, supervision avec alertes automatiques, gestionnaire de secrets centralisé (HashiCorp Vault), cadre contractuel (SLA, conformité RGPD, assurance).

---

## Auteur

**Sifdine Hamoumi** — [github.com/Sifdineha](https://github.com/Sifdineha)
TFE défendu avec succès · EPHEC 2025–2026

---

## Licence

Projet académique réalisé dans le cadre d'un Travail de Fin d'Études.
