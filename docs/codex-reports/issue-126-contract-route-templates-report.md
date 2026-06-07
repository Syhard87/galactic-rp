# Issue #126  Contract route templates MVP

## 1. Résumé de limplémentation

Ajout dun système MVP de templates de routes de transport dans `gr-contracts`.

Le lot ajoute :

- une table serveur `contract_route_templates` ;
- un seed relançable de routes haul ;
- la lecture repository/service des routes ;
- la création dun contrat transport depuis une route via `/createhaulfromroute`.

Le flux existant reste réutilisé :

- `/acceptcontract`
- `/pickupcontract`
- `/completecontract`

## 2. Agents consultés

- `software-architect`
- `backend-lua`
- `database-engineer`
- `security-reviewer`
- `qa-tester`
- `nanos-world-lua-agent`

Documentation consultée avant modification :

- `docs/cahier-des-charges.md`
- `external/nanos-world-docs/docs/core-concepts/packages/packages-guide.md`
- `external/nanos-world-docs/docs/core-concepts/scripting/communicating-between-packages.md`
- `docs/codex-reports/issue-122-contract-item-delivery-report.md`
- `docs/codex-reports/issue-123-contract-delivery-locations-report.md`
- `docs/codex-reports/issue-124-contract-delivery-location-tools-report.md`
- `docs/codex-reports/issue-125-contract-pickup-locations-report.md`

## 3. Fichiers créés

- `database/migrations/031_contract_route_templates.sql`
- `database/seeds/contract_route_templates_mvp_seed.sql`
- `docs/codex-reports/issue-126-contract-route-templates-report.md`

## 4. Fichiers modifiés

- `server/Packages/gr-contracts/Server/ContractRepository.lua`
- `server/Packages/gr-contracts/Server/ContractService.lua`
- `server/Packages/gr-contracts/Server/Index.lua`
- `server/Packages/gr-chat/Server/Index.lua`

## 5. Fichiers explicitement non modifiés

- `server/Packages/gr-inventory/`
- `server/Packages/gr-economy/`
- `server/Packages/gr-gathering/`
- `server/Packages/gr-shops/`
- `Config.toml`

## 6. Migration SQL ajoutée

Fichier ajouté :

```txt
database/migrations/031_contract_route_templates.sql
```

Table ajoutée :

- `contract_route_templates`

Champs principaux :

- `key`
- `name`
- `description`
- `item_key`
- `item_quantity`
- `reward_money`
- `pickup_location_key`
- `delivery_location_key`
- `is_active`

## 7. Seed MVP ajouté

Fichier ajouté :

```txt
database/seeds/contract_route_templates_mvp_seed.sql
```

Routes seedées :

- `scrap_to_spatioport`
- `electronics_to_market`
- `medical_to_government`
- `water_to_industrial`

Le seed est relançable via `ON CONFLICT (key) DO UPDATE`.

## 8. Templates de routes

Ajouts repository :

- `ListRouteTemplates(callback)`
- `GetRouteTemplate(route_key, callback)`

Ajouts service :

- `ListRouteTemplates(callback)`
- `GetRouteTemplate(route_key, callback)`
- `CreateHaulContractFromRoute(creator_character_id, route_key, callback)`

La commande route ne reçoit du client que `route_key`.

Les paramètres critiques viennent de la DB :

- `item_key`
- `item_quantity`
- `reward_money`
- `pickup_location_key`
- `delivery_location_key`

## 9. Commandes /contractroutes /contractrouteinfo /createhaulfromroute

Commandes ajoutées :

- `/contractroutes`
- `/contractrouteinfo <route_key>`
- `/createhaulfromroute <route_key>`

Protection conservée :

- `gr_contracts_debug_commands_enabled`
- `gr_contracts_debug_allowed_platform_ids`

## 10. Intégration avec CreateHaulContract

`CreateHaulContractFromRoute(...)` réutilise `CreateHaulContract(...)`.

Le service :

1. charge la route ;
2. vérifie que la route est active ;
3. réutilise les locations pickup/delivery de la route ;
4. appelle la logique haul existante.

Le MVP n’ajoute pas de colonne `route_key` sur `contracts`.

La provenance de la route est injectée dans la description du contrat :

```txt
[route:<route_key>] ...
```

## 11. Tests PostgreSQL effectués

Commandes exécutées :

```powershell
Get-Content -Raw ".\database\migrations\031_contract_route_templates.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
Get-Content -Raw ".\database\seeds\contract_route_templates_mvp_seed.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, item_key, item_quantity, reward_money, pickup_location_key, delivery_location_key, is_active FROM contract_route_templates ORDER BY key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, name, position_x, position_y, position_z, radius, is_active FROM contract_delivery_locations ORDER BY key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, type, reward_money, status, payment_status, required_item_key, required_item_quantity, pickup_location_key, pickup_status, delivery_location_key FROM contracts ORDER BY id DESC LIMIT 10;"
```

Constats :

- migration `031` appliquée ;
- `4` routes actives présentes ;
- les locations référencées existent ;
- `contracts` reste lisible et inchangé hors création runtime.

## 12. Tests runtime effectués ou restants

Tests runtime non exécutés dans ce lot.

Restent à faire :

```txt
/contractroutes
/contractrouteinfo scrap_to_spatioport
/createhaulfromroute scrap_to_spatioport
/contracts
/acceptcontract 1
/pickupcontract 1
/completecontract 1
```

## 13. Risques restants

- pas de test runtime nanos world exécuté ici ;
- les points pickup/delivery seedés ont toujours des positions `NULL` tant qu’ils ne sont pas calibrés en jeu ;
- le lot suppose que les items seedés (`scrap`, `electronic_component`, `medkit_basic`, `water_bottle`) restent valides dans la DB locale ;
- `git diff --check` ne remonte ici que des warnings `LF -> CRLF`.

## 14. Résultat git status -sb

Résultat obtenu après le lot :

```txt
## feature/issue-126-contract-route-templates
 M server/Packages/gr-chat/Server/Index.lua
 M server/Packages/gr-contracts/Server/ContractRepository.lua
 M server/Packages/gr-contracts/Server/ContractService.lua
 M server/Packages/gr-contracts/Server/Index.lua
?? database/migrations/031_contract_route_templates.sql
?? database/seeds/contract_route_templates_mvp_seed.sql
?? docs/codex-reports/issue-126-contract-route-templates-report.md
```

## 15. Message de commit recommandé

```txt
feat(contracts): add route templates
```
