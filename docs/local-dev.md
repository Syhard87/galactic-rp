# Développement local

## Objectif

Le bootstrap actuel prépare uniquement l'infrastructure locale autour de PostgreSQL et pgAdmin. Aucun gameplay ni package nanos world n'est encore initialisé dans ce lot.

## Prérequis

- Docker Desktop ou moteur Docker compatible Compose
- Git

## Variables d'environnement

Le dépôt ne versionne pas de `.env` réel. Un exemple est fourni dans `docker/.env.example`.

Pour lancer la stack locale sans créer de secret réel dans le dépôt, utiliser directement ce fichier d'exemple avec `--env-file`.

## Commandes

Depuis la racine du repo :

```powershell
docker compose --env-file docker/.env.example -f docker/docker-compose.yml up -d
```

Vérifier l'état :

```powershell
docker compose --env-file docker/.env.example -f docker/docker-compose.yml ps
```

Arrêter la stack :

```powershell
docker compose --env-file docker/.env.example -f docker/docker-compose.yml down
```

Réinitialiser aussi les volumes locaux :

```powershell
docker compose --env-file docker/.env.example -f docker/docker-compose.yml down -v
```

## Services exposés

- PostgreSQL : `localhost:5432`
- pgAdmin : `http://localhost:5050`

## Accès pgAdmin

Les identifiants d'exemple sont définis dans `docker/.env.example`. Ils sont réservés au développement local et doivent être remplacés hors dépôt pour tout autre environnement.

Connexion serveur pgAdmin recommandée :

- Hostname : `postgres`
- Port : `5432`
- Username : valeur `POSTGRES_USER`
- Password : valeur `POSTGRES_PASSWORD`
- Database : valeur `POSTGRES_DB`

## Migration initiale

Le dépôt contient `database/migrations/001_init.sql`. Cette migration crée :

- `players`
- `characters`
- `character_skills`

Exécution manuelle possible :

```powershell
docker compose --env-file docker/.env.example -f docker/docker-compose.yml exec -T postgres psql -U galactic -d galactic_rp -f /workspace/database/migrations/001_init.sql
```

## Limites actuelles

- pas de seed versionné
- pas de script d'automatisation PowerShell
- pas de build UI
- pas de packages nanos world initialisés
