# Issue #93 - Crafted item quality

## 1. Résumé de limplémentation

Ajout d'une premiere gestion MVP de la qualite des objets craftes dans `gr-crafting`.

Le lot ajoute :

- un calcul serveur de qualite au moment du craft
- les qualites MVP `common`, `improved`, `rare`, `prototype`
- une transmission des metadata de craft a `gr-inventory`
- une persistance de la qualite dans `inventory_items.metadata_json`
- un affichage simple de `quality=<...>` dans `/inv` quand la qualite est presente
- une mise a jour du message de succes `/craft`

## 2. Agents consultés

- software-architect
- database-engineer
- backend-lua
- nanos-world-lua-agent
- security-reviewer
- qa-tester

## 3. Fichiers créés

- `docs/codex-reports/issue-93-crafted-item-quality-report.md`

## 4. Fichiers modifiés

- `server/Packages/gr-crafting/Server/CraftingService.lua`
- `server/Packages/gr-crafting/Server/Index.lua`
- `server/Packages/gr-inventory/Server/Index.lua`

## 5. Fichiers explicitement non modifiés

- `server/Packages/gr-database/`
- `server/Packages/gr-characters/`
- `server/Packages/gr-factions/`
- `server/Packages/gr-progression/`
- `server/Packages/gr-skills/`
- `server/Packages/gr-quests/`
- `server/Packages/gr-inventory/Server/InventoryRepository.lua`
- `server/Packages/gr-inventory/Server/InventoryService.lua`
- `database/migrations/`
- `database/seeds/`
- vrai `Config.toml`

## 6. Migration SQL ajoutée ou non nécessaire

Aucune migration n'etait necessaire.

Constat :

- `inventory_items.metadata_json` existe deja dans `database/migrations/003_inventory_foundation.sql`
- `InventoryRepository:AddItem(...)` accepte deja `metadata_json`
- `GRInventoryBridge.AddItem(...)` transporte deja ce parametre jusqu'au repository

## 7. Seed modifié ou non nécessaire

Aucun seed n'etait necessaire.

Le comportement de qualite est calcule au runtime cote serveur et ne depend d'aucune nouvelle donnee seedee.

## 8. Détails techniques Lua

### `gr-crafting`

`server/Packages/gr-crafting/Server/CraftingService.lua`

Ajouts principaux :

- `ALLOWED_CRAFT_QUALITIES`
- `escape_json_string(...)`
- `build_crafted_item_metadata_json(recipe_key, quality)`
- `compute_craft_quality(recipe_row, resolved_skill_level)`

Le service :

1. valide recette, station et ingredients comme avant
2. resout si possible le niveau de competence utile au craft
3. calcule une qualite cote serveur
4. construit des metadata JSON de craft
5. appelle `GRInventoryBridge.AddItem(...)` avec ces metadata

Metadata generees :

```json
{
  "source": "crafting",
  "recipe_key": "medkit_basic",
  "quality": "improved",
  "crafted_at": "2026-..."
}
```

### `gr-inventory`

`server/Packages/gr-inventory/Server/Index.lua`

La fonction `summarize_inventory_rows(...)` a ete ajustee pour :

- detecter `quality` dans `metadata_json`
- separer les lignes par `item_key + quality`
- afficher `quality=<...>` si presente

Exemple :

```txt
- Ration alimentaire x1 quality=improved
```

## 9. Calcul de qualité

Regles MVP implementees :

- `common` par defaut
- si la recette n'a pas de competence requise : qualite maximale `improved`
- si le joueur depasse le niveau requis : chances progressives vers `improved`, `rare`, `prototype`
- `prototype` reste rare

Table de comportement :

- aucune competence requise :
  - `25% improved`
  - sinon `common`
- surplus `1-2` niveaux :
  - `30% improved`
- surplus `3-4` niveaux :
  - `12% rare`
  - `40% improved`
- surplus `5+` niveaux :
  - `5% prototype`
  - `20% rare`
  - `45% improved`

Fallback :

- si le niveau de competence n'est pas disponible pour une recette qui depend d'une competence, la qualite retombe a `common`
- le service loggue :
  - `[gr_crafting][service] Crafted item quality fallback reason=%s recipe_key=%s.`

Log nominal :

- `[gr_crafting][service] Crafted item quality computed character_id=%s recipe_key=%s quality=%s.`

## 10. Intégration avec gr-inventory

Integration utilisee :

- `GRInventoryBridge.AddItem(character_id, item_key, quantity, metadata_json, callback)`

Constat important :

- aucun changement de schema inventaire
- aucun changement du repository inventaire n'etait necessaire
- les objets stackables avec metadata non vides restent volontairement sur des lignes distinctes, ce qui evite de melanger plusieurs qualites dans une meme pile SQL

## 11. Intégration avec gr-skills

La qualite tente de reutiliser l'information de competence quand `recipe.required_skill_key` existe.

Comportement :

- si `GRSkillsBridge.ListSkills(...)` est disponible, le niveau est lu cote serveur
- si le bridge ou la lecture est indisponible pour une recette sans prerequis bloquant, la qualite retombe a `common`
- si une recette a un prerequis de niveau strict et que le service skills manque, le craft reste refuse comme avant

## 12. Commandes impactées

Commandes impactees :

- `/craft <recipe_key>`
- `/inv`

Nouveau message craft :

```txt
Craft reussi : medkit_basic x1 qualite=improved
```

Nouvel affichage inventaire si metadata presentes :

```txt
- Medikit basique x1 quality=improved
```

## 13. Tests effectués

Tests locaux reels effectues :

1. verification branche et prerequis :
   - `git status -sb`
   - `git branch --show-current`
   - `Test-Path "server\Packages\gr-crafting"`
   - `Test-Path "database\migrations\011_crafting_stations.sql"`
2. lecture du support metadata existant :
   - `InventoryRepository.lua`
   - `InventoryService.lua`
   - `003_inventory_foundation.sql`
3. lecture des rapports #91 et #92
4. lecture docs nanos world et docs projet utiles
5. verification PostgreSQL :
   - `inventory_items`
   - `crafting_recipes`
   - `character_skills`
6. verification git finale :
   - `git status -sb`
   - `git status --short --untracked-files=all`
   - `git diff --name-only`
   - `git diff --check`

Tests non effectues ici :

- craft runtime en jeu
- verification manuelle d'un item crafté avec metadata via `/inv`

## 14. Tests à faire manuellement en runtime nanos world

Scenario principal :

```txt
/craftstations
/inv
/giveitem credit_chip 5
/craft ration_pack
/inv
/craft medkit_basic
/craft comlink
/skills
/xpinfo
/profile
/quests
```

Attendus :

- `/craftstations` fonctionne toujours
- `ration_pack` reste craftable sans station
- les recettes avec station refusent si le joueur est trop loin
- un craft reussi affiche `qualite=<...>`
- `/inv` affiche la qualite si l'objet crafté est present
- pas de `chat-command-not-supported`

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
/craftstations
/craft ration_pack
```

## 15. Requêtes PostgreSQL de vérification

Inventaire :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, item_key, quantity, metadata_json FROM inventory_items ORDER BY character_id, item_key;"
```

Recettes :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, result_item_key, required_skill_key, required_skill_level, station_key, is_active FROM crafting_recipes ORDER BY key;"
```

Competences :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, skill_key, level, current_xp, total_xp, last_gain_at FROM character_skills ORDER BY character_id, skill_key;"
```

## 16. Résultat git status -sb

```text
## feature/issue-93-crafted-item-quality
 M server/Packages/gr-crafting/Server/CraftingService.lua
 M server/Packages/gr-crafting/Server/Index.lua
 M server/Packages/gr-inventory/Server/Index.lua
?? docs/codex-reports/issue-93-crafted-item-quality-report.md
```

## 17. Risques restants

- le runtime nanos world n'a pas ete lance ici, donc la validation finale du message `/craft` et de l'affichage `/inv` reste manuelle
- les recettes seedees actuellement n'ont pas de `required_skill_key`, donc en l'etat le calcul produit seulement `common` ou `improved`
- si `os.date` est indisponible au runtime, `crafted_at` ne sera pas ajoute; les metadata minimales `source`, `recipe_key` et `quality` restent quand meme ecrites
- `git diff --check` peut ne remonter que des warnings CRLF Windows

## 18. Message de commit recommandé

```text
feat(crafting): add crafted item quality
```
