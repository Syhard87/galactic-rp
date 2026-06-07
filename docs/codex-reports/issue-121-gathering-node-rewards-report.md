# Issue #121  Gathering rewards table MVP

## 1. Résumé de limplémentation

Ajout d'une table serveur `gathering_node_rewards` pour permettre à un node de récolte de distribuer plusieurs items possibles avec :
- récompense garantie ;
- récompense bonus avec chance ;
- quantités min/max par reward ;
- fallback legacy automatique sur `gathering_nodes.result_item_key / min_quantity / max_quantity`.

Le tirage reste entièrement server-authoritative dans `gr-gathering`.

Documentation consultée avant modification Lua/package :
- `docs/cahier-des-charges.md`
- `external/nanos-world-docs/docs/core-concepts/packages/packages-guide.md`
- `external/nanos-world-docs/docs/core-concepts/scripting/communicating-between-packages.md`

## 2. Agents consultés

- `.codex/agents/software-architect.toml`
- `.codex/agents/backend-lua.toml`
- `.codex/agents/database-engineer.toml`
- `.codex/agents/security-reviewer.toml`
- `.codex/agents/qa-tester.toml`
- `.codex/agents/nanos-world-lua-agent.md`

## 3. Fichiers créés

- `database/migrations/027_gathering_node_rewards.sql`
- `docs/codex-reports/issue-121-gathering-node-rewards-report.md`

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
- `Config.toml`

## 6. Migration SQL ajoutée

Migration ajoutée :

- `database/migrations/027_gathering_node_rewards.sql`

Table créée :

- `gathering_node_rewards`

Structure couverte :
- `id`
- `node_key`
- `item_key`
- `reward_type`
- `min_quantity`
- `max_quantity`
- `chance_percent`
- `is_active`
- `created_at`
- `updated_at`

Contraintes et index :
- check sur `reward_type IN ('primary', 'bonus')`
- check sur quantités et `chance_percent`
- index `node_key`, `item_key`, `is_active`
- index unique `(node_key, item_key, reward_type)` pour seed relançable

## 7. Seed MVP modifié

Seed modifié :

- `database/seeds/gathering_mvp_seed.sql`

Rewards ajoutées :
- `scrap_field`
  - `primary scrap chance=100 qty=1-3`
  - `bonus electronic_component chance=20 qty=1-1`
- `electronic_wreck`
  - `primary electronic_component chance=100 qty=1-2`
  - `bonus scrap chance=35 qty=1-2`
- `water_source`
  - `primary water_bottle chance=100 qty=1-2`
- `medical_cache`
  - `primary medkit_basic chance=100 qty=1-1`

Les colonnes legacy sur `gathering_nodes` restent présentes et seedées.

## 8. Table gathering_node_rewards

Le repository ajoute :

- `ListNodeRewards(node_key, callback)`

Normalisation des rewards :
- `id`
- `node_key`
- `item_key`
- `reward_type`
- `min_quantity`
- `max_quantity`
- `chance_percent`
- `is_active`

Ordre de lecture stable :
- `primary` puis `bonus`
- puis `item_key`
- puis `id`

## 9. Impact sur /gather

Le flux `Gather(...)` :
1. charge le node ;
2. applique le restock paresseux existant ;
3. vérifie proximité, cooldown et requirements ;
4. charge les rewards actives ;
5. utilise la table rewards si présente, sinon fallback legacy ;
6. garantit au moins une reward `primary` si aucune reward n'a été tirée ;
7. borne le total distribué au stock disponible si le node a un stock activé ;
8. décrémente le stock ;
9. ajoute chaque reward à l'inventaire ;
10. tente un rollback inventaire puis stock si une insertion échoue ;
11. donne l'XP skill comme avant ;
12. met à jour le cooldown comme avant.

Nouveaux résultats gérés :
- `no-reward-generated`
- multi-rewards sur un seul gather

## 10. Impact sur /gatherinfo

`/gatherinfo <node_key>` affiche maintenant :

```txt
Rewards:
- primary scrap qty=1-3 chance=100%
- bonus electronic_component qty=1-1 chance=20%
```

Si aucune reward active n'existe :

```txt
Rewards: legacy <item> qty=<min>-<max>
```

## 11. Compatibilité legacy result_item_key

Compatibilité conservée :
- `gathering_nodes.result_item_key` reste en place
- `gathering_nodes.min_quantity / max_quantity` restent en place
- si aucune reward active n'existe sur `gathering_node_rewards`, le node utilise encore le comportement legacy

La table rewards devient la voie préférée sans casser les anciens nodes.

## 12. Tests PostgreSQL effectués

Commandes exécutées :

```powershell
Get-Content -Raw ".\database\migrations\027_gathering_node_rewards.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
Get-Content -Raw ".\database\migrations\026_gathering_node_stock.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
Get-Content -Raw ".\database\seeds\gathering_mvp_seed.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT node_key, item_key, reward_type, min_quantity, max_quantity, chance_percent, is_active FROM gathering_node_rewards ORDER BY node_key, reward_type, item_key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, result_item_key, min_quantity, max_quantity, stock_enabled, stock_quantity, max_stock, is_active FROM gathering_nodes ORDER BY key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, item_key, quantity, metadata_json FROM inventory_items ORDER BY character_id, item_key;"
```

Constats :
- `027` appliquée avec succès
- la base locale avait encore besoin de `026` pour exposer `stock_enabled`, `stock_quantity`, `max_stock`
- `gathering_node_rewards` contient `6` lignes actives
- `gathering_nodes` garde ses colonnes legacy et son stock actuel
- `inventory_items` reste lisible

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
/inv
/skills
/xpinfo
```

## 14. Risques restants

- pas de test runtime nanos world exécuté ici
- compensation partielle possible si plusieurs `AddItem(...)` réussissent puis qu'un rollback inventaire échoue
- le stock est borné sur la somme totale distribuée ; en cas de dépassement, les rewards de fin de liste sont réduites en priorité
- warnings `LF -> CRLF` possibles au `git diff --check`

## 15. Résultat git status -sb

```txt
## feature/issue-121-gathering-rewards-table
 M database/seeds/gathering_mvp_seed.sql
 M server/Packages/gr-gathering/Server/GatheringRepository.lua
 M server/Packages/gr-gathering/Server/GatheringService.lua
 M server/Packages/gr-gathering/Server/Index.lua
?? database/migrations/027_gathering_node_rewards.sql
?? docs/codex-reports/issue-121-gathering-node-rewards-report.md
```

## 16. Message de commit recommandé

```txt
feat(gathering): add node rewards table
```
