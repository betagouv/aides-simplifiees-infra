# aides simplifiées - Infrastructure

Infrastructure Docker pour le produit [aides simplifiées](https://beta.gouv.fr/startups/droit-data-gouv-fr-simulateurs-de-droits.html)

## Architecture

- **Nginx** : Reverse proxy (ports 80/443)
- **Main app** : [aides-simplifiees-app](https://github.com/betagouv/aides-simplifiees-app) (AdonisJS)
- **OpenFisca** : [aides-calculatrice-back](https://github.com/betagouv/aides-calculatrice-back) (calculs)
- **PostgreSQL 17** : Base de données
- **Docker Secrets** : Gestion sécurisée des secrets

**[Documentation détaillée avec diagrammes](./docs/architecture-overview.md)** - Vue complète de l'architecture avec diagrammes Mermaid

## Démarrage rapide

```bash
# 1. Cloner et configurer
git clone https://github.com/betagouv/aides-simplifiees-infra.git
cd aides-simplifiees-infra
cp .env.template .env

# 2. Démarrer (développement)
make dev

# 3. Vérifier le statut
make health
```

**Accès :**
- Application : http://localhost:80
- Main app (dev) : http://localhost:3333  
- OpenFisca (dev) : http://localhost:5001
- Database (dev) : localhost:5432

## Docker Secrets

Les secrets sont gérés de manière sécurisée sans variables d'environnement en plain text.

### Commandes
```bash
make secrets-setup      # Génère tous les secrets
make secrets-validate   # Vérifie leur existence
make secrets-rotate     # Régénère tous les secrets
```

### Secrets créés
- `db_password` : Mot de passe postgreSQL
- `admin_password` : Compte admin initial AdonisJS  
- `app_key` : Chiffrement AdonisJS
- `monitoring_secret` : Health checks

## Développement

### Commandes essentielles
```bash
make help               # Liste toutes les commandes
make dev               # Démarre en mode développement
make prod              # Démarre en mode production
make logs              # Affiche les logs
make down              # Arrête les services
make clean             # Nettoyage complet
```

### Logs par service
```bash
make main-app-logs     # Logs de l'application
make openfisca-logs    # Logs OpenFisca
make db-logs           # Logs PostgreSQL
make nginx-logs        # Logs nginx
```

### Base de données
```bash
make db-migrate        # Exécute les migrations
make db-seed           # Exécute les seeders
make db-backup         # Sauvegarde
make db-shell          # Shell PostgreSQL
```

## Configuration

### Variables d'environnement (.env)
```bash
ADONIS_ADMIN_LOGIN=admin@example.com
MAIN_APP_TAG=latest
OPENFISCA_TAG=latest
```

### Développement local
Pour développer avec les sources locales :
```bash
make dev-setup  # Clone les dépôts adjacents
```

## Dépannage

### Problèmes fréquents
```bash
# Secrets manquants
make secrets-validate && make secrets-setup

# Ports occupés  
lsof -i :3333 :5001 :80 :5432

# Nettoyer Docker
make clean && docker system prune -a

# Base corrompue
make down && docker volume rm aides-simplifiees-infra_dbdata && make up

# Permissions secrets
chmod 600 secrets/*
```

## Support

- [Issues GitHub](https://github.com/betagouv/aides-simplifiees-infra/issues)
- [aides-simplifiees-app](https://github.com/betagouv/aides-simplifiees-app)
- [aides-calculatrice-back](https://github.com/betagouv/aides-calculatrice-back)
