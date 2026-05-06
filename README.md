# Galactic RP

Galactic RP est un serveur RP/RPG galactique persistant construit comme un produit logiciel sérieux sur nanos world. Le projet vise un monde social persistant, modulaire et durable, avec logique serveur autoritative, WebUI dédiées, persistance PostgreSQL et outillage de collaboration propre.

## Vision

Le projet cherche à construire un RPG social persistant dans un univers space opera original, avec une base technique maintenable avant d'ouvrir les systèmes gameplay plus ambitieux. Ce dépôt couvre le bootstrap MVP Tech : architecture, documentation, base SQL minimale, infrastructure locale et CI.

## Stack prévue

- Gameplay : Lua sur nanos world
- UI : React + TypeScript + Vite
- Styling : Tailwind CSS
- Base de données : PostgreSQL
- Infrastructure locale : Docker Compose
- CI/CD : GitHub Actions
- Documentation : Markdown

## Arborescence de démarrage

```txt
server/Packages/
ui/hud/
ui/datapad/
database/migrations/
database/seeds/
docker/
tools/
.github/ISSUE_TEMPLATE/
.github/workflows/
```

## Lancement local Docker

Démarrer PostgreSQL et pgAdmin avec le fichier d'exemple versionné :

```powershell
docker compose --env-file docker/.env.example -f docker/docker-compose.yml up -d
```

Vérifier les services :

```powershell
docker compose --env-file docker/.env.example -f docker/docker-compose.yml ps
```

Arrêter la stack :

```powershell
docker compose --env-file docker/.env.example -f docker/docker-compose.yml down
```

## Documentation

- Spécification principale : [docs/cahier-des-charges.md](docs/cahier-des-charges.md)
- Architecture : [docs/architecture.md](docs/architecture.md)
- Backlog technique : [docs/backlog.md](docs/backlog.md)
- Développement local : [docs/local-dev.md](docs/local-dev.md)
- CI/CD : [docs/ci-cd.md](docs/ci-cd.md)
