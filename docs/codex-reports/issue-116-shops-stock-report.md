# Issue #116  Shops stock MVP

## 1. Résumé de limplémentation

Ajout d'un stock boutique optionnel sur `shop_items`.

Règles MVP appliquées :
- `stock_enabled = false` : achat inchangé, stock illimité ;
- `stock_enabled = true` : le serveur vérifie `stock_quantity >= quantity` ;
- après paiement, le stock est décrémenté côté serveur avant l'ajout inventaire ;
- en cas d'échec inventaire, tentative de compensation argent puis de restauration du stock.

La logique reste concentrée dans `gr-shops`.

## 2. Agents consultés

- `software-architect`
- `backend-lua`
- `database-engineer`
- `security-reviewer`
- `qa-tester`
- `nanos-world-lua-agent`

## 3. Fichiers créés

- `database/migrations/022_shops_stock.sql`
- `docs/codex-reports/issue-116-shops-stock-report.md`

## 4. Fichiers modifiés

- `database/seeds/shops_mvp_seed.sql`
- `server/Packages/gr-shops/Server/ShopRepository.lua`
- `server/Packages/gr-shops/Server/ShopService.lua`
- `server/Packages/gr-shops/Server/Index.lua`
- `server/Packages/gr-chat/Server/Index.lua`

## 5. Fichiers explicitement non modifiés

- `server/Packages/gr-economy/`
- `server/Packages/gr-inventory/`
- `server/Packages/gr-contracts/`
- `server/Packages/gr-crafting/`
- `server/Packages/gr-quests/`
- `server/Packages/gr-reputation/`
- `Config.toml` réel

## 6. Migration SQL ajoutée

Migration ajoutée :
- `database/migrations/022_shops_stock.sql`

Effet :
- `shop_items.stock_enabled BOOLEAN NOT NULL DEFAULT false`
- `shop_items.stock_quantity INTEGER`
- `shop_items.max_stock INTEGER`
- contraintes :
  - `stock_quantity IS NULL OR stock_quantity >= 0`
  - `max_stock IS NULL OR max_stock >= 0`
  - `stock_quantity <= max_stock` si les deux sont non nuls

Migration idempotente, sans `DROP`.

## 7. Seed MVP modifié

Seed modifié :
- `database/seeds/shops_mvp_seed.sql`

Configuration MVP :
- `general_store / ration_pack / stock_enabled=true / stock_quantity=20 / max_stock=20`
- `general_store / id_card / stock_enabled=false`
- `medical_kiosk / medkit_basic / stock_enabled=true / stock_quantity=10 / max_stock=10`
- `tech_vendor / comlink / stock_enabled=true / stock_quantity=8 / max_stock=8`

## 8. Stock boutique

Ajouts dans `ShopRepository` :
- normalisation `stock_enabled`
- normalisation `stock_quantity`
- normalisation `max_stock`
- `DecreaseShopItemStock(...)`
- `IncreaseShopItemStock(...)`

Règles :
- pas de stock négatif ;
- si `stock_enabled=false`, le décrément retourne succès sans bloquer l'achat ;
- si stock activé mais invalide, erreur ;
- décrément via requête SQL atomique avec condition `stock_quantity >= quantity`.

## 9. Impact sur /buy

`/buy` :
- vérifie le stock avant paiement ;
- si stock activé, décrémente le stock après paiement ;
- si décrément impossible, le paiement est compensé ;
- si ajout inventaire échoue après décrément, tentative de compensation argent puis restauration du stock.

Message ajouté :
- `Achat impossible : stock insuffisant.`

## 10. Commande /restockshop

Commande ajoutée :
- `/restockshop <shop_key> <item_key> <quantity>`

Protection :
- mêmes settings debug shops que le reste du package

Règles :
- quantité `> 0` et `<= 1000`
- restock limité par `max_stock` si défini
- refus si `stock_enabled=false`

Messages couverts :
- `Stock mis a jour : general_store ration_pack stock=20/20.`
- `Restock impossible : stock desactive pour cet objet.`
- `Restock impossible : quantite invalide.`

## 11. Compensation en cas déchec inventaire

Flux d'achat avec stock activé :
1. retrait argent
2. décrément stock
3. ajout inventaire

En cas d'échec à l'étape 3 :
- tentative de restauration du stock
- tentative de remboursement argent

Limite restante :
- pas d'atomicité SQL parfaite entre économie, stock et inventaire.

## 12. Tests PostgreSQL effectués

Exécutés :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1 -f /workspace/database/migrations/022_shops_stock.sql
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1 -f /workspace/database/seeds/shops_mvp_seed.sql
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT s.key AS shop_key, si.item_key, si.wallet, si.price, si.sell_price, si.is_sellable, si.stock_enabled, si.stock_quantity, si.max_stock, si.is_active FROM shop_items si JOIN shops s ON s.id = si.shop_id ORDER BY s.key, si.item_key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, item_key, quantity, metadata_json FROM inventory_items ORDER BY character_id, item_key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, first_name, last_name, money_cash, money_bank FROM characters ORDER BY id;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, character_id, target_character_id, amount, currency, wallet, type, reason, created_at FROM bank_transactions ORDER BY id DESC LIMIT 20;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT column_name FROM information_schema.columns WHERE table_name = 'shop_items' ORDER BY ordinal_position;"
```

Note d'exécution :
- la lecture `/workspace/...` dans le conteneur était en retard sur le workspace local ;
- migration et seed ont été réappliqués avec `Get-Content -Raw ... | docker exec ... psql ...` pour injecter le contenu local exact.

Constats :
- colonnes de stock présentes ;
- `ration_pack`, `medkit_basic` et `comlink` ont un stock fini ;
- `id_card` reste en stock illimité ;
- `bank_transactions` encore vide avant retest runtime.

## 13. Tests runtime effectués ou restants

Runtime non exécuté dans ce lot.

Checklist restante :

```txt
/shopitems general_store
/givemoney bank 200 shop_stock_test
/buy general_store ration_pack 2
/shopitems general_store
/restockshop general_store ration_pack 2
/shopitems general_store
/inv
/money
/transactions
```

## 14. Risques restants

- pas d'atomicité SQL parfaite entre paiement, stock et inventaire ;
- en cas d'échec de compensation multiple, l'état peut rester partiellement incohérent ;
- le retest runtime `/buy` + `/restockshop` reste à exécuter ;
- `git diff --check` ne remonte ici que des warnings `LF -> CRLF`.

## 15. Résultat git status -sb

```txt
## feature/issue-116-shops-stock
 M database/seeds/shops_mvp_seed.sql
 M server/Packages/gr-chat/Server/Index.lua
 M server/Packages/gr-shops/Server/Index.lua
 M server/Packages/gr-shops/Server/ShopRepository.lua
 M server/Packages/gr-shops/Server/ShopService.lua
?? database/migrations/022_shops_stock.sql
?? docs/codex-reports/issue-116-shops-stock-report.md
```

## 16. Message de commit recommandé

```txt
feat(shops): add stock management
```
