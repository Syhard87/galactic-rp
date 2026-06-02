# Issue #92 - Crafting stations MVP

## 1. Résumé de limplémentation

Ajout d'une premiere fondation MVP des stations de craft dans `gr-crafting`.

Le lot ajoute :

- une migration SQL `crafting_stations`
- une colonne `crafting_recipes.station_key` si absente
- un seed relancable de stations MVP
- une mise a jour du seed craft pour imposer certaines stations
- une verification serveur de proximite avant craft
- une commande debug `/craftstations`
- l'allowlist `gr-chat` pour laisser passer `/craftstations`

Le craft sans station continue de fonctionner comme en #91.

## 2. Agents consultés

- software-architect
- database-engineer
- backend-lua
- nanos-world-lua-agent
- security-reviewer
- qa-tester

## 3. Fichiers créés

- `database/migrations/011_crafting_stations.sql`
- `database/seeds/crafting_stations_mvp_seed.sql`
- `docs/codex-reports/issue-92-crafting-stations-report.md`

## 4. Fichiers modifiés

- `database/seeds/crafting_mvp_seed.sql`
- `server/Packages/gr-crafting/Server/CraftingRepository.lua`
- `server/Packages/gr-crafting/Server/CraftingService.lua`
- `server/Packages/gr-crafting/Server/Index.lua`
- `server/Packages/gr-chat/Server/Index.lua`

## 5. Fichiers explicitement non modifiés

- `database/migrations/010_crafting_foundation.sql`
- `server/Packages/gr-database/`
- `server/Packages/gr-characters/`
- `server/Packages/gr-factions/`
- `server/Packages/gr-inventory/`
- `server/Packages/gr-skills/`
- vrai `Config.toml`

## 6. Migration SQL ajoutée

Fichier :

- `database/migrations/011_crafting_stations.sql`

Ajouts :

- table `crafting_stations`
- index `idx_crafting_stations_station_type`
- colonne `crafting_recipes.station_key` si absente

Structure de `crafting_stations` :

- `key`
- `name`
- `station_type`
- `position_x`
- `position_y`
- `position_z`
- `radius`
- `is_active`
- `created_at`
- `updated_at`

Garanties :

- migration idempotente
- aucun `DROP`
- aucune destruction de donnees

## 7. Seed ajouté

Fichier :

- `database/seeds/crafting_stations_mvp_seed.sql`

Stations MVP seedées :

- `medical_workbench`
- `engineering_bench`
- `field_camp`

Coordonnees de test retenues :

- `medical_workbench` -> `0,0,100`
- `engineering_bench` -> `500,0,100`
- `field_camp` -> `-500,0,100`

Rayons :

- `medical_workbench` -> `300`
- `engineering_bench` -> `300`
- `field_camp` -> `450`

Ces positions suivent les conventions de test deja visibles dans les spawns MVP `gr-factions`.

## 8. Seed craft modifié

Fichier :

- `database/seeds/crafting_mvp_seed.sql`

Recettes apres mise a jour :

- `medkit_basic` -> station requise `medical_workbench`
- `comlink` -> station requise `engineering_bench`
- `ration_pack` -> aucune station requise

La recette sans station permet de verifier le fallback #91.

## 9. Détails techniques Lua

### Repository

`server/Packages/gr-crafting/Server/CraftingRepository.lua`

Ajouts :

- `station_key` charge sur les recettes
- `GetStationByKey(station_key, callback)`
- `ListActiveStations(callback)`

Le repository reste limite a l'acces DB.

### Service

`server/Packages/gr-crafting/Server/CraftingService.lua`

Ajouts :

- `ListActiveStations(callback)`
- verification de station avant verification des ingredients et avant retrait inventaire

Flux station :

1. charger la recette
2. lire `recipe.station_key`
3. si absent -> continuer comme avant
4. si present -> charger la station
5. refuser si station absente
6. refuser si station inactive
7. retrouver le joueur cote serveur depuis le personnage actif
8. lire la position du personnage controle via `GetControlledCharacter():GetLocation()`
9. calculer la distance
10. refuser hors rayon
11. continuer le craft si le joueur est dans le rayon

Codes d'erreur utilises :

- `required-station-not-found`
- `required-station-inactive`
- `required-station-too-far`
- `station-player-location-unavailable`

## 10. Commandes debug ajoutées

Commande deja existante :

- `/craft <recipe_key>`

Commande ajoutee :

- `/craftstations`

Comportement de `/craftstations` :

- liste les stations actives
- affiche `key`, `station_type`, `position_x`, `position_y`, `position_z`, `radius`

Protection :

- meme garde debug/dev que `/craft`
- depend de `gr_crafting_debug_commands_enabled`
- depend de `gr_crafting_debug_allowed_platform_ids`

Allowlist `gr-chat` ajoutee :

- `craftstations = true`

## 11. Tests effectués

Tests locaux reels effectues :

1. verification branche :
   - `git status -sb`
   - `git branch --show-current`
   - `Test-Path "server\Packages\gr-crafting"`
2. lecture docs projet, docs nanos world et packages cibles
3. application migration :
   - `database/migrations/011_crafting_stations.sql`
4. application seed stations :
   - `database/seeds/crafting_stations_mvp_seed.sql`
5. reapplication seed craft :
   - `database/seeds/crafting_mvp_seed.sql`
6. verification PostgreSQL :
   - `SELECT ... FROM crafting_stations`
   - `SELECT ... FROM crafting_recipes`
   - `SELECT column_name ... FROM information_schema.columns WHERE table_name = 'crafting_recipes'`
7. verification git :
   - `git status -sb`
   - `git status --short --untracked-files=all`
   - `git diff --name-only`
   - `git diff --check`

Tests non effectues ici :

- runtime nanos world en jeu
- verification manuelle des distances en map

## 12. Tests à faire manuellement en runtime nanos world

Copie packages :

```powershell
$Repo = "C:\Users\Syhar\OneDrive - educ-valadon-limoges.fr\Bureau\galactic-rp\galactic-rp"
$ServerRoot = "C:\Program Files (x86)\Steam\steamapps\common\nanos-world-playtest\Server"

robocopy "$Repo\server\Packages" "$ServerRoot\Packages" /E /FFT /R:2 /W:2 /NP /XF ".gitkeep"
```

Lancement :

```powershell
cd "C:\Program Files (x86)\Steam\steamapps\common\nanos-world-playtest\Server"
.\NanosWorldServer.exe --playtest
```

Tests :

```txt
/craftstations
/inv
/giveitem credit_chip 5
/craft ration_pack
/craft medkit_basic
/craft comlink
/skills
/xpinfo
/profile
/quests
```

Attendus :

- `/craftstations` liste les 3 stations actives
- `ration_pack` reste craftable sans station
- `medkit_basic` refuse si le joueur est trop loin de `medical_workbench`
- `comlink` refuse si le joueur est trop loin de `engineering_bench`
- une fois dans le rayon, le craft reussit
- pas de `chat-command-not-supported`

## 13. Requêtes PostgreSQL de vérification

Migration :

```powershell
Get-Content -Raw ".\database\migrations\011_crafting_stations.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
```

Seeds :

```powershell
Get-Content -Raw ".\database\seeds\crafting_stations_mvp_seed.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
Get-Content -Raw ".\database\seeds\crafting_mvp_seed.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
```

Verifications :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, name, station_type, position_x, position_y, position_z, radius, is_active FROM crafting_stations ORDER BY key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, result_item_key, station_key, is_active FROM crafting_recipes ORDER BY key;"
```

## 14. Résultat git status -sb

```text
## feature/issue-92-crafting-stations
 M database/seeds/crafting_mvp_seed.sql
 M server/Packages/gr-chat/Server/Index.lua
 M server/Packages/gr-crafting/Server/CraftingRepository.lua
 M server/Packages/gr-crafting/Server/CraftingService.lua
 M server/Packages/gr-crafting/Server/Index.lua
?? database/migrations/011_crafting_stations.sql
?? database/seeds/crafting_stations_mvp_seed.sql
```

## 15. Risques restants

- le runtime nanos world n'a pas ete lance ici, donc la validation finale de proximite reste manuelle
- la verification de station repose sur le personnage controle et sa position serveur; si aucun personnage n'est possede au runtime, le craft refusera les recettes avec station
- `field_camp` est seedee mais n'est pas encore utilisee par une recette MVP
- `git diff --check` ne remonte que des warnings CRLF Windows, pas d'erreur de contenu

## 16. Message de commit recommandé

```text
feat(crafting): add crafting stations
```
