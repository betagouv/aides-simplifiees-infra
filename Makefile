SHELL := /bin/bash
export COMPOSE_DOCKER_CLI_BUILD=1
export DOCKER_BUILDKIT=1

# Default environment
ENV ?= dev

# Docker compose files
COMPOSE_FILE := docker-compose.yml
ifeq ($(ENV),prod)
    COMPOSE_FILE := docker-compose.yml -f docker-compose.prod.yml
else
    # For dev environment, include override file if it exists
    ifneq (,$(wildcard docker-compose.override.yml))
        COMPOSE_FILE := docker-compose.yml -f docker-compose.override.yml
    endif
endif

.PHONY: help bootstrap build up logs down clean pull restart status ssl nginx-setup setup

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

ssl: ## Génère les certificats SSL pour le développement
	@echo "Génération des certificats SSL..."
	@./nginx/generate-ssl.sh

nginx-setup: ssl ## Configure nginx avec les certificats SSL
	@echo "Configuration de nginx terminée"

setup: bootstrap nginx-setup ## Configuration complète (bootstrap + nginx + SSL)

build: bootstrap ## Build tous les services
	docker compose --progress=plain -f $(COMPOSE_FILE) build

up: bootstrap ## Démarre tous les services
	docker compose -f $(COMPOSE_FILE) up -d

logs: ## Affiche les logs de tous les services
	docker compose -f $(COMPOSE_FILE) logs -f --tail=100

down: ## Arrête tous les services
	docker compose -f $(COMPOSE_FILE) down

clean: ## Arrête et supprime tout (volumes inclus)
	docker compose -f $(COMPOSE_FILE) down -v --remove-orphans
	docker system prune -f

pull: ## Met à jour les images de base
	docker compose -f $(COMPOSE_FILE) pull

restart: down up ## Redémarre tous les services

status: ## Affiche le statut des services
	docker compose -f $(COMPOSE_FILE) ps

# Environnements spécifiques
dev: ## Démarre l'environnement de développement
	@$(MAKE) setup build ENV=dev
	@docker compose -f docker-compose.yml -f docker-compose.override.yml up -d

prod: ## Démarre l'environnement de production
	@$(MAKE) setup build ENV=prod
	@docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d

# Commandes de développement
dev-setup: ## Clone les dépôts pour le développement local
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

# Commandes spécifiques aux services
nginx-logs: ## Logs de nginx uniquement
	docker compose -f $(COMPOSE_FILE) logs -f nginx

nginx-reload: ## Recharge la configuration nginx
	docker compose -f $(COMPOSE_FILE) exec nginx nginx -s reload

nginx-test: ## Test la configuration nginx
	docker compose -f $(COMPOSE_FILE) exec nginx nginx -t

main-app-logs: ## Logs du main-app uniquement
	docker compose -f $(COMPOSE_FILE) logs -f main-app

openfisca-logs: ## Logs du openfisca uniquement
	docker compose -f $(COMPOSE_FILE) logs -f openfisca

db-logs: ## Logs de la base de données
	docker compose -f $(COMPOSE_FILE) logs -f db

db-shell: ## Shell dans la base de données
	docker compose -f $(COMPOSE_FILE) exec db psql -U aides-simplifiees -d aides-simplifiees

# Database management commands
db-setup: ## Configure la base de données (migrations et seeders)
	@echo "Configuration de la base de données..."
	@echo "Les migrations et seeders s'exécutent automatiquement via les services db-migrate et db-seed"

db-migrate: ## Execute les migrations uniquement
	@echo "Exécution des migrations..."
	@docker compose -f $(COMPOSE_FILE) run --rm db-migrate

db-seed: ## Execute les seeders uniquement
	@echo "Exécution des seeders..."
	@docker compose -f $(COMPOSE_FILE) run --rm db-seed

db-reset: ## Remet à zéro la base de données (ATTENTION: supprime toutes les données)
	@echo "Ceci va supprimer toutes les données de la base. Êtes-vous sûr? (y/N)"
	@read -r response && [ "$$response" = "y" ] || exit 1
	@echo "Suppression de la base de données..."
	@docker compose -f $(COMPOSE_FILE) down
	@docker volume rm aides-simplifiees-infra_dbdata || true
	@docker compose -f $(COMPOSE_FILE) up -d db
	@sleep 5
	@make db-setup

main-app-shell: ## Shell dans le container main-app
	docker compose -f $(COMPOSE_FILE) exec main-app sh

openfisca-shell: ## Shell dans le container openfisca
	docker compose -f $(COMPOSE_FILE) exec openfisca bash

# Base de données
db-backup: ## Sauvegarde de la base de données
	@echo "Création d'une sauvegarde..."
	docker compose -f $(COMPOSE_FILE) exec db pg_dump -U aides-simplifiees aides-simplifiees > backup_$$(date +%Y%m%d_%H%M%S).sql

db-restore: ## Restaure la base de données (Usage: make db-restore BACKUP=filename.sql)
	@if [ -z "$(BACKUP)" ]; then \
		echo "Usage: make db-restore BACKUP=filename.sql"; \
		exit 1; \
	fi
	docker compose -f $(COMPOSE_FILE) exec -T db psql -U aides-simplifiees -d aides-simplifiees < $(BACKUP)

# Surveillance
health: ## Vérifie l'état de santé des services
	@echo "Vérification de l'état des services:"
	@docker compose -f $(COMPOSE_FILE) ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

health-check: ## Lance le script de vérification complète
	@./scripts/health-check.sh