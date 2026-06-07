# Issue #120  Gathering node stock MVP

## 1. Résumé de limplémentation

Ajout dun stock optionnel sur `gathering_nodes` avec support serveur pour :
- vérification de stock avant récolte ;
- limitation de la quantité récoltée au stock disponible ;
- décrément atomique du stock ;
- compensation stock si lajout inventaire échoue ;
- restock paresseux simple via `restock_seconds` et `last_restock_at` ;
- commande debug `/restocknode`.

Documentation nanos world consultée avant modification :
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

- `database/migrations/026_gathering_node_stock.sql`
- `docs/codex-reports/issue-120-gathering-node-stock-report.md`

## 4. Fichiers modifiés

- `database/seeds/gathering_mvp_seed.sql`
- `server/Packages/gr-gathering/Server/GatheringRepository.lua`
- `server/Packages/gr-gathering/Server/GatheringService.lua`
- `server/Packages/gr-gathering/Server/Index.lua`
- `server/Packages/gr-chat/Server/Index.lua`

## 5. Fichiers explicitement non modifiés

- `server/Packages/gr-inventory/`
- `server/Packages/gr-skills/`
- `server/Packages/gr-shops/`
- `server/Packages/gr-economy/`
- `server/Packages/gr-contracts/`
- `Config.toml`

## 6. Migration SQL ajoutée

Ajout de `database/migrations/026_gathering_node_stock.sql` avec :
- `stock_enabled`
- `stock_quantity`
- `max_stock`
- `restock_seconds`
- `last_restock_at`

Contraintes ajoutées de manière idempotente :
- `stock_quantity >= 0` si non null
- `max_stock >= 0` si non null
- `stock_quantity <= max_stock` si les deux sont non null
- `restock_seconds > 0` si non null

## 7. Seed MVP modifié

Mise à jour de `database/seeds/gathering_mvp_seed.sql` :
- `scrap_field` : stock activé `25/25`, restock `1800s`
- `electronic_wreck` : stock activé `10/10`, restock `3600s`
- `water_source` : stock illimité
- `medical_cache` : stock activé `5/5`, restock `7200s`

Le seed reste relançable.

## 8. Stock de node

Le repository normalise désormais :
- `stock_enabled`
- `stock_quantity`
- `max_stock`
- `restock_seconds`
- `last_restock_at`

Méthodes ajoutées :
- `DecreaseNodeStock(node_key, quantity, callback)`
- `IncreaseNodeStock(node_key, quantity, callback)`
- `RestockNode(node_key, quantity, callback)`
- `MaybeRestockNode(node_key, callback)`

Le décrément utilise une requête SQL atomique et refuse tout passage sous zéro.

## 9. Impact sur /gather

Le flux `Gather(...)` vérifie maintenant :
1. node présent et actif ;
2. restock paresseux éventuel ;
3. proximité ;
4. cooldown ;
5. requirements ;
6. quantité aléatoire bornée ;
7. limitation au stock disponible ;
8. décrément du stock ;
9. ajout inventaire ;
10. compensation stock si ajout inventaire en échec ;
11. XP skill ;
12. écriture cooldown.

Messages ajoutés ou couverts :
- `Recolte impossible : node epuise.`
- `Recolte impossible : stock insuffisant.`
- `Recolte impossible : erreur stock.`

## 10. Commande /restocknode

Commande ajoutée :

```txt
/restocknode <node_key> [quantity]
```

Règles :
- protégée par `gr_gathering_debug_commands_enabled`
- protégée par `gr_gathering_debug_allowed_platform_ids`
- sans quantité : remise à `max_stock`
- avec quantité : augmentation plafonnée à `max_stock`

## 11. Compensation en cas déchec inventaire

Si le stock a été décrémenté puis que `GRInventoryBridge.AddItem(...)` échoue :
- tentative de restauration du stock via `IncreaseNodeStock(...)`
- si cette restauration échoue, retour `stock-compensation-failed`

Le système reste un MVP applicatif, pas une atomicité transactionnelle SQL complète.

## 12. Tests PostgreSQL effectués

Commandes tentées :

```powershell
Get-Content -Raw ".\database\migrations\026_gathering_node_stock.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
Get-Content -Raw ".\database\seeds\gathering_mvp_seed.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, result_item_key, min_quantity, max_quantity, stock_enabled, stock_quantity, max_stock, restock_seconds, last_restock_at, is_active FROM gathering_nodes ORDER BY key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, node_key, last_gathered_at, gather_count FROM character_gathering_cooldowns ORDER BY character_id, node_key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, item_key, quantity, metadata_json FROM inventory_items ORDER BY character_id, item_key;"
```

Résultat :
- non exécutables sur cette machine dans ce lot ;
- `docker exec` et `docker ps` échouent car le daemon Docker local est indisponible :
  `failed to connect to the docker API at npipe:////./pipe/dockerDesktopLinuxEngine`

## 13. Tests runtime effectués ou restants

Tests runtime non exécutés dans ce lot.

Restent à faire :

```txt
/gathernodes
/gatherinfo scrap_field
/gather scrap_field
/gatherinfo scrap_field
/restocknode scrap_field
/gatherinfo scrap_field
/inv
/skills
/xpinfo
```

## 14. Risques restants

- pas de validation PostgreSQL effective tant que Docker local reste indisponible ;
- pas de test runtime nanos world exécuté dans ce lot ;
- atomicité applicative seulement entre stock, inventaire et cooldown ;
- warnings `LF -> CRLF` remontés par `git diff --check`.

## 15. Résultat git status -sb

Résultat final :

```txt
## feature/issue-120-gathering-node-stock
 M database/seeds/gathering_mvp_seed.sql
 M server/Packages/gr-chat/Server/Index.lua
 M server/Packages/gr-gathering/Server/GatheringRepository.lua
 M server/Packages/gr-gathering/Server/GatheringService.lua
 M server/Packages/gr-gathering/Server/Index.lua
?? database/migrations/026_gathering_node_stock.sql
?? docs/codex-reports/issue-120-gathering-node-stock-report.md
```

## 16. Message de commit recommandé

```txt
feat(gathering): add node stock management
```
