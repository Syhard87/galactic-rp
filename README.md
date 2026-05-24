# Galactic RP

Galactic RP est un serveur RP/RPG galactique persistant construit comme un produit logiciel serieux sur nanos world. Le projet vise un monde social persistant, modulaire et durable, avec logique serveur autoritative, WebUI dediees, persistance PostgreSQL et outillage de collaboration propre.

## Vision

Le projet cherche a construire un RPG social persistant dans un univers space opera original, avec une base technique maintenable avant d'ouvrir les systemes gameplay plus ambitieux. Ce depot couvre le bootstrap MVP Tech : architecture, documentation, base SQL minimale, infrastructure locale et CI.

## Stack prevue

- Gameplay : Lua sur nanos world
- UI : React + TypeScript + Vite
- Styling : Tailwind CSS
- Base de donnees : PostgreSQL
- Infrastructure locale : Docker Compose
- CI/CD : GitHub Actions
- Documentation : Markdown

## Arborescence de demarrage

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

## Packages nanos world actuels

Les noms de dossiers/packages nanos world actuellement utilises par le depot sont :

- `gr-core`
- `gr-database`
- `gr-characters`

Les prefxes de logs internes peuvent conserver les formes historiques `[gr_core]`, `[gr_database]` et `[gr_characters]`.

## Lancement local Docker

Demarrer PostgreSQL et pgAdmin avec le fichier d'exemple versionne :

```powershell
docker compose --env-file docker/.env.example -f docker/docker-compose.yml up -d
```

Verifier les services :

```powershell
docker compose --env-file docker/.env.example -f docker/docker-compose.yml ps
```

Arreter la stack :

```powershell
docker compose --env-file docker/.env.example -f docker/docker-compose.yml down
```

## Documentation

- Specification principale : [docs/cahier-des-charges.md](docs/cahier-des-charges.md)
- Architecture : [docs/architecture.md](docs/architecture.md)
- MVP Character : [docs/character-mvp.md](docs/character-mvp.md)
- Backlog technique : [docs/backlog.md](docs/backlog.md)
- Developpement local : [docs/local-dev.md](docs/local-dev.md)
- CI/CD : [docs/ci-cd.md](docs/ci-cd.md)
- Checklist de validation MVP Tech : [docs/mvp-tech-validation-checklist.md](docs/mvp-tech-validation-checklist.md)
