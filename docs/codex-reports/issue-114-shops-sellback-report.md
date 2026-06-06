# Issue #114  Shops sellback MVP

## 1. Résumé de limplémentation

Ajout du MVP de revente boutique côté serveur avec `/sell <shop_key> <item_key> <quantity>`.
Le flux reste server-authoritative :
- lecture de la configuration boutique en DB ;
- retrait d'objet via `GRInventoryBridge.RemoveItem(...)` ;
- crédit économie via `GREconomyBridge.AddMoney(...)` ;
- transaction journalisée par `gr-economy` ;
- compensation inventaire tentée si le crédit économie échoue après retrait.

Documentation nanos world vérifiée avant modification :
- `external/nanos-world-docs/docs/core-concepts/packages/packages-guide.md`
- `external/nanos-world-docs/docs/core-concepts/scripting/communicating-between-packages.md`

## 2. Agents consultés

- `software-architect`
- `backend-lua`
- `database-engineer`
- `security-reviewer`
- `qa-tester`
- `nanos-world-lua-agent`

## 3. Fichiers créés

- `database/migrations/020_shops_sellback.sql`

## 4. Fichiers modifiés

- `database/seeds/shops_mvp_seed.sql`
- `server/Packages/gr-shops/Server/Index.lua`
- `server/Packages/gr-shops/Server/ShopRepository.lua`
- `server/Packages/gr-shops/Server/ShopService.lua`
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
- `database/migrations/020_shops_sellback.sql`

Effet :
- `shop_items.sell_price INTEGER`
- `shop_items.is_sellable BOOLEAN NOT NULL DEFAULT false`
- contrainte `sell_price IS NULL OR sell_price > 0`

Migration idempotente, sans `DROP`.

## 7. Seed MVP modifié

Seed modifié :
- `database/seeds/shops_mvp_seed.sql`

Sellback MVP configuré :
- `general_store / ration_pack / sell_price=10 / is_sellable=true`
- `general_store / id_card / sell_price=NULL / is_sellable=false`
- `medical_kiosk / medkit_basic / sell_price=25 / is_sellable=true`
- `tech_vendor / comlink / sell_price=30 / is_sellable=true`

## 8. Commande /sell

Commande ajoutée :
- `/sell <shop_key> <item_key> <quantity>`

Messages couverts :
- `Boutique introuvable.`
- `Boutique inactive.`
- `Objet non revendable dans cette boutique.`
- `Quantite invalide.`
- `Inventaire insuffisant.`
- `Inventaire indisponible.`
- `Economie indisponible.`
- `Erreur lors de la vente.`
- `Vente effectuee : ration_pack x1 pour 10 credits.`

## 9. Intégration économie/inventaire

Intégration réalisée dans `gr-shops` uniquement :
- lecture article via `ShopRepository`
- retrait inventaire via `GRInventoryBridge.RemoveItem(...)`
- crédit wallet via `GREconomyBridge.AddMoney(...)`
- raison de transaction :
  - `shop_sell:<shop_key>:<item_key>`

## 10. Compensation en cas déchec économie

Stratégie MVP retenue :
- retirer l'objet d'abord ;
- si le crédit économie échoue, tenter `GRInventoryBridge.AddItem(...)` pour restaurer la quantité ;
- si cette compensation échoue aussi, renvoyer `rollback-failed`.

Limite restante :
- pas d'atomicité SQL parfaite entre inventaire et économie.

## 11. Tests PostgreSQL effectués

Exécutés :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1 -f /workspace/database/migrations/020_shops_sellback.sql
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1 -f /workspace/database/seeds/shops_mvp_seed.sql
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT s.key AS shop_key, si.item_key, si.wallet, si.price, si.sell_price, si.is_sellable, si.is_active FROM shop_items si JOIN shops s ON s.id = si.shop_id ORDER BY s.key, si.item_key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, item_key, quantity, metadata_json FROM inventory_items ORDER BY character_id, item_key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, first_name, last_name, money_cash, money_bank FROM characters ORDER BY id;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, character_id, target_character_id, amount, currency, wallet, type, reason, created_at FROM bank_transactions ORDER BY id DESC LIMIT 20;"
```

Constats :
- migration `020` appliquee ;
- colonnes `sell_price` et `is_sellable` presentes ;
- `ration_pack`, `medkit_basic` et `comlink` sont revendables ;
- `id_card` reste non revendable ;
- `bank_transactions` est encore vide avant retest runtime.

## 12. Tests runtime effectués ou restants

Runtime non execute dans ce lot.

Checklist restante :

```txt
/givemoney bank 200 shop_sell_test_setup
/buy general_store ration_pack 2
/inv
/money
/sell general_store ration_pack 1
/inv
/money
/transactions
```

## 13. Risques restants

- pas d'atomicité SQL parfaite entre retrait inventaire et crédit économie ;
- la compensation inventaire après échec économie reste à confirmer en runtime ;
- pas de stock dynamique, pas de proximité boutique, pas de marché dynamique dans ce MVP ;
- `git diff --check` ne remonte ici que des warnings `LF -> CRLF`.

## 14. Résultat git status -sb

```txt
## feature/issue-114-shops-sellback
 M database/seeds/shops_mvp_seed.sql
 M server/Packages/gr-chat/Server/Index.lua
 M server/Packages/gr-shops/Server/Index.lua
 M server/Packages/gr-shops/Server/ShopRepository.lua
 M server/Packages/gr-shops/Server/ShopService.lua
?? database/migrations/020_shops_sellback.sql
```

## 15. Message de commit recommandé

```txt
feat(shops): add item sellback
```
