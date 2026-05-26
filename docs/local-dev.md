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
gr_database_auto_connect = "true"
gr_characters_dev_tools_enabled = "false"
gr_characters_dev_platform_id = "local-dev-platform-id"
```

Notes importantes :

- ne pas versionner ce `Config.toml` local
- ne pas reutiliser un vrai secret dans le depot
- adapter `gr_database_name`, `gr_database_user` et `gr_database_password` a votre instance locale
- `docker/.env.example` reste la reference locale pour les valeurs Docker par defaut
- le log de `gr-database` ne doit jamais afficher `gr_database_password`, uniquement `has_password=true|false`
- mettre `gr_database_auto_connect = "false"` si vous voulez charger `gr-database` sans tentative de connexion automatique
- mettre `gr_characters_dev_tools_enabled = "true"` uniquement pour le dev/local/test
- `gr_characters_dev_platform_id` permet de valider le flux `player -> characters -> active character` avec un `platform_id` controle, sans pretendre finaliser le vrai flux joueur UI/gameplay

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

## Procedure QA runtime locale complete issue `#49`

Cette procedure consolide les validations runtime locales preparees par les issues `#45`, `#46`, `#47` et `#48`.

Objectif :

- verifier la lecture des `custom_settings`
- verifier la connexion PostgreSQL reelle
- verifier le smoke test `SELECT 1`
- verifier le flux `player -> player DB -> characters -> active character`
- verifier qu'aucun password n'apparait jamais dans les logs

Important :

- cette procedure ne commit jamais le vrai `Config.toml`
- cette procedure ne prouve pas une mise en production
- cette procedure ne valide pas encore le spawn final, `player:Possess(...)`, l'inventaire, les factions ou le gameplay RPG

### Checklist QA

- [ ] Docker Desktop ou moteur Compose operationnel
- [ ] `docker/.env.example` verifie
- [ ] PostgreSQL demarre et passe `healthy`
- [ ] migration `database/migrations/001_init.sql` appliquee
- [ ] vrai `Config.toml` local prepare sans secret reel committe
- [ ] packages `gr-core`, `gr-database`, `gr-characters` listes dans le vrai serveur nanos world local
- [ ] `gr-database` lit les `custom_settings`
- [ ] `gr-database` confirme `has_password=true` et `auto_connect=true`
- [ ] connexion PostgreSQL reelle OK
- [ ] `SELECT 1` OK
- [ ] joueur local connecte
- [ ] `platform_id` resolu cote serveur
- [ ] `player DB` charge ou cree
- [ ] `characters count` visible dans les logs
- [ ] `active character` selectionne si possible
- [ ] aucun password PostgreSQL dans les logs

### 1. Demarrer PostgreSQL

Commande principale :

```powershell
docker compose --env-file docker/.env.example -f docker/docker-compose.yml up -d
```

Verification recommandee :

```powershell
docker compose --env-file docker/.env.example -f docker/docker-compose.yml ps
```

Attendu :

- le service `postgres` doit etre `healthy`
- le service `pgadmin` doit etre demarre

### 2. Appliquer la migration initiale

Commande :

```powershell
docker compose --env-file docker/.env.example -f docker/docker-compose.yml exec -T postgres psql -U galactic -d galactic_rp -f /workspace/database/migrations/001_init.sql
```

Verification recommandee :

- pas d'erreur SQL fatale
- les tables `players`, `characters` et `character_skills` existent

### 3. Preparer le vrai `Config.toml` local

Le depot ne versionne aucun `server/Config.example.toml` et le vrai `Config.toml` du serveur nanos world local doit rester hors Git.

Exemple minimal de `custom_settings` pour le smoke test runtime :

```toml
[custom_settings]
gr_database_host = "127.0.0.1"
gr_database_port = "5432"
gr_database_name = "galactic_rp"
gr_database_user = "galactic"
gr_database_password = "change-me-local-only"
gr_database_auto_connect = "true"
gr_characters_dev_tools_enabled = "true"
```

Notes :

- `gr_database_password` ci-dessus est un exemple local uniquement
- ne jamais commiter de vrai secret
- mettre `gr_characters_dev_tools_enabled = "false"` pour le cas nominal sans fallback dev
- remettre `gr_characters_dev_tools_enabled = "true"` seulement pour tester le fallback local de creation de personnage de test

### 4. Demarrer le serveur nanos world local

Verifier dans le vrai `Config.toml` local :

```toml
packages = [
  "gr-core",
  "gr-database",
  "gr-characters",
]
```

Puis lancer le vrai serveur nanos world local avec votre binaire ou script local documente.

Attendu :

- pas de crash Lua fatal au demarrage
- pas d'erreur `Package.Require`
- pas d'erreur de dependance `gr-database`

### 5. Verifier les logs de demarrage

Logs `gr-database` attendus ou proches :

- `[gr_database][config] Loaded source=custom-settings|safe-defaults engine=postgresql host=127.0.0.1 port=5432 dbname=galactic_rp user=galactic has_password=true|false auto_connect=true|false`
- `[gr_database][server] PostgreSQL auto_connect=true, attempting connection...`
- `[gr_database][server] PostgreSQL connection successful.`
- `[gr_database][server] PostgreSQL smoke test SELECT 1 OK. Result=1.`

Logs `gr-characters` attendus ou proches :

- `[gr_characters][server] Characters package loaded.`
- `[gr_characters][server] Player-ready flow is server-only and uses players.platform_id lookup plus in-memory active character selection.`
- `[gr_characters][server][dev] Character dev tool disabled.` ou `Character dev tool enabled.`

Verification securite obligatoire :

- le mot de passe PostgreSQL ne doit jamais apparaitre
- seul `has_password=true` ou `has_password=false` est acceptable

### 6. Connecter un joueur localement

Une fois le serveur pret :

1. connecter un joueur localement
2. attendre l'evenement serveur `Player.Ready`
3. observer les logs `gr_characters`

Logs attendus ou proches :

- `[gr_characters][server] Player connected.`
- `[gr_characters][server] Resolved platform_id=...`
- `[gr_characters][server] Player DB loaded id=...` ou `[gr_characters][server] Player DB created id=...`
- `[gr_characters][server] Characters found count=...`

### 7. Verifier le flux Character MVP

Cas A : le joueur a deja au moins un personnage

Attendu :

- le premier personnage retourne par la DB est selectionne
- le tri doit etre stable cote SQL
- les logs montrent :

```text
[gr_characters][server] Active character selected id=...
[gr_characters][server] Active character stored for player.
```

Cas B : le joueur n'a aucun personnage et le mode dev est desactive

Attendu :

```text
[gr_characters][server] Characters found count=0.
[gr_characters][server] No active character selected. Character creation UI will be required later.
```

Cas C : le joueur n'a aucun personnage et le mode dev est active explicitement

Attendu :

```text
[gr_characters][server][dev] Character dev fallback enabled for platform_id=...
[gr_characters][server][dev] Test character created id=...
[gr_characters][server][dev] Active character selected id=...
[gr_characters][server][dev] Active character stored in memory.
```

### 8. Cas d'erreur a verifier

Docker ou PostgreSQL bloques :

- relancer `docker compose ... ps`
- suivre `docker compose --env-file docker/.env.example -f docker/docker-compose.yml logs -f postgres`
- verifier que `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_PASSWORD` et `POSTGRES_PORT` correspondent bien a `docker/.env.example`

Connexion DB en echec :

- verifier `gr_database_auto_connect = "true"`
- verifier les `custom_settings` `gr_database_*`
- verifier que PostgreSQL ecoute bien sur `127.0.0.1:5432`
- verifier que la migration a bien ete appliquee

Serveur nanos world bloque :

- verifier que le vrai dossier `Packages/` contient bien `gr-core`, `gr-database`, `gr-characters`
- verifier que `Config.toml` liste bien ces packages
- verifier que le serveur a bien genere puis recharge le vrai `Config.toml`
- verifier les erreurs `Package.Require`, dependances ou crash Lua dans la console serveur

Flux joueur bloque :

- verifier que l'evenement `Player.Ready` se produit bien dans votre build locale
- verifier qu'un `platform_id` est resolu
- verifier les logs `player-service`, `player-repository` et `selection-service`
- si aucun personnage n'existe et que le mode dev est desactive, le log d'absence de personnage est le resultat attendu

### 9. Limites connues du smoke test runtime

Ce smoke test ne valide toujours pas :

- le spawn final du personnage gameplay
- `player:Possess(...)`
- une UI complete de creation de personnage
- une UI complete de selection
- le Datapad
- l'inventaire, les factions, la progression ou le gameplay RPG complet

Lecture correcte du resultat :

- si les logs DB et Character attendus apparaissent sans crash ni fuite de password, le socle runtime local du Character MVP est valide
- cela ne signifie pas que l'experience joueur complete est terminee

## Logs attendus au demarrage

Les logs suivants sont attendus ou probables au demarrage si les packages sont bien charges :

- `[gr_core][server] Core package loaded.`
- `[gr_database][config] Loaded source=custom-settings|safe-defaults engine=postgresql host=127.0.0.1 port=5432 dbname=galactic_rp user=galactic has_password=true|false auto_connect=true|false`
- `[gr_database][server] PostgreSQL auto_connect=true, attempting connection...`
- `[gr_database][server] PostgreSQL connection successful.`
- `[gr_database][server] PostgreSQL smoke test SELECT 1 OK. Result=1.`
- `[gr_database][server] Database package loaded.`
- `[gr_database][server] Sensitive database logic remains server-only.`
- `[gr_database][server] PostgreSQL runtime access stays server-only.`
- `[gr_characters][server] Characters package loaded.`
- `[gr_characters][server] Character authority, validation and persistence stay server-side.`
- `[gr_characters][server] Player-ready flow is server-only and uses players.platform_id lookup plus in-memory active character selection.`
- `[gr_characters][server] Character creation is prepared server-side with strict field validation and safe defaults.`
- `[gr_characters][server] Character selection is prepared server-side with ownership validation and transient active character state.`
- `[gr_characters][server] Active character position saving is prepared server-side with a slow timer, DB anti-spam and spawn fallback resolution.`
- `[gr_characters][server][dev] Character dev tool disabled.`

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

- `[gr_characters][server] Player connected.`
- `[gr_characters][server] Resolved platform_id=...`
- `[gr_characters][server] Player DB loaded id=...` ou `[gr_characters][server] Player DB created id=...`
- `[gr_characters][server] Characters found count=...`
- `[gr_characters][player-service] Resolving players row for platform_id=... username=...`
- `[gr_characters][player-repository] Looking up players.platform_id=...`

Puis un des cas suivants :

- ligne `players` trouvee puis personnage actif selectionne
- ligne `players` creee puis personnage actif selectionne
- aucun personnage, avec log indiquant qu'une future UI de creation sera necessaire

## Verifications en jeu

Le premier smoke test local doit verifier au minimum :

- un joueur peut rejoindre le serveur
- `gr-core`, `gr-database` et `gr-characters` se chargent sans erreur critique
- aucun crash Lua n'apparait au demarrage
- aucune erreur de dependance package n'apparait
- les logs de player loading sont visibles
- si le joueur n'a pas encore de ligne `players`, le serveur peut la creer sans crash ni exposition client
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

- si `gr_database_auto_connect = "true"`, `gr-database` tente une connexion PostgreSQL au chargement du package
- si `gr_database_auto_connect = "false"`, aucune connexion automatique n'est tentee
- en cas d'indisponibilite PostgreSQL, le serveur doit continuer sans crash avec un log d'erreur propre

## Procedure de validation PostgreSQL issue `#46`

1. lancer Docker Compose avec `docker/.env.example`
2. verifier que `postgres` est `healthy`
3. appliquer `database/migrations/001_init.sql`
4. verifier les valeurs locales de `docker/.env.example`
5. dans le vrai `Config.toml` local du serveur nanos world, renseigner les `custom_settings` `gr_database_*`
6. mettre `gr_database_auto_connect = "true"`
7. lancer le serveur nanos world local
8. verifier la presence des logs `gr_database` de connexion et de `SELECT 1`
9. verifier que le mot de passe n'apparait jamais dans les logs
10. tester ensuite `gr_database_auto_connect = "false"` pour confirmer qu'aucune connexion automatique n'est tentee

Logs complements attendus pour `#46` :

- `[gr_database][server] PostgreSQL auto_connect=true, attempting connection...`
- `[gr_database][server] PostgreSQL connection successful.`
- `[gr_database][server] PostgreSQL smoke test SELECT 1 OK. Result=1.`
- `[gr_database][server] PostgreSQL optional players smoke test OK. First row id=... platform_id=... username=...`

Ou, si PostgreSQL est indisponible :

- `[gr_database][server] PostgreSQL connection failed: database-connection-failed`
- `[gr_database][server] Server continues without database connection.`

## Procedure de validation Character dev tool issue `#47`

1. lancer Docker Compose avec `docker/.env.example`
2. verifier que `postgres` est `healthy`
3. appliquer `database/migrations/001_init.sql`
4. dans le vrai `Config.toml` local du serveur nanos world, renseigner les `custom_settings` `gr_database_*`
5. ajouter `gr_characters_dev_tools_enabled = "true"`
6. lancer le serveur nanos world local
7. connecter un joueur localement
8. verifier les logs `gr_characters][server][dev]`
9. verifier que le fallback dev ne se declenche que si le joueur charge n'a aucun personnage
10. verifier que le personnage de test minimal est cree seulement dans ce cas et jamais hors mode dev
11. verifier qu'un personnage existant est selectionne et stocke en memoire serveur
12. remettre `gr_characters_dev_tools_enabled = "false"` pour confirmer que le fallback ne se lance plus

Logs complements attendus pour `#47` :

- `[gr_characters][server][dev] Character dev tool enabled.`
- `[gr_characters][server][dev] Character dev fallback enabled for platform_id=...`
- `[gr_characters][server][dev] Characters found count=...`
- `[gr_characters][server][dev] Test character created id=...`
- `[gr_characters][server][dev] Active character selected id=...`
- `[gr_characters][server][dev] Active character stored in memory.`

## Procedure de validation premier flux joueur issue `#48`

1. lancer PostgreSQL localement avec `docker/.env.example`
2. verifier que `postgres` est `healthy`
3. appliquer `database/migrations/001_init.sql`
4. verifier le vrai `Config.toml` local non committe et mettre `gr_database_auto_connect = "true"`
5. laisser `gr_characters_dev_tools_enabled = "false"` pour le cas nominal, puis le remettre a `"true"` seulement pour tester le fallback dev
6. lancer le serveur nanos world local
7. connecter un joueur localement
8. verifier les logs `gr_characters` :
   - `Player connected.`
   - `Resolved platform_id=...`
   - `Player DB loaded id=...` ou `Player DB created id=...`
   - `Characters found count=...`
   - `Active character selected id=...` puis `Active character stored for player.` si un personnage existe
9. tester le cas d'un joueur sans personnage :
   - verifier `Characters found count=0`
   - verifier `No active character selected. Character creation UI will be required later.`
10. tester le cas d'un joueur avec au moins un personnage :
   - verifier la selection automatique du premier personnage retourne par la DB
11. retester le cas sans personnage avec `gr_characters_dev_tools_enabled = "true"` pour confirmer le fallback local de creation de personnage de test
12. verifier qu'aucun mot de passe PostgreSQL n'apparait dans les logs

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
