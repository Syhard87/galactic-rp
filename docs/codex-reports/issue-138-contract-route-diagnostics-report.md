# Issue #138  Contract route diagnostics MVP

## 1. Resume de limplementation

Ajout de trois commandes admin/debug en lecture seule dans `gr-contracts` pour diagnostiquer les routes de transport, lister les routes invalides et resumer la sante globale des routes sans modifier la base.

## 2. Agents consultes

References de role utilisees depuis le prompt :

- `software-architect`
- `backend-lua`
- `database-engineer`
- `security-reviewer`
- `qa-tester`
- `nanos-world-lua-agent.md`

Documentation lue avant modification :

- `docs/cahier-des-charges.md`
- `external/nanos-world-docs/docs/core-concepts/packages/packages-guide.md`
- `external/nanos-world-docs/docs/core-concepts/scripting/communicating-between-packages.md`
- `docs/codex-reports/issue-123-contract-delivery-locations-report.md`
- `docs/codex-reports/issue-124-contract-delivery-location-tools-report.md`
- `docs/codex-reports/issue-126-contract-route-templates-report.md`
- `docs/codex-reports/issue-136-contract-route-admin-tools-report.md`
- `docs/codex-reports/issue-137-contract-route-creation-tools-report.md`

## 3. Fichiers crees

- `docs/codex-reports/issue-138-contract-route-diagnostics-report.md`

## 4. Fichiers modifies

- `server/Packages/gr-contracts/Server/ContractRepository.lua`
- `server/Packages/gr-contracts/Server/ContractService.lua`
- `server/Packages/gr-contracts/Server/Index.lua`
- `server/Packages/gr-chat/Server/Index.lua`

## 5. Fichiers explicitement non modifies

- `database/migrations/`
- `database/seeds/`
- `server/Packages/gr-skills/`
- `server/Packages/gr-progression/`
- `server/Packages/gr-reputation/`
- `server/Packages/gr-inventory/`
- `server/Packages/gr-economy/`
- `server/Packages/gr-gathering/`
- `server/Packages/gr-shops/`
- `Config.toml`

## 6. Migration SQL ajoutee ou non

Aucune migration ajoutee.

## 7. Commandes /routehealth /validateroute /invalidroutes

Commandes ajoutees :

- `/routehealth`
- `/validateroute <route_key>`
- `/invalidroutes`

## 8. Diagnostic des routes

Ajouts service :

- `EvaluateRouteTemplateHealth(route_template, pickup_location, delivery_location, raw_route)`
- `ValidateRouteTemplate(route_key, callback)`
- `GetRouteHealth(callback)`
- `ListInvalidRoutes(callback)`

Checks MVP couverts :

- `route_key` non vide
- `item_key` non vide
- `item_quantity > 0`
- `reward_money >= 0`
- `deadline_seconds` nul ou strictement positif
- `reward_skill_xp >= 0`
- `required_skill_level >= 0`
- `required_reputation_min >= 0`
- `pickup_location_key` non vide
- `delivery_location_key` non vide

Le service retourne :

- `route`
- `is_valid`
- `issues`
- `issue_codes`
- `is_uncalibrated`
- `pickup_location`
- `delivery_location`

## 9. Diagnostic pickup/delivery

Ajout repository :

- `ListRouteTemplatesWithLocations(include_inactive, callback)`

Le diagnostic verifie aussi :

- pickup existant
- destination existante
- pickup actif
- destination active
- pickup calibre avec `position_x/y/z`
- destination calibree avec `position_x/y/z`
- pickup `radius > 0`
- destination `radius > 0`

Les codes techniques sont traduits en messages lisibles, par exemple :

- `pickup non calibre`
- `destination non calibree`
- `pickup introuvable`
- `destination introuvable`

## 10. Securite / lecture seule

Les nouvelles commandes restent derriere les memes settings debug contracts :

- `gr_contracts_debug_commands_enabled`
- `gr_contracts_debug_allowed_platform_ids`

Le lot reste strictement en lecture seule :

- aucune creation de contrat
- aucune creation de route
- aucune mise a jour de route
- aucune correction automatique
- aucune ecriture DB

Ajout minimal dans `gr-chat` :

- `routehealth`
- `validateroute`
- `invalidroutes`

## 11. Tests PostgreSQL effectues

Executes :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, is_active, item_key, item_quantity, reward_money, pickup_location_key, delivery_location_key, deadline_seconds FROM contract_route_templates ORDER BY key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, is_active, position_x, position_y, position_z, radius FROM contract_delivery_locations ORDER BY key;"
```

Constats :

- aucune migration necessaire
- `contract_route_templates` contient 4 routes actives
- `contract_delivery_locations` contient 5 locations actives
- les positions `position_x/y/z` sont actuellement `NULL` sur les locations observees
- les routes seront donc diagnostiquees comme non calibrees tant que ces positions restent nulles

## 12. Tests runtime effectues ou restants

Runtime non execute dans ce lot.

Restent a faire :

```txt
/routehealth
/validateroute scrap_to_spatioport
/invalidroutes
/deliverylocationinfo spatioport
/setdeliverylocationhere spatioport 500
/routehealth
```

## 13. Risques restants

- pas de test runtime nanos world execute ici
- aucun `lua`, `luac` ou `luajit` local disponible pour validation syntaxique automatique
- pas de verification dun vrai catalogue ditems dans ce lot
- les diagnostics reposent sur les locations en base ; tant que les positions restent nulles, les routes apparaissent non calibrees
- `git diff --check` peut encore remonter des warnings `LF -> CRLF`

## 14. Resultat git status -sb

```txt
## feature/issue-138-contract-route-diagnostics
 M server/Packages/gr-chat/Server/Index.lua
 M server/Packages/gr-contracts/Server/ContractRepository.lua
 M server/Packages/gr-contracts/Server/ContractService.lua
 M server/Packages/gr-contracts/Server/Index.lua
?? docs/codex-reports/issue-138-contract-route-diagnostics-report.md
```

## 15. Message de commit recommande

```txt
feat(contracts): add route diagnostics
```
