# Issue #113  Shops foundation MVP

## 1. Résumé de limplémentation

Cette issue ajoute une fondation serveur `gr-shops` permettant :

- de lister les boutiques ;
- de lister les objets vendus par boutique ;
- d'acheter un objet via économie + inventaire ;
- de garder le calcul prix/quantité entièrement côté serveur.

Le lot reste sans UI, sans PNJ réel, sans proximité obligatoire et sans marché dynamique.

## 2. Agents consultés

- `software-architect`
- `backend-lua`
- `database-engineer`
- `security-reviewer`
- `qa-tester`
- `nanos-world-lua-agent`

Documentation nanos world relue avant modification Lua :

- `external/nanos-world-docs/docs/core-concepts/packages/packages-guide.md`
- `external/nanos-world-docs/docs/core-concepts/scripting/communicating-between-packages.md`

Référence projet relue :

- `docs/cahier-des-charges.md`

## 3. Fichiers créés

- `database/migrations/019_shops_foundation.sql`
- `database/seeds/shops_mvp_seed.sql`
- `server/Packages/gr-shops/Package.toml`
- `server/Packages/gr-shops/Shared/Index.lua`
- `server/Packages/gr-shops/Server/Index.lua`
- `server/Packages/gr-shops/Server/ShopRepository.lua`
- `server/Packages/gr-shops/Server/ShopService.lua`
- `docs/codex-reports/issue-113-shops-foundation-report.md`

## 4. Fichiers modifiés

- `server/Packages/gr-chat/Server/Index.lua`

## 5. Fichiers explicitement non modifiés

- `server/Packages/gr-economy/`
- `server/Packages/gr-inventory/`
- `server/Packages/gr-contracts/`
- `server/Packages/gr-crafting/`
- `server/Packages/gr-quests/`
- `Config.toml` réel

## 6. Migration SQL ajoutée

Migration ajoutée :

- `database/migrations/019_shops_foundation.sql`

Tables créées :

- `shops`
- `shop_items`

Contraintes principales :

- `shops.key` unique
- `shop_items (shop_id, item_key)` unique
- `wallet` limité à `cash | bank`
- `price > 0`

## 7. Seed MVP ajouté

Seed ajouté :

- `database/seeds/shops_mvp_seed.sql`

Boutiques seedées :

- `general_store`
- `medical_kiosk`
- `tech_vendor`

Le seed est volontairement limité aux `item_key` réellement présents dans le projet :

- `ration_pack`
- `id_card`
- `medkit_basic`
- `comlink`

## 8. Package gr-shops

Package créé :

- `gr-shops`

Dépendances :

- `gr-core`
- `gr-database`
- `gr-characters`
- `gr-economy`
- `gr-inventory`

Bridge exporté :

- `GRShopsBridge.ListShops`
- `GRShopsBridge.ListShopItems`
- `GRShopsBridge.BuyItem`

## 9. Commandes /shops /shopitems /buy

Commandes ajoutées :

- `/shops`
- `/shopitems <shop_key>`
- `/buy <shop_key> <item_key> <quantity>`

Protection debug utilisée :

- `gr_shops_debug_commands_enabled`
- `gr_shops_debug_allowed_platform_ids`

## 10. Intégration économie/inventaire

Flux d'achat serveur :

1. chargement de l'entrée boutique ;
2. validation `shop`, `item`, `quantity` ;
3. calcul serveur du prix total ;
4. débit via `GREconomyBridge.RemoveMoney(...)` ;
5. ajout item via `GRInventoryBridge.AddItem(...)` ;
6. message de succès en jeu.

Reason économie utilisée :

```txt
shop:<shop_key>:<item_key>
```

## 11. Compensation en cas déchec inventaire

Si le débit économie réussit mais que l'ajout inventaire échoue :

- tentative de compensation via `GREconomyBridge.AddMoney(...)`
- log de rollback côté `gr-shops`

Limite documentée :

- il ne s'agit pas d'une atomicité SQL parfaite entre économie et inventaire ;
- la cohérence repose sur un rollback applicatif minimal.

## 12. Tests PostgreSQL effectués

Exécutés :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1 -f /workspace/database/migrations/019_shops_foundation.sql
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1 -f /workspace/database/seeds/shops_mvp_seed.sql
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, key, name, shop_type, is_active FROM shops ORDER BY key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT s.key AS shop_key, si.item_key, si.wallet, si.price, si.is_active FROM shop_items si JOIN shops s ON s.id = si.shop_id ORDER BY s.key, si.item_key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, first_name, last_name, money_cash, money_bank FROM characters ORDER BY id;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, item_key, quantity, metadata_json FROM inventory_items ORDER BY character_id, item_key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, character_id, target_character_id, amount, currency, wallet, type, reason, created_at FROM bank_transactions ORDER BY id DESC LIMIT 20;"
```

## 13. Tests runtime effectués ou restants

Runtime nanos world non exécuté dans ce lot.

Checklist restante :

```txt
/money
/shops
/shopitems general_store
/givemoney bank 200 shop_test_setup
/buy general_store ration_pack 2
/inv
/money
/transactions
```

## 14. Risques restants

- pas d'atomicité SQL parfaite entre débit économie et ajout inventaire
- aucune vérification de proximité boutique dans ce MVP
- l'échec inventaire sur item théoriquement valide devrait rester rare, mais la compensation doit encore être confirmée en runtime

## 15. Résultat git status -sb

Résultat attendu après ce lot :

```txt
## feature/issue-113-shops-foundation
 M server/Packages/gr-chat/Server/Index.lua
?? database/migrations/019_shops_foundation.sql
?? database/seeds/shops_mvp_seed.sql
?? docs/codex-reports/issue-113-shops-foundation-report.md
?? server/Packages/gr-shops/
```

## 16. Message de commit recommandé

```txt
feat(shops): add shops foundation
```
