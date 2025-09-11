# aides simplifiées - Infrastructure

Infrastructure Docker pour le produit [aides simplifiées](https://beta.gouv.fr/startups/droit-data-gouv-fr-simulateurs-de-droits.html)

## Architecture

- **Main app** : [aides-simplifiees-app](https://github.com/betagouv/aides-simplifiees-app) (AdonisJS) - Port 80 (dev), 8080 (prod)
- **OpenFisca** : [aides-calculatrice-back](https://github.com/betagouv/aides-calculatrice-back) (calculs) - Port 5001 (dev), interne (prod)
- **LexImpact** : [territoires](https://git.leximpact.dev/leximpact/territoires/territoires) (API autocomplétion communes) - Port 3000 (dev), interne (prod)
- **PostgreSQL 17** : Base de données

**[Documentation détaillée avec diagrammes](./docs/architecture-overview.md)** - Vue complète de l'architecture avec diagrammes Mermaid

## Démarrage rapide

```bash
# 1. Cloner et configurer
git clone https://github.com/betagouv/aides-simplifiees-infra.git
cd aides-simplifiees-infra
cp .env.template .env

# 2. Démarrer (développement)
make dev # ou make local ou make prod

# 3. Vérifier le statut
make health
```

**Accès :**

**Tous les environnements :**
- Application principale : http://localhost:8080
- OpenFisca API : http://localhost:5001 (dev/local uniquement)
- LexImpact API : http://localhost:3000 (dev/local uniquement)
- Database : localhost:5432 (dev/local uniquement)
- Debug Node.js : localhost:9229 (dev/local uniquement)
- Debug Python : localhost:5678 (dev/local uniquement)

**Notes par environnement:**
- **dev**: NODE_ENV=development, build target=development
- **local**: NODE_ENV=production, volumes montés, debugging activé
- **prod**: Services internes uniquement, pas de ports de debug

> **Note:** Static files (assets, images, etc.) are now served directly by the AdonisJS application. The internal nginx proxy has been removed to simplify the architecture. SSL termination and advanced routing should be handled by external infrastructure.

## Configuration

Les variables d'environnement sont gérées via le fichier `.env`.

### Génération de secrets sécurisés
```bash
make generate-secrets   # Génère des valeurs sécurisées à copier dans .env
```

### Variables importantes dans .env
- `DB_PASSWORD` : Mot de passe PostgreSQL
- `ADMIN_PASSWORD` : Compte admin initial AdonisJS  
- `APP_KEY` : Clé de chiffrement AdonisJS (32 caractères)
- `MONITORING_SECRET` : Secret pour les health checks
- `MAIN_APP_TAG`, `OPENFISCA_TAG`, `LEXIMPACT_TAG` : Versions des images Docker (production)

## Développement

### Commandes essentielles
```bash
make help               # Liste toutes les commandes
make dev               # Démarre en mode développement
make prod              # Démarre en mode production
make logs              # Affiche les logs
make health            # Statut des services
make health-check      # Vérification complète de santé
make down              # Arrête les services
make clean             # Nettoyage complet
```

### Logs par service
```bash
make main-app-logs     # Logs de l'application
make openfisca-logs    # Logs OpenFisca
make leximpact-logs    # Logs LexImpact
make db-logs           # Logs PostgreSQL
```

### Base de données
```bash
make db-migrate        # Exécute les migrations
make db-seed           # Exécute les seeders
make db-backup         # Sauvegarde
make db-shell          # Shell PostgreSQL
```

### Exemple de configuration (.env)
```bash
# Application
NODE_ENV=production
ADMIN_LOGIN=admin@beta.gouv.fr
APP_KEY=your-32-character-app-key-here

# Database
DB_PASSWORD=your-secure-database-password-here

# Monitoring
MONITORING_SECRET=your-monitoring-secret-here

# Images Docker (production)
MAIN_APP_TAG=latest
OPENFISCA_TAG=latest
LEXIMPACT_TAG=latest
```

### Développement local
Pour développer avec les sources locales :
```bash
make local-setup              # Clone tous les dépôts adjacents
```

**Structure attendue (développement) :**
```
parent-directory/
├── aides-simplifiees-infra/     (ce projet)
├── territoires/                 (LexImpact - requis pour dev/local)
├── aides-simplifiees-app/       (optionnel)
└── aides-calculatrice-back/     (optionnel)
```

### Déploiement en production

#### Étapes de déploiement production :

1. **Configuration simple (recommandée)**
   ```bash
   # Cloner uniquement ce repository
   git clone https://github.com/betagouv/aides-simplifiees-infra.git
   cd aides-simplifiees-infra
   cp .env.template .env
   # Éditer .env avec vos valeurs de production
   make prod
   ```
   
   La production utilise automatiquement l'image pré-compilée `ghcr.io/betagouv/leximpact-territoires:latest`.

2. **Build personnalisé (optionnel)**
   
   Si vous souhaitez construire l'image LexImpact localement :
   ```bash
   # Cloner les repositories requis
   git clone https://github.com/betagouv/aides-simplifiees-infra.git
   git clone https://git.leximpact.dev/leximpact/territoires/territoires.git
   cd aides-simplifiees-infra
   make build-leximpact-image  # Build local
   make prod
   ```

3. **Publication d'image (développeurs seulement)** :
   ```bash
   # Construire et publier l'image depuis ce repository
   make build-leximpact-image    # Construit l'image localement
   make push-leximpact-image     # Construit et publie sur ghcr.io
   ```
   
   La production utilise automatiquement l'image pré-compilée `ghcr.io/betagouv/leximpact-territoires:latest`

## Dépannage

### Problèmes fréquents
```bash
# Variables d'environnement manquantes
cp .env.template .env && make generate-secrets

# Ports occupés (développement/local)
lsof -i :8080 :3000 :5001 :5432 :9229 :5678

# Ports occupés (production)  
lsof -i :8080

# Nettoyer Docker
make clean && docker system prune -a

# Base corrompue
make down && docker volume rm aides-simplifiees-infra_dbdata && make up

# Vérifier la configuration
make health-check
```

## Support

- [Issues GitHub](https://github.com/betagouv/aides-simplifiees-infra/issues)
- [aides-simplifiees-app](https://github.com/betagouv/aides-simplifiees-app)
- [aides-calculatrice-back](https://github.com/betagouv/aides-calculatrice-back)