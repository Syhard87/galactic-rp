# Issue #117  Shops access requirements MVP

## 1. Résumé de limplémentation

Ajout de requirements d'accès côté serveur sur `shops` et `shop_items`.

Le système applique la règle MVP suivante :
- tous les requirements sont `NULL` par défaut ;
- si aucun requirement n'est défini, l'accès reste inchangé ;
- `/buy` valide les requirements de la boutique puis de l'item ;
- `/sell` valide seulement le requirement de la boutique ;
- les checks restent server-authoritative.

## 2. Agents consultés

- `software-architect`
- `backend-lua`
- `database-engineer`
- `security-reviewer`
- `qa-tester`
- `nanos-world-lua-agent`

## 3. Fichiers créés

- `database/migrations/023_shops_access_requirements.sql`
- `docs/codex-reports/issue-117-shops-access-requirements-report.md`

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
- `server/Packages/gr-factions/`
- `Config.toml` réel

## 6. Migration SQL ajoutée

Migration ajoutée :
- `database/migrations/023_shops_access_requirements.sql`

Colonnes ajoutées sur `shops` :
- `required_reputation_key`
- `required_reputation_min_value`
- `required_faction_key`

Colonnes ajoutées sur `shop_items` :
- `required_reputation_key`
- `required_reputation_min_value`
- `required_faction_key`

Contraintes ajoutées :
- `required_reputation_min_value IS NULL OR required_reputation_min_value >= 0`

Migration idempotente, sans `DROP`.

## 7. Seed MVP modifié

Seed modifié :
- `database/seeds/shops_mvp_seed.sql`

Décision MVP appliquée :
- `general_store` reste sans requirement
- `medical_kiosk` reste sans requirement
- `tech_vendor` reste sans requirement boutique
- `tech_vendor/comlink` requiert `merchant_guild >= 50`

Les requirements faction ne sont pas seedés dans ce lot, car le schéma factions expose surtout un `type` fiable, pas une vraie `faction_key` dédiée.

## 8. Requirements boutique/item

Le repository remonte maintenant :
- `required_reputation_key`
- `required_reputation_min_value`
- `required_faction_key`

Le service applique :
- requirement boutique
- puis requirement item

Si aucun requirement n'est défini, l'accès est autorisé comme avant.

## 9. Intégration réputation/faction

Réputation :
- check via `GRReputationBridge.ListCharacterReputations(character_id, callback)`
- comparaison serveur `value >= required_reputation_min_value`

Faction :
- support côté service via `GRFactionsBridge.ResolveActiveCharacterFaction(player, callback)`
- comparaison MVP sur `faction.type`

Documentation nanos consultée avant modification Lua :
- `external/nanos-world-docs/docs/core-concepts/packages/packages-guide.md`
- `external/nanos-world-docs/docs/core-concepts/scripting/communicating-between-packages.md`
- `docs/nanos-world-reference.md`

## 10. Impact sur /buy et /sell

`/buy` :
- vérifie boutique active
- vérifie proximité
- vérifie requirements boutique + item
- vérifie stock
- exécute paiement, stock, inventaire

`/sell` :
- vérifie boutique active
- vérifie proximité
- vérifie seulement le requirement de la boutique
- conserve la logique MVP de revente existante

Messages ajoutés :
- `Achat impossible : reputation insuffisante.`
- `Achat impossible : verification reputation impossible.`
- `Achat impossible : faction requise.`
- `Achat impossible : acces boutique refuse.`
- équivalents vente

`/shops` et `/shopitems` affichent maintenant un résumé court :
- `req_rep=<key>>=<value>`
- `req_faction=<key>`

## 11. Tests PostgreSQL effectués

Exécutés :

```powershell
Get-Content -Raw ".\database\migrations\023_shops_access_requirements.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
Get-Content -Raw ".\database\seeds\shops_mvp_seed.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, name, required_reputation_key, required_reputation_min_value, required_faction_key FROM shops ORDER BY key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT s.key AS shop_key, si.item_key, si.required_reputation_key, si.required_reputation_min_value, si.required_faction_key, si.price, si.sell_price, si.stock_enabled, si.stock_quantity, si.is_active FROM shop_items si JOIN shops s ON s.id = si.shop_id ORDER BY s.key, si.item_key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, name, min_value, max_value, default_value, is_active FROM reputation_definitions ORDER BY key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, reputation_key, value, rank FROM character_reputations ORDER BY character_id, reputation_key;"
```

Constats :
- colonnes requirements présentes sur `shops`
- colonnes requirements présentes sur `shop_items`
- `merchant_guild` existe bien dans `reputation_definitions`
- `tech_vendor/comlink` est seedé avec `merchant_guild >= 50`
- `character_reputations` est vide avant retest runtime, ce qui est cohérent

## 12. Tests runtime effectués ou restants

Runtime non exécuté dans ce lot.

Checklist restante :

```txt
/shops
/shopitems general_store
/shopitems tech_vendor
/givemoney bank 500 shop_req_test
/buy general_store ration_pack 1
/buy tech_vendor comlink 1
/givereputation merchant_guild 100 shop_req_test
/buy tech_vendor comlink 1
/inv
/money
/transactions
```

## 13. Risques restants

- pas de retest runtime effectué ici pour confirmer les messages exacts en jeu
- le check faction repose sur `factions.type` comme clé MVP
- si un requirement réputation pointe vers une clé absente ou inactive, le service refuse avec `reputation-check-unavailable`
- `git diff --check` peut encore remonter des warnings `LF -> CRLF`

## 14. Résultat git status -sb

```txt
## feature/issue-117-shops-access-requirements
 M database/seeds/shops_mvp_seed.sql
 M server/Packages/gr-shops/Server/Index.lua
 M server/Packages/gr-shops/Server/ShopRepository.lua
 M server/Packages/gr-shops/Server/ShopService.lua
?? database/migrations/023_shops_access_requirements.sql
?? docs/codex-reports/issue-117-shops-access-requirements-report.md
```

## 15. Message de commit recommandé

```txt
feat(shops): add access requirements
```
