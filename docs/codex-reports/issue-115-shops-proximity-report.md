# Issue #115  Shops proximity MVP

## 1. Résumé de limplémentation

Ajout d'un contrôle de proximité serveur pour `gr-shops`.

Le MVP applique la règle suivante :
- si `requires_proximity = false`, la boutique reste utilisable à distance ;
- si `requires_proximity = true`, `/buy` et `/sell` exigent une position boutique valide, une position joueur disponible et une distance `<= radius`.

La consultation `/shops` et `/shopitems` reste disponible à distance.

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

- `database/migrations/021_shops_proximity.sql`
- `docs/codex-reports/issue-115-shops-proximity-report.md`

## 4. Fichiers modifiés

- `database/seeds/shops_mvp_seed.sql`
- `server/Packages/gr-shops/Server/ShopRepository.lua`
- `server/Packages/gr-shops/Server/ShopService.lua`
- `server/Packages/gr-shops/Server/Index.lua`

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
- `database/migrations/021_shops_proximity.sql`

Effet :
- `shops.position_x DOUBLE PRECISION`
- `shops.position_y DOUBLE PRECISION`
- `shops.position_z DOUBLE PRECISION`
- `shops.radius DOUBLE PRECISION NOT NULL DEFAULT 250.0`
- `shops.requires_proximity BOOLEAN NOT NULL DEFAULT false`
- contrainte `radius > 0`

Migration idempotente, sans `DROP`.

## 7. Seed MVP modifié

Seed modifié :
- `database/seeds/shops_mvp_seed.sql`

Configuration MVP :
- `position_x = NULL`
- `position_y = NULL`
- `position_z = NULL`
- `radius = 250.0`
- `requires_proximity = false`

Le seed reste relançable et conserve le comportement distant des tests existants.

## 8. Proximité boutique

La proximité est validée dans `ShopService`.

Source de position serveur utilisée :
- `player:GetControlledCharacter():GetLocation()`

Règles :
- `requires_proximity = false` : autorisé
- `requires_proximity = true` + position boutique invalide : refus
- `requires_proximity = true` + position joueur indisponible : refus
- `requires_proximity = true` + distance > radius : refus

Codes d'erreur gérés :
- `shop-too-far`
- `shop-position-invalid`
- `player-position-unavailable`

## 9. Impact sur /buy et /sell

`/buy` :
- inchangé si `requires_proximity = false`
- message ajouté :
  - `Achat impossible : vous etes trop loin de cette boutique.`

`/sell` :
- inchangé si `requires_proximity = false`
- message ajouté :
  - `Vente impossible : vous etes trop loin de cette boutique.`

`/shops` :
- affiche maintenant `radius` et `proximity`

`/shopitems` :
- non bloqué par la distance

## 10. Tests PostgreSQL effectués

Exécutés :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1 -f /workspace/database/migrations/021_shops_proximity.sql
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1 -f /workspace/database/seeds/shops_mvp_seed.sql
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, key, name, position_x, position_y, position_z, radius, requires_proximity, is_active FROM shops ORDER BY key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT s.key AS shop_key, si.item_key, si.wallet, si.price, si.sell_price, si.is_sellable, si.is_active FROM shop_items si JOIN shops s ON s.id = si.shop_id ORDER BY s.key, si.item_key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT column_name FROM information_schema.columns WHERE table_name = 'shops' ORDER BY ordinal_position;"
```

Constats :
- migration `021` appliquée ;
- colonnes de proximité présentes sur `shops` ;
- boutiques seedées avec `radius=250` et `requires_proximity=false` ;
- `shop_items` inchangé côté contenu métier.

## 11. Tests runtime effectués ou restants

Runtime non exécuté dans ce lot.

Checklist restante :

```txt
/shops
/shopitems general_store
/givemoney bank 200 shop_proximity_test
/buy general_store ration_pack 1
/sell general_store ration_pack 1
```

Test manuel futur en DB :

```sql
UPDATE shops
SET requires_proximity = true,
    position_x = <position proche>,
    position_y = <position proche>,
    position_z = <position proche>,
    radius = 500
WHERE key = 'general_store';
```

## 12. Risques restants

- la récupération de position dépend du `ControlledCharacter` serveur ; si le joueur n'est pas possédé au moment de la commande, le refus sera strict ;
- pas de visualisation de zone, pas de PNJ, pas de marker dans ce MVP ;
- pas de test runtime exécuté ici pour confirmer le cas `requires_proximity=true` ;
- `git diff --check` ne remonte ici que des warnings `LF -> CRLF`.

## 13. Résultat git status -sb

```txt
## feature/issue-115-shops-proximity
 M database/seeds/shops_mvp_seed.sql
 M server/Packages/gr-shops/Server/Index.lua
 M server/Packages/gr-shops/Server/ShopRepository.lua
 M server/Packages/gr-shops/Server/ShopService.lua
?? database/migrations/021_shops_proximity.sql
?? docs/codex-reports/issue-115-shops-proximity-report.md
```

## 14. Message de commit recommandé

```txt
feat(shops): add proximity checks
```
