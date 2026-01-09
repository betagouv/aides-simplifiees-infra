# aides simplifiées - Infrastructure

Infrastructure Docker pour le produit [aides simplifiées](https://beta.gouv.fr/startups/droit-data-gouv-fr-simulateurs-de-droits.html).

**[Documentation détaillée de l'architecture et des ports](./docs/architecture-overview.md)**

## Démarrage rapide (Local)

```bash
# 1. Configurer
git clone https://github.com/betagouv/aides-simplifiees-infra.git
cd aides-simplifiees-infra
cp .env.template .env
make generate-secrets  # Génère des secrets sécurisés

# 2. Démarrer
make dev      # Développement (hot-reload, debuggers, API exposées)
# OU
make local    # Production locale (sources montées)

# 3. Vérifier
make health
```
Accès: http://localhost:8080 (App), http://localhost:5001 (OpenFisca), http://localhost:3000 (LexImpact)

## Environnements Serveur

| Env | Commande | Fichier Env | Port | Description |
|-----|----------|-------------|------|-------------|
| **Prod** | `make prod` | `.env.prod` | 8080 | Instance de production officielle |
| **Preprod** | `make preprod` | `.env.preprod` | 8081 | Instance de recette / staging |

> Les environnements serveur utilisent des bases de données et des volumes distincts (`_prod` et `_preprod`) pour garantir une isolation totale.

## Commandes utiles

| Action | Commande |
|--------|----------|
| **Logs** | `make logs`, `make main-app-logs`, `make db-logs` |
| **Base de données** | `make db-shell ENV=prod|preprod|dev` (SQL shell) |
| **Backup** | `make db-backup ENV=prod|preprod` (dans `database/backups_<env>`) |
| **Aide** | `make help` (Liste toutes les commandes) |

## Déploiement

1. Sur le serveur, cloner le repo.
2. Créer `.env.prod` et `.env.preprod` à partir de `.env.template`.
3. Générer des secrets uniques pour chaque environnement : `make generate-secrets`.
4. Configurer les variables spécifiques (URLs, Matomo).
5. Lancer : `make prod` et/ou `make preprod`.

Voir [docs/architecture-overview.md](./docs/architecture-overview.md) pour les détails techniques.