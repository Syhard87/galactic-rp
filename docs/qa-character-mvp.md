# QA Checklist Character MVP

## Objectif

Cette checklist sert a valider l'etat actuel du MVP Character sans presenter le systeme comme entierement jouable.

Elle couvre :

- la structure des packages `gr-core`, `gr-database`, `gr-characters`
- la presence des fichiers attendus
- les garde-fous server-authoritative
- les validations deja preparees cote serveur
- les tests manuels a executer plus tard quand nanos world sera lance
- les limites actuelles du MVP

## Pre-lecture

Avant d'utiliser cette checklist, verifier les documents de reference suivants :

- `AGENTS.md`
- `docs/nanos-world-reference.md`
- `docs/architecture.md`
- `docs/character-mvp.md`

## 1. Structure des packages

### `gr-core`

- [ ] `server/Packages/gr-core/` existe
- [ ] `server/Packages/gr-core/Package.toml` existe
- [ ] `server/Packages/gr-core/Server/Index.lua` existe
- [ ] `server/Packages/gr-core/Client/Index.lua` existe
- [ ] `server/Packages/gr-core/Shared/Index.lua` existe
- [ ] `Shared/Index.lua` ne contient que des constantes et conventions communes non sensibles

### `gr-database`

- [ ] `server/Packages/gr-database/` existe
- [ ] `server/Packages/gr-database/Package.toml` existe
- [ ] `server/Packages/gr-database/Server/DatabaseConfig.lua` existe
- [ ] `server/Packages/gr-database/Server/DatabaseService.lua` existe
- [ ] `server/Packages/gr-database/Server/Index.lua` existe
- [ ] `server/Packages/gr-database/Shared/Index.lua` existe
- [ ] aucun dossier `Client/` n'est exige pour `gr-database`
- [ ] la documentation rappelle bien que `gr-database` est strictement server-side

### `gr-characters`

- [ ] `server/Packages/gr-characters/` existe
- [ ] `server/Packages/gr-characters/Package.toml` existe
- [ ] `server/Packages/gr-characters/Server/Index.lua` existe
- [ ] `server/Packages/gr-characters/Client/Index.lua` existe
- [ ] `server/Packages/gr-characters/Shared/Index.lua` existe
- [ ] `Shared/Index.lua` ne contient pas de logique autoritative

## 2. Presence des services serveur `gr-characters`

- [ ] `server/Packages/gr-characters/Server/CharacterPlayerRepository.lua` existe
- [ ] `server/Packages/gr-characters/Server/CharacterPlayerService.lua` existe
- [ ] `server/Packages/gr-characters/Server/CharacterCreationService.lua` existe
- [ ] `server/Packages/gr-characters/Server/CharacterSelectionService.lua` existe
- [ ] `server/Packages/gr-characters/Server/CharacterPositionService.lua` existe
- [ ] `server/Packages/gr-characters/Server/CharacterRepository.lua` existe
- [ ] `server/Packages/gr-characters/Server/CharacterService.lua` existe
- [ ] `server/Packages/gr-characters/Server/Index.lua` existe

## 3. Dependances de packages

- [ ] `gr-core` ne declare pas de dependance de package obligatoire
- [ ] `gr-database` ne declare pas de dependance de package obligatoire
- [ ] `gr-characters` declare `packages_requirements = ["gr-database"]`
- [ ] la documentation ne presente pas `gr-core` comme une dependance runtime deja branchee a `gr-characters`

## 4. Regles server-authoritative

- [ ] le client ne peut pas forcer `money_cash`
- [ ] le client ne peut pas forcer `money_bank`
- [ ] le client ne peut pas forcer `faction_id`
- [ ] le client ne peut pas forcer `rank_id`
- [ ] le client ne peut pas forcer `xp`
- [ ] le client ne peut pas forcer `position_x`
- [ ] le client ne peut pas forcer `position_y`
- [ ] le client ne peut pas forcer `position_z`
- [ ] le client ne peut pas forcer des permissions
- [ ] le client ne choisit pas seul le personnage actif
- [ ] la doc rappelle que le client et la WebUI ne sont pas des sources de verite gameplay

## 5. Validation du player loading

- [ ] le chargement du joueur se base sur `players.platform_id`
- [ ] `CharacterPlayerService` utilise `Player:GetAccountID()` comme identifiant stable
- [ ] `CharacterPlayerService` utilise `Player:GetName()` comme nom observe
- [ ] le cas `player-row-loaded` est documente
- [ ] le cas `player-row-missing` est documente
- [ ] le cas `player-not-loaded` est documente
- [ ] le cas `player-platform-id-unavailable` ou identifiant introuvable est documente comme bloquant

## 6. Validation de la creation de personnage

- [ ] seuls `first_name`, `last_name`, `age`, `species`, `biography` sont autorises
- [ ] les champs interdits sont rejetes explicitement
- [ ] `first_name` est obligatoire
- [ ] `last_name` est obligatoire
- [ ] `age` est entier et borne
- [ ] `species` est obligatoire
- [ ] `biography` est optionnelle et plafonnee
- [ ] les valeurs par defaut serveur documentees incluent `money_cash = 0`
- [ ] les valeurs par defaut serveur documentees incluent `money_bank = 0`
- [ ] les valeurs par defaut serveur documentees incluent `position_x = 0`
- [ ] les valeurs par defaut serveur documentees incluent `position_y = 0`
- [ ] les valeurs par defaut serveur documentees incluent `position_z = 0`
- [ ] la creation est refusee si le joueur n'est pas deja charge cote serveur

## 7. Validation de la selection de personnage

- [ ] la liste des personnages est chargee cote serveur depuis `characters.player_id`
- [ ] l'ownership est verifie cote serveur avant selection
- [ ] `character-not-owned` est un cas de refus documente
- [ ] `character-not-found` ou `character-unavailable` est un cas de refus documente
- [ ] `character-invalid` est un cas de refus documente
- [ ] le personnage actif est stocke cote serveur en memoire de session
- [ ] la doc ne pretend pas que la selection active deja le gameplay final

## 8. Validation de la sauvegarde de position

- [ ] `position_x`, `position_y`, `position_z` sont confirmes dans le schema SQL
- [ ] la sauvegarde de position est cote serveur uniquement
- [ ] la position est lue depuis le `Character` controle cote serveur
- [ ] le client ne peut pas forcer librement un `character_id`
- [ ] le client ne peut pas forcer librement une position
- [ ] un anti-spam DB est documente
- [ ] la cadence lente de sauvegarde est documentee
- [ ] le fallback `position persistante -> spawn point de map` est documente
- [ ] la doc rappelle que le spawn final complet n'est pas encore implemente

## 9. Flux MVP Character

- [ ] le flux `player -> player row -> character list` est explique
- [ ] le flux `character creation ou selection -> active character` est explique
- [ ] le flux `active character -> position saving` est explique
- [ ] la checklist reste coherente avec `docs/character-mvp.md`
- [ ] la checklist reste coherente avec `docs/architecture.md`

## 10. Tests manuels attendus quand nanos world sera lance

Ces tests ne sont pas encore executables ici, mais ils doivent etre prevus :

- [ ] le serveur nanos world demarre sans crash
- [ ] `gr-core`, `gr-database` et `gr-characters` se chargent
- [ ] les logs de chargement de package sont visibles
- [ ] un joueur rejoint sans crash Lua
- [ ] le chargement player ne casse pas si la ligne `players` existe deja
- [ ] le comportement attendu reste propre si le joueur n'a aucun personnage
- [ ] le comportement attendu reste propre si le joueur a un ou plusieurs personnages
- [ ] aucune erreur critique n'apparait lors du chargement des packages
- [ ] aucune boucle agressive de sauvegarde de position n'apparait dans les logs

## 11. Smoke test local `#41`

- [ ] Docker Compose demarre `postgres` et `pgadmin`
- [ ] le service `postgres` devient `healthy`
- [ ] pgAdmin est accessible sur `http://localhost:5050`
- [ ] la base `galactic_rp` est joignable dans pgAdmin
- [ ] les tables `players`, `characters` et `character_skills` sont visibles apres migration
- [ ] aucun `server/Config.example.toml` n'est suppose exister dans le depot
- [ ] la doc rappelle que `Config.toml` nanos world est genere au premier lancement
- [ ] le `Config.toml` local du vrai serveur nanos world liste `gr-core`, `gr-database`, `gr-characters`
- [ ] l'ordre de chargement local retenu est `gr-core -> gr-database -> gr-characters`
- [ ] le dossier local `Packages/` du serveur contient bien ces trois packages
- [ ] le log `[gr_core][server] Core package loaded.` est visible
- [ ] le log `[gr_database][server] Database package loaded.` est visible
- [ ] le log `[gr_characters][server] Characters package loaded.` est visible
- [ ] aucun message d'erreur `Package.Require` n'apparait au chargement
- [ ] aucune erreur de dependance `gr-database` manquante n'apparait
- [ ] un joueur peut rejoindre sans crash Lua
- [ ] les logs `player-service` ou `player-repository` sont visibles a la connexion
- [ ] un joueur sans ligne `players` ne provoque pas de crash
- [ ] un joueur sans personnage ne provoque pas de spawn final force

## 12. Limites actuelles

- [ ] la doc rappelle qu'il n'y a pas encore d'UI complete
- [ ] la doc rappelle qu'il n'y a pas encore de spawn final complet
- [ ] la doc rappelle qu'il n'y a pas encore de Datapad complet
- [ ] la doc rappelle qu'il n'y a pas encore de vraie boucle RP jouable
- [ ] la doc ne pretend pas que le MVP Character est entierement jouable

## 13. Verification documentaire finale

- [ ] aucun fichier inexistant n'est mentionne dans la checklist
- [ ] la checklist reste alignee avec les fichiers reels du depot
- [ ] la checklist ne modifie ni code Lua ni schema SQL
- [ ] la checklist peut etre utilisee comme support QA pour les futures validations manuelles

## Commandes utiles de verification

Exemples de commandes locales a executer :

- `git diff --check`
- `git status --short`
- `Get-ChildItem -Recurse -File server/Packages/gr-core,server/Packages/gr-database,server/Packages/gr-characters`
- `Get-ChildItem server/Packages/gr-characters/Server -File`
- `docker compose --env-file docker/.env.example -f docker/docker-compose.yml ps`
- `docker compose --env-file docker/.env.example -f docker/docker-compose.yml logs --tail 100 postgres`
- `Select-String -Path database/migrations/001_init.sql -Pattern 'position_x','position_y','position_z'`
- `rg -n --hidden --glob "!.git/*" "Config\\.example\\.toml|Config\\.toml" .`
