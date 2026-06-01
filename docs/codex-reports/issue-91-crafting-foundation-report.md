# Issue #91 - Crafting foundation

## 1. Résumé de limplémentation

Ajout d'une premiere fondation serveur `gr-crafting` pour nanos world.

Le lot ajoute :

- une migration SQL `crafting_recipes` / `crafting_recipe_ingredients`
- un seed MVP de recettes relancable
- un package serveur-only `gr-crafting`
- un repository SQL minimal
- un service de craft avec verification des ingredients
- un retrait d'ingredients via `GRInventoryBridge`
- un ajout du resultat via `GRInventoryBridge`
- une recompense d'XP competence optionnelle via `GRSkillsBridge`
- une commande debug `/craft <recipe_key>`
- l'allowlist `gr-chat` pour laisser passer `/craft`

## 2. Agents consultés

- software-architect
- database-engineer
- backend-lua
- nanos-world-lua-agent
- security-reviewer
- qa-tester

## 3. Fichiers créés

- `database/migrations/010_crafting_foundation.sql`
- `database/seeds/crafting_mvp_seed.sql`
- `server/Packages/gr-crafting/Package.toml`
- `server/Packages/gr-crafting/Shared/Index.lua`
- `server/Packages/gr-crafting/Server/CraftingRepository.lua`
- `server/Packages/gr-crafting/Server/CraftingService.lua`
- `server/Packages/gr-crafting/Server/Index.lua`

## 4. Fichiers modifiés

- `server/Packages/gr-chat/Server/Index.lua`

## 5. Fichiers explicitement non modifiés

- `server/Packages/gr-database/`
- `server/Packages/gr-characters/`
- `server/Packages/gr-factions/`
- `server/Packages/gr-inventory/`
- `server/Packages/gr-progression/`
- `server/Packages/gr-skills/`
- anciennes migrations existantes
- vrai `Config.toml`

## 6. Migration SQL ajoutée

Fichier :

- `database/migrations/010_crafting_foundation.sql`

Tables ajoutees :

- `crafting_recipes`
- `crafting_recipe_ingredients`

Points notables :

- aucune destruction de donnees
- aucun `DROP`
- contraintes de quantites positives
- FK vers `items(key)` et `crafting_recipes(key)`
- index sur `is_active` et `recipe_key`
- contrainte unique `(recipe_key, item_key)` pour relancer le seed proprement

## 7. Seed ajouté

Fichier :

- `database/seeds/crafting_mvp_seed.sql`

Recettes MVP seedées :

- `medkit_basic`
- `ration_pack`
- `comlink`

Ingredients MVP seedes :

- `medkit_basic` -> `credit_chip x2`
- `ration_pack` -> `credit_chip x1`
- `comlink` -> `credit_chip x3`

Note importante :

- les exemples `scrap`, `electronic_component` et `repair_kit_basic` n'existent pas dans les items actuellement seedes du worktree
- le seed MVP utilise donc uniquement des `item_key` reels deja presents dans `database/seeds/inventory_mvp_seed.sql`

## 8. Détails techniques Lua

Package cree :

- `server/Packages/gr-crafting/`

Structure :

- `Shared/Index.lua`
- `Server/CraftingRepository.lua`
- `Server/CraftingService.lua`
- `Server/Index.lua`

Bridge exporte :

- `GRCraftingBridge.GetService()`
- `GRCraftingBridge.ListActiveRecipes(callback)`
- `GRCraftingBridge.CraftItem(character_id, recipe_key, callback)`
- `GRCraftingBridge.CraftItemForActiveCharacter(player_or_platform_id, recipe_key, callback)`

Le service :

- valide `character_id`
- valide `recipe_key`
- charge la recette
- charge les ingredients
- verifie l'inventaire agrege
- retire les ingredients sequentiellement
- ajoute le resultat
- tente un rollback best-effort si l'ajout final echoue
- ajoute une XP competence si configuree et si `GRSkillsBridge` est disponible

## 9. Intégration avec gr-inventory

Le craft n'accede pas directement aux tables inventaire.

APIs utilisees :

- `GRInventoryBridge.ListInventory(character_id, callback)`
- `GRInventoryBridge.RemoveItem(character_id, item_key, quantity, callback)`
- `GRInventoryBridge.AddItem(character_id, item_key, quantity, metadata_json, callback)`

Comportement :

- verification des ingredients avant tout retrait
- retrait serveur-only des ingredients
- ajout serveur-only du resultat
- rollback best-effort des ingredients si l'ajout du resultat echoue

## 10. Intégration avec gr-skills

APIs utilisees :

- verification optionnelle de prerequis futur via `GRSkillsBridge.ListSkills(...)`
- recompense XP via `GRSkillsBridge.AddSkillXp(...)`

Comportement :

- si `craft_xp_skill_key` ou `craft_xp_amount` est absent ou nul, aucune XP competence n'est donnee
- si `GRSkillsBridge` est indisponible, le craft reussit quand meme et le skip est loggue

Recettes MVP et XP competence :

- `medkit_basic` -> `medicine x20`
- `ration_pack` -> `survival x10`
- `comlink` -> `crafting x15`

## 11. Commandes debug ajoutées

Commande ajoutee :

```txt
/craft <recipe_key>
```

Protection :

- commande reservee au debug/dev
- controlee via `custom_settings`

Settings attendus dans le vrai `Config.toml` local :

```toml
gr_crafting_debug_commands_enabled = false
gr_crafting_debug_allowed_platform_ids = ""
```

Messages joueur principaux :

- `Craft reussi : <item_key> x<quantity>`
- `Craft impossible : ingredients insuffisants`
- `Craft impossible : recette inconnue`
- `Craft impossible : personnage actif introuvable`

## 12. Tests effectués

Tests locaux reels effectues :

1. verification branche :
   - `git status -sb`
   - `git branch --show-current`
2. lecture docs/agents locaux
3. lecture des packages `gr-inventory`, `gr-skills`, `gr-chat`
4. application migration PostgreSQL :
   - `database/migrations/010_crafting_foundation.sql`
5. application seed PostgreSQL :
   - `database/seeds/crafting_mvp_seed.sql`
6. verification SQL :
   - `SELECT ... FROM public.crafting_recipes`
   - `SELECT ... FROM public.crafting_recipe_ingredients`
   - `SELECT key FROM public.items`
7. verification git :
   - `git status -sb`
   - `git status --short --untracked-files=all`
   - `git diff --name-only`
   - `git diff --check`

Tests non effectues localement :

- runtime nanos world en jeu
- verification manuelle de `/craft` en session playtest
- verification manuelle de non-regression chat/gameplay en jeu

## 13. Tests à faire manuellement en runtime nanos world

Preparation packages :

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

Config locale de debug a prevoir dans le vrai `Config.toml` :

```toml
gr_inventory_debug_commands_enabled = "true"
gr_inventory_debug_allowed_platform_ids = "platform_id_1"
gr_crafting_debug_commands_enabled = "true"
gr_crafting_debug_allowed_platform_ids = "platform_id_1"
```

Scenario craft adapte aux recettes reelles seedes :

```txt
/inv
/giveitem credit_chip 5
/craft medkit_basic
/inv
/skills
/xpinfo
/profile
```

Autres scenarios :

```txt
/giveitem credit_chip 1
/craft ration_pack
/inv
```

```txt
/giveitem credit_chip 3
/craft comlink
/inv
/skills
```

Non-regression :

```txt
/quests
/profile
/whoami
/f test
/me test
/do test
/inv
/xpinfo
/skills
/classes
```

## 14. Requêtes PostgreSQL de vérification

Migration :

```powershell
Get-Content -Raw ".\database\migrations\010_crafting_foundation.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
```

Seed :

```powershell
Get-Content -Raw ".\database\seeds\crafting_mvp_seed.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
```

Recettes :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, category, result_item_key, result_quantity, required_skill_key, required_skill_level, craft_xp_skill_key, craft_xp_amount, is_active FROM public.crafting_recipes ORDER BY key;"
```

Ingredients :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT recipe_key, item_key, quantity FROM public.crafting_recipe_ingredients ORDER BY recipe_key, item_key;"
```

Items existants utiles au craft MVP :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key FROM public.items ORDER BY key;"
```

## 15. Résultat git status -sb

```text
## feature/issue-91-crafting-foundation
 M server/Packages/gr-chat/Server/Index.lua
?? database/migrations/010_crafting_foundation.sql
?? database/seeds/crafting_mvp_seed.sql
?? server/Packages/gr-crafting/
```

## 16. Risques restants

- pas de transaction cross-package ; le rollback inventaire reste best-effort
- les recettes MVP utilisent `credit_chip` comme ressource temporaire car aucun composant de craft plus pertinent n'est seed dans le worktree
- le runtime nanos world n'a pas ete lance ici
- aucun compilateur `lua` ou `luac` n'a ete detecte localement pour une validation syntaxique automatisee
- `gr-skills` est declare en dependance package, mais le service garde quand meme un comportement tolerent si le bridge runtime est indisponible

## 17. Message de commit recommandé

```text
feat(crafting): add crafting foundation
```
