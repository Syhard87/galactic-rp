# Developpement local

## Objectif

Le bootstrap actuel prepare uniquement l'infrastructure locale autour de PostgreSQL et pgAdmin. Aucun gameplay ni package nanos world n'est encore initialise dans ce lot.

## Prerequis

- Docker Desktop ou moteur Docker compatible Compose
- Git

## Variables d'environnement

Le depot ne versionne pas de `.env` reel. Un exemple est fourni dans `docker/.env.example`.

Pour lancer la stack locale sans creer de secret reel dans le depot, le script de demarrage et les commandes manuelles utilisent directement ce fichier d'exemple avec `--env-file`.

## Demarrage recommande

Depuis la racine du repo :

```powershell
.\tools\start-dev.ps1
```

Le script :

- verifie que Docker et Docker Compose sont disponibles
- verifie la presence de `docker/docker-compose.yml`
- verifie la presence de `docker/.env.example`
- lance la stack locale avec `docker compose up -d`
- affiche l'etat des services
- rappelle les URLs et identifiants locaux issus de `docker/.env.example`

## Commandes manuelles

Lancer la stack :

```powershell
docker compose --env-file docker/.env.example -f docker/docker-compose.yml up -d
```

Verifier l'etat :

```powershell
docker compose --env-file docker/.env.example -f docker/docker-compose.yml ps
```

Arreter la stack :

```powershell
docker compose --env-file docker/.env.example -f docker/docker-compose.yml down
```

Reinitialiser aussi les volumes locaux :

```powershell
docker compose --env-file docker/.env.example -f docker/docker-compose.yml down -v
```

## Services exposes

- PostgreSQL : `localhost:5432`
- pgAdmin : `http://localhost:5050`

## Acces pgAdmin

Les identifiants d'exemple sont definis dans `docker/.env.example`. Ils sont reserves au developpement local et doivent etre remplaces hors depot pour tout autre environnement.

Valeurs locales par defaut :

- pgAdmin email : `admin@local.dev`
- pgAdmin password : `change-me-local-only`
- PostgreSQL database : `galactic_rp`
- PostgreSQL user : `galactic`
- PostgreSQL password : `change-me-local-only`

Connexion serveur pgAdmin recommandee :

- Hostname : `postgres`
- Port : `5432`
- Username : valeur `POSTGRES_USER`
- Password : valeur `POSTGRES_PASSWORD`
- Database : valeur `POSTGRES_DB`

## Migration initiale

Le depot contient `database/migrations/001_init.sql`. Cette migration cree :

- `players`
- `characters`
- `character_skills`

Execution manuelle possible :

```powershell
docker compose --env-file docker/.env.example -f docker/docker-compose.yml exec -T postgres psql -U galactic -d galactic_rp -f /workspace/database/migrations/001_init.sql
```

## Seed de developpement

Le depot contient `database/seeds/dev_seed.sql`. Ce seed ajoute un joueur fictif de test, un personnage fictif associe et quelques competences de test coherentes avec le schema actuel.

Le seed est concu pour etre relance autant que possible sans creer de doublons :

- le joueur est upsert via `platform_id`
- le personnage n'est insere que s'il n'existe pas deja pour ce joueur et ce nom
- les competences sont upsert via la contrainte unique `uq_character_skills_character_skill`

Execution manuelle avec Docker :

```powershell
docker exec -it galactic-rp-postgres psql -U galactic -d galactic_rp -f /workspace/database/seeds/dev_seed.sql
```

## Limites actuelles

- pas de build UI
- pas de packages nanos world initialises
