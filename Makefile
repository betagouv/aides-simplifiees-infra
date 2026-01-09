SHELL := /bin/bash
export COMPOSE_DOCKER_CLI_BUILD=1
export DOCKER_BUILDKIT=1

# Default environment
ENV ?= dev

# Docker compose files
COMPOSE_FILE := docker-compose.yml
ifeq ($(ENV),prod)
    COMPOSE_FILE := docker-compose.yml -f docker-compose.prod.yml
else ifeq ($(ENV),preprod)
    COMPOSE_FILE := docker-compose.yml -f docker-compose.preprod.yml
else ifeq ($(ENV),dev)
    COMPOSE_FILE := docker-compose.yml -f docker-compose.dev.yml
else ifeq ($(ENV),local)
    COMPOSE_FILE := docker-compose.yml -f docker-compose.local.yml
else
    # For override environment, include override file if it exists
    ifneq (,$(wildcard docker-compose.override.yml))
        COMPOSE_FILE := docker-compose.yml -f docker-compose.override.yml
    endif
endif

.PHONY: help bootstrap build up logs down clean pull restart status setup

help: ## Affiche cette aide
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

bootstrap: ## Vérifie la configuration initiale
	@test -f .env || (echo "Créer le fichier .env (copier depuis .env.template et personnaliser)"; exit 1)
	@echo "Configuration OK"

generate-secrets: ## Génère des valeurs sécurisées pour les secrets dans .env
	@echo "Génération de valeurs sécurisées pour les secrets..."
	@DB_PASS=$$(openssl rand -base64 32 | tr -d '=+/' | cut -c1-25); \
	APP_KEY=$$(openssl rand -base64 32 | tr -d '=+/' | cut -c1-32); \
	ADMIN_PASS=$$(openssl rand -base64 32 | tr -d '=+/' | cut -c1-20); \
	MONITOR_SECRET=$$(openssl rand -base64 48 | tr -d '=+/' | cut -c1-40); \
	echo "Valeurs générées (à copier dans votre .env):"; \
	echo "DB_PASSWORD=$$DB_PASS"; \
	echo "APP_KEY=$$APP_KEY"; \
	echo "ADMIN_PASSWORD=$$ADMIN_PASS"; \
	echo "MONITORING_SECRET=$$MONITOR_SECRET"

setup: bootstrap ## Configuration complète (Usage: make setup ENV=dev|local|prod|preprod)
	@echo "Vérification des dépendances (environnement: $(ENV))..."
	@if [ "$(ENV)" = "prod" ]; then \
		echo "Mode production: utilisation des images pré-construites"; \
	else \
		echo "Mode dev/local: vérification des repositories sources..."; \
		MISSING=""; \
		if [ ! -d "../aides-simplifiees-app" ]; then MISSING="$$MISSING aides-simplifiees-app"; fi; \
		if [ ! -d "../aides-calculatrice-back" ]; then MISSING="$$MISSING aides-calculatrice-back"; fi; \
		if [ ! -d "../territoires" ]; then MISSING="$$MISSING territoires"; fi; \
		if [ -n "$$MISSING" ]; then \
			echo "  Repositories manquants pour dev/local:$$MISSING"; \
			echo "  Lancez: make local-setup pour cloner tous les repositories"; \
			echo "  Ou utilisez: make prod pour la production avec images pré-construites"; \
			exit 1; \
		else \
			echo "Tous les repositories sources trouvés"; \
		fi; \
	fi

build: bootstrap ## Build tous les services (Usage: make build ENV=dev|local|prod|preprod)
	docker compose --progress=plain -f $(COMPOSE_FILE) build

up: bootstrap ## Démarre tous les services (Usage: make up ENV=dev|local|prod|preprod)
	docker compose -f $(COMPOSE_FILE) up -d

logs: ## Affiche les logs de tous les services (Usage: make logs ENV=dev|local|prod|preprod)
	docker compose -f $(COMPOSE_FILE) logs -f --tail=100

down: ## Arrête tous les services (Usage: make down ENV=dev|local|prod|preprod)
	docker compose -f $(COMPOSE_FILE) down

clean: ## Arrête et supprime tout (Usage: make clean ENV=dev|local|prod|preprod)
	docker compose -f $(COMPOSE_FILE) down -v --remove-orphans
	docker system prune -f

pull: ## Met à jour les images de base (Usage: make pull ENV=dev|local|prod|preprod)
	docker compose -f $(COMPOSE_FILE) pull

restart: down up ## Redémarre tous les services (Usage: make restart ENV=dev|local|prod|preprod)

status: ## Affiche le statut des services (Usage: make status ENV=dev|local|prod|preprod)
	docker compose -f $(COMPOSE_FILE) ps

# Environment-specific build-up commands
dev: ## Démarre l'environnement de développement
	@$(MAKE) setup ENV=dev
	@docker compose -f docker-compose.yml -f docker-compose.dev.yml build
	@docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d

prod: ## Démarre l'environnement de production
	@$(MAKE) setup ENV=prod
	@docker compose -f docker-compose.yml -f docker-compose.prod.yml build
	@docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

local: ## Démarre l'environnement local (production locale)
	@$(MAKE) setup ENV=local
	@docker compose -f docker-compose.yml -f docker-compose.local.yml build
	@docker compose -f docker-compose.yml -f docker-compose.local.yml up -d

preprod: ## Démarre l'environnement de préproduction
	@$(MAKE) bootstrap
	@docker compose -f docker-compose.yml -f docker-compose.preprod.yml pull
	@docker compose -f docker-compose.yml -f docker-compose.preprod.yml up -d

# Commandes de développement
local-setup: ## Clone les dépôts pour le développement local
	@if [ ! -d "../aides-simplifiees-app" ]; then \
		echo "Clonage de aides-simplifiees-app..."; \
		git clone https://github.com/betagouv/aides-simplifiees-app.git ../aides-simplifiees-app; \
	else \
		echo "aides-simplifiees-app déjà cloné"; \
	fi
	@if [ ! -d "../aides-calculatrice-back" ]; then \
		echo "Clonage de aides-calculatrice-back..."; \
		git clone https://github.com/betagouv/aides-calculatrice-back.git ../aides-calculatrice-back; \
	else \
		echo "aides-calculatrice-back déjà cloné"; \
	fi
	@if [ ! -d "../territoires" ]; then \
		echo "Clonage de territoires (LexImpact)..."; \
		git clone https://git.leximpact.dev/leximpact/territoires/territoires.git ../territoires; \
	else \
		echo "territoires déjà cloné"; \
	fi

# Commandes spécifiques aux services
main-app-logs: ## Logs du main-app uniquement (Usage: make main-app-logs ENV=dev|local|prod|preprod)
	docker compose -f $(COMPOSE_FILE) logs -f main-app

openfisca-logs: ## Logs du openfisca uniquement (Usage: make openfisca-logs ENV=dev|local|prod|preprod)
	docker compose -f $(COMPOSE_FILE) logs -f openfisca

leximpact-logs: ## Logs du leximpact uniquement (Usage: make leximpact-logs ENV=dev|local|prod|preprod)
	docker compose -f $(COMPOSE_FILE) logs -f leximpact

db-logs: ## Logs de la base de données (Usage: make db-logs ENV=dev|local|prod|preprod)
	docker compose -f $(COMPOSE_FILE) logs -f db

db-shell: ## Shell dans la base de données (Usage: make db-shell ENV=dev|local|prod|preprod)
	@if [ "$(ENV)" = "preprod" ]; then \
		docker compose -f docker-compose.yml -f docker-compose.preprod.yml exec db psql -U aides-simplifiees -d aides-simplifiees-preprod; \
	elif [ "$(ENV)" = "prod" ]; then \
		docker compose -f docker-compose.yml -f docker-compose.prod.yml exec db psql -U aides-simplifiees -d aides-simplifiees-prod; \
	elif [ "$(ENV)" = "local" ]; then \
		docker compose -f docker-compose.yml -f docker-compose.local.yml exec db psql -U aides-simplifiees -d aides-simplifiees-local; \
	else \
		docker compose -f $(COMPOSE_FILE) exec db psql -U aides-simplifiees -d aides-simplifiees; \
	fi

# Database management commands
db-setup: ## Configure la base de données (Usage: make db-setup ENV=dev|local|prod|preprod)
	@echo "Configuration de la base de données..."
	@echo "Les migrations et seeders s'exécutent automatiquement via les services db-migrate et db-seed"

db-migrate: ## Execute les migrations uniquement (Usage: make db-migrate ENV=dev|local|prod|preprod)
	@echo "Exécution des migrations..."
	@docker compose -f $(COMPOSE_FILE) run --rm db-migrate

db-seed: ## Execute les seeders uniquement (Usage: make db-seed ENV=dev|local|prod|preprod)
	@echo "Exécution des seeders..."
	@docker compose -f $(COMPOSE_FILE) run --rm db-seed

db-reset: ## Remet à zéro la base de données (Usage: make db-reset ENV=dev|local|prod|preprod)
	@echo "Ceci va supprimer toutes les données de la base. Êtes-vous sûr? (y/N)"
	@read -r response && [ "$$response" = "y" ] || exit 1
	@echo "Suppression de la base de données..."
	@docker compose -f $(COMPOSE_FILE) down
	@if [ "$(ENV)" = "prod" ]; then \
		docker volume rm aides-simplifiees-prod_dbdata_prod || true; \
	elif [ "$(ENV)" = "preprod" ]; then \
		docker volume rm aides-simplifiees-preprod_dbdata_preprod || true; \
	elif [ "$(ENV)" = "local" ]; then \
		docker volume rm aides-simplifiees-local_dbdata_local || true; \
	else \
		docker volume rm aides-simplifiees-infra_dbdata || true; \
	fi
	@docker compose -f $(COMPOSE_FILE) up -d db
	@sleep 5
	@$(MAKE) db-setup ENV=$(ENV)

main-app-shell: ## Shell dans le container main-app (Usage: make main-app-shell ENV=dev|local|prod|preprod)
	docker compose -f $(COMPOSE_FILE) exec main-app sh

openfisca-shell: ## Shell dans le container openfisca (Usage: make openfisca-shell ENV=dev|local|prod|preprod)
	docker compose -f $(COMPOSE_FILE) exec openfisca bash

leximpact-shell: ## Shell dans le container leximpact (Usage: make leximpact-shell ENV=dev|local|prod|preprod)
	docker compose -f $(COMPOSE_FILE) exec leximpact sh

# Base de données
db-backup: ## Sauvegarde de la base de données (Usage: make db-backup ENV=dev|local|prod|preprod)
	@echo "Création d'une sauvegarde..."
	@if [ "$(ENV)" = "prod" ]; then \
		docker compose -f $(COMPOSE_FILE) exec db pg_dump -U aides-simplifiees aides-simplifiees-prod > database/backups_prod/backup_$$(date +%Y%m%d_%H%M%S).sql; \
	elif [ "$(ENV)" = "preprod" ]; then \
		docker compose -f $(COMPOSE_FILE) exec db pg_dump -U aides-simplifiees aides-simplifiees-preprod > database/backups_preprod/backup_$$(date +%Y%m%d_%H%M%S).sql; \
	elif [ "$(ENV)" = "local" ]; then \
		docker compose -f $(COMPOSE_FILE) exec db pg_dump -U aides-simplifiees aides-simplifiees-local > database/backups_local/backup_$$(date +%Y%m%d_%H%M%S).sql; \
	else \
		docker compose -f $(COMPOSE_FILE) exec db pg_dump -U aides-simplifiees aides-simplifiees > backup_$$(date +%Y%m%d_%H%M%S).sql; \
	fi

db-restore: ## Restaure la base de données (Usage: make db-restore BACKUP=filename.sql ENV=dev|local|prod|preprod)
	@if [ -z "$(BACKUP)" ]; then \
		echo "Usage: make db-restore BACKUP=filename.sql ENV=dev|local|prod|preprod"; \
		exit 1; \
	fi
	@if [ "$(ENV)" = "prod" ]; then \
		docker compose -f $(COMPOSE_FILE) exec -T db psql -U aides-simplifiees -d aides-simplifiees-prod < $(BACKUP); \
	elif [ "$(ENV)" = "preprod" ]; then \
		docker compose -f $(COMPOSE_FILE) exec -T db psql -U aides-simplifiees -d aides-simplifiees-preprod < $(BACKUP); \
	elif [ "$(ENV)" = "local" ]; then \
		docker compose -f $(COMPOSE_FILE) exec -T db psql -U aides-simplifiees -d aides-simplifiees-local < $(BACKUP); \
	else \
		docker compose -f $(COMPOSE_FILE) exec -T db psql -U aides-simplifiees -d aides-simplifiees < $(BACKUP); \
	fi

# Surveillance
health: ## Vérifie l'état de santé des services (Usage: make health ENV=dev|local|prod|preprod)
	@echo "Vérification de l'état des services:"
	@docker compose -f $(COMPOSE_FILE) ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

health-check: ## Lance le script de vérification complète (Usage: make health-check ENV=dev|local|prod|preprod)
	@chmod +x ./scripts/health-check.sh
	@./scripts/health-check.sh

# Image building targets
build-leximpact-image: ## Build l'image leximpact-territoires localement
	@echo "Construction de l'image leximpact-territoires (local)..."
	@if [ ! -d "../territoires" ]; then \
		echo "Clonage du repository territoires..."; \
		git clone https://git.leximpact.dev/leximpact/territoires/territoires.git ../territoires; \
	fi
	@docker build -f dockerfiles/leximpact.Dockerfile -t ghcr.io/betagouv/leximpact-territoires:latest ../territoires
	@echo "Image construite localement: ghcr.io/betagouv/leximpact-territoires:latest"

build-push-leximpact-image: ## Build et publie l'image leximpact-territoires (multi-platform)
	@echo "Building multi-platform leximpact-territoires image..."
	@echo "Target: ghcr.io/betagouv/leximpact-territoires:latest"
	@echo "Platforms: linux/amd64, linux/arm64"
	@echo ""
	@if [ ! -d "../territoires" ]; then \
		echo "Clonage du repository territoires..."; \
		git clone https://git.leximpact.dev/leximpact/territoires/territoires.git ../territoires; \
	fi
	@docker buildx build \
		--platform linux/amd64,linux/arm64 \
		-f dockerfiles/leximpact.Dockerfile \
		-t ghcr.io/betagouv/leximpact-territoires:latest \
		--push \
		../territoires
	@echo ""
	@echo "Build and push completed successfully!"
	@echo "Image available at: ghcr.io/betagouv/leximpact-territoires:latest"

# Backward compatibility
push-leximpact-image: build-push-leximpact-image ## Alias pour build-push-leximpact-image