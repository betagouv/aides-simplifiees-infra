# Architecture Overview - Aides Simplifiées Infrastructure

## 1. Architecture générale du système

### Environnements et ports

| Service | Développement (dev) | Local (local) | Préproduction (preprod) | Production (prod) |
|---------|---------------------|---------------|-------------------------|-------------------|
| main-app | 8080:3333 <br/>(Debug: 9229) | 8080:3333 <br/>(Debug: 9229) | 8081:3333 | 8080:3333 |
| openfisca | 5001:5000 <br/>(Debug: 5678) | 5001:5000 <br/>(Debug: 5678) | Interne | Interne |
| leximpact | 3000:3000 | 3000:3000 | Interne | Interne |
| database | 5432:5432 | 5432:5432 | Interne | Interne |

**Différences clés:**
- **dev**: `NODE_ENV=development`, hot-reload, debugger actif.
- **local**: `NODE_ENV=production`, setup iso-prod mais avec sources montées.
- **preprod**: Serveur, `APP_ENV=staging`, base de données séparée, port 8081.
- **prod**: Serveur, `APP_ENV=production`, base de données séparée, port 8080.

### Diagramme d'architecture

```mermaid
graph TB
    subgraph "Infrastructure Docker"
        subgraph "Application Layer"
            main["main-app<br/>AdonisJS<br/>Port 8080 (Prod)/8081 (Preprod)<br/>Serves Static Files"]
            openfisca[openfisca<br/>Calculateur<br/>Port 5001:5000 dev/local<br/>Internal only prod]
            leximpact[leximpact<br/>LexImpact Territoires<br/>Port 3000 dev/local<br/>Internal only prod]
        end
        
        subgraph "Data Layer"
            db[(PostgreSQL 17<br/>Database<br/>Port 5432 dev/local<br/>Internal only prod)]
            migrate[db-migrate<br/>Migrations<br/>Run Once]
            seed[db-seed<br/>Seeds<br/>Run Once]
            backup[db-backup<br/>Sauvegarde Auto<br/>Quotidienne]
        end
        
        subgraph "Storage"
            dbdata[dbdata<br/>Volume PostgreSQL]
            logs[app_logs<br/>Volume Logs]
            backups[./database/backups<br/>Fichiers de sauvegarde]
        end
    end
    
    subgraph "External"
        users[👥 Utilisateurs]
        extproxy[External Load Balancer<br/>Reverse Proxy<br/>SSL Termination]
    end
    
    users -->|HTTPS/HTTP| extproxy
    extproxy -->|HTTP 8080| main
    users -.->|Direct API dev only| openfisca
    main -->|Internal API| openfisca
    main -->|Internal API| leximpact
    main -->|SQL| db
    migrate -->|Migrations| db
    migrate -->|Dependencies| seed
    seed -->|Seeds| db
    backup -->|pg_dump| db
    
    db -.->|Persist| dbdata
    main -.->|Logs| logs
    backup -.->|Backup Files| backups
```

## 2. Flux de données et communication

```mermaid
sequenceDiagram
    participant U as Utilisateur
    participant P as External Proxy/LB
    participant M as main-app
    participant O as openfisca
    participant D as PostgreSQL
    participant L as LexImpact
    participant Mig as db-migrate
    participant Seed as db-seed
    
    Note over U,Seed: Démarrage et flux typique
    
    %% Initialization phase
    Note over Mig,D: Phase d'initialisation
    Mig->>D: Run migrations
    Seed->>D: Populate initial data
    
    %% Normal operation
    Note over U,L: Flux typique d'une demande d'aide
    
    U->>P: HTTPS Request
    
    P->>M: HTTP Port 8080:3333
    
    alt Calcul d'aide
        M->>O: POST http://openfisca:5000/calculate
        O-->>M: Résultat calcul OpenFisca
    end
    
    alt Autocomplétion communes
        M->>L: GET http://leximpact:3000/...
        L-->>M: Données communes LexImpact
    end
    
    M->>D: SQL Query
    D-->>M: Données utilisateur/aide
    
    M-->>P: Response (HTML/JSON/Assets)
    P-->>U: HTTPS Response
```