# TFE — Stratégie de sauvegarde sécurisée pour PME

## Auteur
Hamoumi Sifdine — Bachelier en Informatique, Orientation Sécurité des Systèmes — EPHEC 2025-2026

## Description
Mise en place d'une stratégie de sauvegarde sécurisée, chiffrée et testée
pour une PME fictive de services informatiques, basée sur BorgBackup,
Borgmatic et Docker Compose, suivant le principe 3-2-1.

## Architecture
- Serveur principal (Lenovo Ubuntu) → données source
- Dépôt Borg local → restauration rapide
- Serveur distant Hetzner → copie hors site chiffrée

## Technologies
- BorgBackup / Borgmatic
- Docker / Docker Compose
- SSH (authentification par clé)
- GitHub (portabilité du projet)

## Références
- NIST Cybersecurity Framework 2.0
- CyberFundamentals Framework (CyFun) — CCB Belgique
- CIS Controls v8.1
