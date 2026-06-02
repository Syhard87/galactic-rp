# Issue #94 - Crafting diagnostics

## 1. Résumé de limplémentation

Ajout de deux commandes de diagnostic dans `gr-crafting` :

- `/craftrecipes`
- `/craftinfo <recipe_key>`

Le lot reste strictement en lecture seule. Il n'ajoute ni mécanique de craft, ni migration, ni seed. Les commandes permettent de vérifier rapidement les recettes actives, les ingrédients, la station requise, la compétence requise, l'XP de craft et le comportement qualité introduit en #93.

## 2. Agents consultés

- software-architect
- backend-lua
- database-engineer
- security-reviewer
- nanos-world-lua-agent
- qa-tester

## 3. Fichiers créés

- `docs/codex-reports/issue-94-crafting-diagnostics-report.md`

## 4. Fichiers modifiés

- `server/Packages/gr-crafting/Server/CraftingRepository.lua`
- `server/Packages/gr-crafting/Server/CraftingService.lua`
- `server/Packages/gr-crafting/Server/Index.lua`
- `server/Packages/gr-chat/Server/Index.lua`

## 5. Fichiers explicitement non modifiés

- `database/migrations/`
- `database/seeds/`
- `server/Packages/gr-database/`
- `server/Packages/gr-characters/`
- `server/Packages/gr-factions/`
- `server/Packages/gr-progression/`
- `server/Packages/gr-skills/`
- `server/Packages/gr-quests/`
- vrai `Config.toml`

## 6. Migration SQL ajoutée ou non nécessaire

Aucune migration n'etait necessaire.

Les commandes s'appuient sur les tables deja en place :

- `crafting_recipes`
- `crafting_recipe_ingredients`
- `crafting_stations`

## 7. Seed modifié ou non nécessaire

Aucun seed n'etait necessaire.

Les commandes de diagnostic lisent uniquement les recettes et stations deja seedées par #91 et #92.

## 8. Détails techniques Lua

### Repository

`server/Packages/gr-crafting/Server/CraftingRepository.lua`

Ajout de :

- `GetRecipeDetails(recipe_key, callback)`

Cette methode compose :

- `GetRecipeByKey(...)`
- `ListIngredientsByRecipeKey(...)`

Le repository reste limite a l'acces DB et ne formate pas le texte des commandes.

### Service

`server/Packages/gr-crafting/Server/CraftingService.lua`

Ajout de :

- `ListCraftRecipes(callback)`
- `GetCraftRecipeInfo(recipe_key, callback)`

Ajout d'un helper :

- `build_quality_diagnostic_text(recipe_row)`

Le service retourne une structure lisible :

- `recipe`
- `ingredients`
- `quality_hint`

Il distingue proprement :

- `recipe-not-found`
- `recipe-inactive`

### Index

`server/Packages/gr-crafting/Server/Index.lua`

Ajout de l'export bridge :

- `GRCraftingBridge.ListCraftRecipes(callback)`
- `GRCraftingBridge.GetCraftRecipeInfo(recipe_key, callback)`

Ajout des commandes chat debug :

- `/craftrecipes`
- `/craftinfo <recipe_key>`

## 9. Commande /craftrecipes

Objectif :

- lister les recettes actives pour un test rapide en jeu

Format actuel :

```txt
Recettes de craft actives :
- ration_pack -> ration_pack x1 station=aucune skill=aucune
- medkit_basic -> medkit_basic x1 station=medical_workbench skill=aucune
```

Comportement :

- si aucune recette active : `Aucune recette de craft active.`
- la commande ne modifie ni inventaire, ni XP, ni DB
- elle reutilise le garde debug/dev existant de `gr-crafting`

## 10. Commande /craftinfo

Objectif :

- afficher le detail d'une recette

Format actuel :

```txt
Recette : medkit_basic
Resultat : medkit_basic x1
Station : medical_workbench
Competence requise : aucune
XP craft : medicine +20
Ingredients :
- credit_chip x2
Qualite : common / improved
```

Comportement :

- si `recipe_key` absent : `Usage : /craftinfo <recipe_key>`
- si la recette est inconnue : `Recette inconnue : <recipe_key>`
- si la recette est inactive : `Recette inactive : <recipe_key>`
- pour une recette avec competence requise, la ligne qualite devient :
  - `common / improved / rare / prototype selon competence`

## 11. Impact gr-chat

`server/Packages/gr-chat/Server/Index.lua`

Ajout minimal a l'allowlist externe :

- `craftrecipes = true`
- `craftinfo = true`

Aucune autre commande n'a ete modifiee.

## 12. Tests effectués

Controles locaux reels effectues :

1. verification branche et prerequis :
   - `git status -sb`
   - `git branch --show-current`
   - `Test-Path "server\Packages\gr-crafting"`
   - `Test-Path "docs\codex-reports\issue-93-crafted-item-quality-report.md"`
2. lecture des fichiers cibles et des rapports #91/#92/#93
3. lecture docs nanos world :
   - `packages-guide.md`
   - `chat.mdx`
4. verification PostgreSQL :
   - `crafting_recipes`
   - `crafting_recipe_ingredients`
   - `crafting_stations`
5. verification git finale :
   - `git status -sb`
   - `git status --short --untracked-files=all`
   - `git diff --name-only`
   - `git diff --check`

Tests non effectues ici :

- runtime nanos world en jeu
- verification manuelle des messages `/craftrecipes` et `/craftinfo`

## 13. Tests à faire manuellement en runtime nanos world

En jeu, apres selection du personnage :

```txt
/craftrecipes
/craftinfo ration_pack
/craftinfo medkit_basic
/craftstations
/inv
/craft ration_pack
/inv
/skills
/xpinfo
/profile
/quests
```

Attendus :

- `/craftrecipes` liste les recettes actives
- `/craftinfo <recipe_key>` affiche le detail de la recette
- `/craftstations` fonctionne toujours
- `/craft <recipe_key>` fonctionne toujours
- `/inv`, `/skills`, `/xpinfo`, `/profile`, `/quests` ne regressent pas
- pas de `chat-command-not-supported`

## 14. Requêtes PostgreSQL de vérification

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, result_item_key, result_quantity, required_skill_key, required_skill_level, craft_xp_skill_key, craft_xp_amount, station_key, is_active FROM crafting_recipes ORDER BY key;"
```

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT recipe_key, item_key, quantity FROM crafting_recipe_ingredients ORDER BY recipe_key, item_key;"
```

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, name, station_type, position_x, position_y, position_z, radius, is_active FROM crafting_stations ORDER BY key;"
```

## 15. Résultat git status -sb

```text
## feature/issue-94-crafting-diagnostics
 M server/Packages/gr-chat/Server/Index.lua
 M server/Packages/gr-crafting/Server/CraftingRepository.lua
 M server/Packages/gr-crafting/Server/CraftingService.lua
 M server/Packages/gr-crafting/Server/Index.lua
```

## 16. Risques restants

- le runtime nanos world n'a pas ete lance ici, donc la validation finale des sorties chat reste manuelle
- les recettes seedees actuelles n'ont pas de `required_skill_key`, donc `skill=aucune` et une qualite diagnostique plafonnee a `common / improved` sur les recettes MVP actuelles
- `git diff --check` ne remonte que des warnings CRLF Windows

## 17. Message de commit recommandé

```text
feat(crafting): add crafting diagnostics
```
