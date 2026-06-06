# Issue #119  Gathering requirements MVP

## 1. Résumé de limplémentation

Ajout de prérequis serveur sur `gathering_nodes` pour contrôler laccès aux récoltes selon :

- un item requis présent dans linventaire ;
- une quantité minimale de cet item ;
- un niveau minimal de compétence.

Les vérifications sont faites côté serveur dans `gr-gathering` avant tout ajout dinventaire.

## 2. Agents consultés

- `software-architect`
- `backend-lua`
- `database-engineer`
- `security-reviewer`
- `qa-tester`
- `nanos-world-lua-agent`

## 3. Fichiers créés

- `database/migrations/025_gathering_requirements.sql`
- `docs/codex-reports/issue-119-gathering-requirements-report.md`

## 4. Fichiers modifiés

- `database/seeds/gathering_mvp_seed.sql`
- `server/Packages/gr-gathering/Server/GatheringRepository.lua`
- `server/Packages/gr-gathering/Server/GatheringService.lua`
- `server/Packages/gr-gathering/Server/Index.lua`

## 5. Fichiers explicitement non modifiés

- `server/Packages/gr-inventory/`
- `server/Packages/gr-skills/`
- `server/Packages/gr-shops/`
- `server/Packages/gr-economy/`
- `server/Packages/gr-contracts/`
- `Config.toml` réel

## 6. Migration SQL ajoutée

- `database/migrations/025_gathering_requirements.sql`

Colonnes ajoutées sur `gathering_nodes` :

- `required_item_key`
- `required_item_quantity`
- `required_skill_level`

## 7. Seed MVP modifié

- `database/seeds/gathering_mvp_seed.sql`

Ajouts/ajustements :

- item seedé : `repair_tool`
- `scrap_field` reste sans requirement
- `electronic_wreck` requiert `repair_tool x1` et `mechanics level 2`
- `medical_cache` requiert `medkit_basic x1` et `medicine level 2`
- `water_source` reste sans requirement

## 8. Requirements outil/skill

La validation serveur applique :

- outil requis uniquement si `required_item_key` est défini ;
- quantité requise via `required_item_quantity` ;
- niveau skill requis uniquement si `required_skill_key` et `required_skill_level` sont définis.

Résultats métiers gérés :

- `required-item-missing`
- `inventory-check-unavailable`
- `skill-level-insufficient`
- `skill-check-unavailable`

## 9. Intégration inventaire

La vérification outil utilise :

- `GRInventoryBridge.ListInventory(character_id, callback)`

Le service agrège les quantités par `item_key` côté serveur.

Loutil nest pas consommé dans ce lot.

## 10. Intégration skills

La vérification niveau utilise :

- `GRSkillsBridge.ListSkills(character_id, callback)`

Le niveau courant est lu sur la compétence ciblée. Si la compétence est absente de la liste, le niveau courant est traité comme `0`.

## 11. Impact sur /gather

Ordre des checks :

1. node existe
2. node actif
3. proximité
4. cooldown
5. requirements item/skill
6. ajout inventaire
7. XP
8. cooldown persisté

`/gathernodes` et `/gatherinfo` affichent désormais les prérequis.

## 12. Tests PostgreSQL effectués

Exécutés :

```powershell
Get-Content -Raw ".\database\migrations\025_gathering_requirements.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
Get-Content -Raw ".\database\seeds\gathering_mvp_seed.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, result_item_key, min_quantity, max_quantity, required_item_key, required_item_quantity, required_skill_key, required_skill_level, skill_xp, cooldown_seconds, is_active FROM gathering_nodes ORDER BY key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, item_key, quantity, metadata_json FROM inventory_items ORDER BY character_id, item_key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, skill_key, level, current_xp, total_xp FROM character_skills ORDER BY character_id, skill_key;"
```

Constats :

- migration `025` appliquée ;
- seed gathering réappliqué ;
- `electronic_wreck` requiert `repair_tool x1` et `mechanics level 2` ;
- `medical_cache` requiert `medkit_basic x1` et `medicine level 2` ;
- `scrap_field` reste sans requirement ;
- les données actuelles en base montrent `medkit_basic` dans `inventory_items` pour `character_id=3`, mais aucun `repair_tool` possédé par défaut ;
- les données actuelles en base montrent `medicine` pour `character_id=3`, mais pas de skill `mechanics` sur cette ligne.

## 13. Tests runtime effectués ou restants

Runtime non exécuté dans ce lot.

Restent à faire :

```txt
/gathernodes
/gatherinfo scrap_field
/gather scrap_field
/inv

/gatherinfo electronic_wreck
/gather electronic_wreck
/giveitem repair_tool 1
/gather electronic_wreck
/skills
/xpinfo
```

## 14. Risques restants

- pas de retest runtime nanos world dans ce lot ;
- pas de durabilité ni de consommation doutil ;
- si `ListInventory` ou `ListSkills` deviennent indisponibles, la récolte est refusée proprement ;
- `required_item_key` nest pas protégé par FK dans cette migration MVP ;
- le runtime devra confirmer que le personnage de test ciblé possède bien le niveau `mechanics` attendu après setup, sinon `electronic_wreck` restera logiquement bloqué.

## 15. Résultat git status -sb

```txt
## feature/issue-119-gathering-requirements
 M database/seeds/gathering_mvp_seed.sql
 M server/Packages/gr-gathering/Server/GatheringRepository.lua
 M server/Packages/gr-gathering/Server/GatheringService.lua
 M server/Packages/gr-gathering/Server/Index.lua
?? database/migrations/025_gathering_requirements.sql
?? docs/codex-reports/issue-119-gathering-requirements-report.md
```

## 16. Message de commit recommandé

```txt
feat(gathering): add gather requirements
```
