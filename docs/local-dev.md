# Developpement local

## Objectif

Le bootstrap local couvre maintenant deux besoins distincts :

- l'infrastructure locale PostgreSQL et pgAdmin
- le premier smoke test local du serveur nanos world pour le Character MVP `#41`

Ce document ne pretend pas que le Character MVP est deja jouable complet.

## Perimetre actuel

Le depot prepare actuellement :

- PostgreSQL via Docker Compose
- pgAdmin pour l'inspection manuelle
- les packages nanos world `gr-core`, `gr-database` et `gr-characters`
- la documentation du premier smoke test de chargement serveur

Le depot ne fournit pas encore :

- le binaire nanos world serveur
- un `server/Config.example.toml` versionne
- une UI complete de creation ou de selection
- un spawn final complet
- un Datapad complet

## Prerequis

- Docker Desktop ou moteur Docker compatible Compose
- Git
- une installation locale nanos world serveur hors depot
- acces au dossier local du serveur nanos world contenant le futur `Config.toml`

## Variables d'environnement

Le depot ne versionne pas de `.env` reel. Un exemple est fourni dans `docker/.env.example`.

Pour lancer la stack locale sans creer de secret reel dans le depot, le script de demarrage et les commandes manuelles utilisent directement ce fichier d'exemple avec `--env-file`.

## Demarrage recommande de PostgreSQL

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

## Commandes manuelles Docker Compose

Lancer la stack :

```powershell
docker compose --env-file docker/.env.example -f docker/docker-compose.yml up -d
```

Verifier l'etat :

```powershell
docker compose --env-file docker/.env.example -f docker/docker-compose.yml ps
```

Suivre les logs PostgreSQL :

```powershell
docker compose --env-file docker/.env.example -f docker/docker-compose.yml logs -f postgres
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

## Verifier pgAdmin

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

Verification pgAdmin recommandee :

1. ouvrir `http://localhost:5050`
2. se connecter avec les credentials de `docker/.env.example`
3. declarer un serveur PostgreSQL avec l'hote `postgres`
4. verifier que la base `galactic_rp` est joignable
5. verifier la presence des tables `players`, `characters` et `character_skills` apres migration

## Migration initiale

Le depot contient `database/migrations/001_init.sql`.

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

## Etat des packages Character MVP

Les packages reels prepares pour le smoke test `#41` sont :

1. `gr-core`
2. `gr-database`
3. `gr-characters`

Ordre de chargement attendu pour le smoke test :

1. `gr-core`
2. `gr-database`
3. `gr-characters`

Justification :

- `gr-core` ne declare pas de dependance runtime, mais peut etre charge en premier comme socle de conventions
- `gr-database` doit etre charge avant `gr-characters`
- `gr-characters` declare `packages_requirements = ["gr-database"]`

## Configuration locale du serveur nanos world

Verification faite dans le depot :

- aucun `server/Config.example.toml` n'est versionne
- `server/Config.toml` est ignore par Git
- le cahier des charges cible mentionne `server/Config.example.toml`, mais ce fichier n'existe pas encore dans l'etat reel du depot

Rappel de la documentation officielle nanos world :

- `Config.toml` est genere automatiquement au premier lancement du serveur
- les packages scripts doivent etre listes dans l'entree `packages`
- les packages doivent etre presents dans le dossier `Packages/` du serveur nanos world local

Consequence pratique :

- ne pas creer un faux chemin local dans le depot
- preparer le `Config.toml` dans le vrai dossier du serveur nanos world local
- adapter manuellement le chemin local de votre installation nanos world

TODO local obligatoire :

- confirmer ou documenter dans votre environnement comment les sources du repo `server/Packages/` sont copiees, synchronisees ou liees vers le dossier reel `Packages/` du serveur nanos world

### Configuration minimale recommandee

Dans le dossier reel du serveur nanos world local :

1. lancer une premiere fois le serveur si `Config.toml` n'existe pas encore
2. fermer le serveur
3. editer le `Config.toml` genere automatiquement
4. verifier que les packages suivants sont listes dans cet ordre :

```toml
packages = [
  "gr-core",
  "gr-database",
  "gr-characters",
]
```

Si votre serveur attend aussi une map explicite et qu'aucune map de projet n'est encore disponible, utiliser une map integree documentee par nanos world, par exemple :

```toml
map = "default-blank-map"
```

ou conserver votre map locale deja validee si elle ne bloque pas le smoke test.

### Custom settings PostgreSQL pour `gr-database`

Le package `gr-database` lit sa configuration locale via `Server.GetCustomSettings()` a partir de la section `[custom_settings]` du vrai `Config.toml` du serveur nanos world local.

Exemple local minimal :

```toml
[custom_settings]
gr_database_host = "127.0.0.1"
gr_database_port = "5432"
gr_database_name = "galactic_rp"
gr_database_user = "galactic"
gr_database_password = "change-me-local-only"
gr_database_auto_connect = "false"
```

Notes importantes :

- ne pas versionner ce `Config.toml` local
- ne pas reutiliser un vrai secret dans le depot
- adapter `gr_database_name`, `gr_database_user` et `gr_database_password` a votre instance locale
- `docker/.env.example` reste la reference locale pour les valeurs Docker par defaut
- le log de `gr-database` ne doit jamais afficher `gr_database_password`, uniquement `has_password=true|false`

## Procedure smoke test local Character MVP `#41`

### 1. Preparer la base locale

1. lancer Docker Compose
2. verifier que `postgres` est `healthy`
3. appliquer `database/migrations/001_init.sql`
4. appliquer `database/seeds/dev_seed.sql` seulement si vous voulez un joueur et un personnage de dev pre-remplis

### 2. Preparer le serveur nanos world local

1. verifier que le dossier local `Packages/` du serveur contient `gr-core`, `gr-database` et `gr-characters`
2. verifier que le `Config.toml` local liste `gr-core`, `gr-database`, `gr-characters`
3. verifier que `gr-characters` reste apres `gr-database`
4. ne pas ajouter de package gameplay supplementaire pour ce premier smoke test si ce n'est pas necessaire

### 3. Lancer le serveur nanos world local

Depuis le dossier local du serveur nanos world :

- utiliser le binaire Windows `NanosWorldServer.exe` ou le script correspondant a votre environnement local documente par nanos world
- observer la console serveur des le demarrage

Le depot ne versionne pas encore de script de lancement nanos world. Le chemin exact d'installation reste donc un TODO local a documenter dans votre environnement.

## Logs attendus au demarrage

Les logs suivants sont attendus ou probables au demarrage si les packages sont bien charges :

- `[gr_core][server] Core package loaded.`
- `[gr_database][config] Loaded source=custom-settings|safe-defaults engine=postgresql host=127.0.0.1 port=5432 database=galactic_rp user=galactic has_password=true|false auto_connect=false`
- `[gr_database][server] Database package loaded.`
- `[gr_database][server] Sensitive database logic remains server-only.`
- `[gr_database][server] No automatic PostgreSQL connection is attempted at package load.`
- `[gr_characters][server] Characters package loaded.`
- `[gr_characters][server] Character authority, validation and persistence stay server-side.`
- `[gr_characters][server] Player row loading is prepared server-side through players.platform_id lookup.`
- `[gr_characters][server] Character creation is prepared server-side with strict field validation and safe defaults.`
- `[gr_characters][server] Character selection is prepared server-side with ownership validation and transient active character state.`
- `[gr_characters][server] Active character position saving is prepared server-side with a slow timer, DB anti-spam and spawn fallback resolution.`

Le smoke test doit echouer si vous voyez des erreurs du type :

- package introuvable
- `Package.Require` en erreur
- dependance `gr-database` manquante
- crash Lua fatal au chargement

## Logs attendus a la connexion d'un joueur

Quand un joueur rejoint :

- le serveur ne doit pas crash
- des logs `player-service` et `player-repository` doivent apparaitre
- le chargement par `players.platform_id` doit etre observable

Exemples de logs attendus :

- `[gr_characters][player-service] Resolving players row for platform_id=... username=...`
- `[gr_characters][player-repository] Looking up players.platform_id=...`

Puis un des cas suivants :

- ligne `players` trouvee
- ligne `players` absente mais sans crash serveur

## Verifications en jeu

Le premier smoke test local doit verifier au minimum :

- un joueur peut rejoindre le serveur
- `gr-core`, `gr-database` et `gr-characters` se chargent sans erreur critique
- aucun crash Lua n'apparait au demarrage
- aucune erreur de dependance package n'apparait
- les logs de player loading sont visibles
- si le joueur n'a pas de ligne `players`, le serveur reste proprement dans un etat prepare sans gameplay force
- si le joueur n'a pas de personnage, le serveur ne crash pas et ne tente pas un spawn final non implemente

## Limites connues du smoke test

Ce smoke test ne valide pas encore :

- une UI complete de creation de personnage
- une UI complete de selection de personnage
- un spawn final complet
- un Datapad complet
- une vraie boucle RP jouable

Interpretation correcte :

- on valide ici le chargement des packages et la stabilite minimale du socle Character MVP
- on ne valide pas encore une experience de jeu Character complete

## Troubleshooting

### Package non charge

Verifier :

- que le package existe bien dans le vrai dossier `Packages/` du serveur nanos world local
- que le nom de dossier correspond exactement au nom reference dans `Config.toml`
- que `packages = [...]` contient bien `gr-core`, `gr-database`, `gr-characters`

### Erreur `Package.Require`

Verifier :

- qu'aucun fichier requis dans `Server/` n'est manquant
- que les noms de fichiers respectent la casse attendue
- que le package s'est bien charge avant toute tentative de require dynamique

### Erreur de dependance `gr-database`

Verifier :

- que `gr-database` est present dans le dossier `Packages/`
- que `gr-database` est liste avant `gr-characters` dans le smoke test local
- que `server/Packages/gr-characters/Package.toml` declare toujours `packages_requirements = ["gr-database"]`

### PostgreSQL non disponible

Verifier :

- `docker compose ... ps`
- l'etat `healthy` du service `postgres`
- le port expose `5432`
- les logs `docker compose ... logs postgres`

Rappel :

- `gr-database` n'ouvre pas automatiquement la connexion au chargement du package
- l'indisponibilite PostgreSQL doit donc surtout apparaitre quand une lecture ou une connexion est effectivement tentee

### Fichier `Config.toml` manquant

Rappel officiel nanos world :

- `Config.toml` est genere au premier lancement du serveur

Action recommandee :

1. lancer une premiere fois le serveur local
2. laisser nanos world generer `Config.toml`
3. arreter le serveur
4. editer le fichier genere localement

Ne pas versionner ce fichier local dans le depot.

### API nanos world incertaine

Si un comportement de chargement, d'evenement ou de config ne peut pas etre confirme par la documentation officielle :

- ne pas inventer d'API
- ne pas inventer de chemin de lancement
- documenter le point incertain avec un TODO local explicite
- verifier en jeu avant toute modification Lua de comportement

## Limites documentaires

Ce document decrit uniquement le premier smoke test local `#41` a partir de l'etat reel du depot.

Il ne doit pas etre lu comme :

- un guide de mise en production
- une garantie que le Character MVP est complet
- une preuve que tous les flux creation, selection et spawn sont deja finis
