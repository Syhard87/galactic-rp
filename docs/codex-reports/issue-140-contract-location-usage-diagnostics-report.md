# Issue #140  Contract location usage diagnostics MVP

## 1. Resume de limplementation

Ajout de trois commandes admin/debug en lecture seule dans `gr-contracts` pour diagnostiquer lusage des locations par les routes, evaluer limpact d'une location sur les routes qui lutilisent, et lister les locations inutilisees.

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
- `docs/codex-reports/issue-138-contract-route-diagnostics-report.md`
- `docs/codex-reports/issue-139-contract-location-admin-tools-report.md`
- `database/migrations/029_contract_delivery_locations.sql`
- `database/migrations/031_contract_route_templates.sql`
- `database/seeds/contract_delivery_locations_mvp_seed.sql`
- `database/seeds/contract_route_templates_mvp_seed.sql`

## 3. Fichiers crees

- `docs/codex-reports/issue-140-contract-location-usage-diagnostics-report.md`

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

## 7. Commandes /contractlocationroutes /contractlocationhealth /unusedcontractlocations

Commandes ajoutees :

- `/contractlocationroutes <location_key>`
- `/contractlocationhealth <location_key>`
- `/unusedcontractlocations`

## 8. Diagnostic usage location

Ajouts repository :

- `ListRoutesUsingLocation(location_key, callback)`

Ajouts service :

- `GetContractLocationRoutes(location_key, callback)`

Regles appliquees :

- recherche des routes avec `pickup_location_key = location_key`
- recherche des routes avec `delivery_location_key = location_key`
- calcul du type dusage :
  - `pickup`
  - `destination`
  - `pickup,destination`

## 9. Diagnostic health location

Ajouts service :

- `GetContractLocationHealth(location_key, callback)`

Le diagnostic retourne :

- location active/inactive
- location calibree ou non
- radius valide ou non
- `routes_total`
- `routes_active`
- `routes_invalides`
- liste des routes impactees

Le comptage des routes invalides liees a une location reutilise la logique `EvaluateRouteTemplateHealth(...)` de `#138` pour rester coherent avec `/routehealth` et `/validateroute`.

## 10. Locations inutilisees

Ajouts repository :

- `ListUnusedContractLocations(callback)`

Ajouts service :

- `ListUnusedContractLocations(callback)`

La liste des locations inutilisees est calculee en lecture seule a partir de :

- toutes les locations existantes
- toutes les routes et leurs `pickup_location_key` / `delivery_location_key`

## 11. Securite / lecture seule

Les nouvelles commandes restent derriere :

- `gr_contracts_debug_commands_enabled`
- `gr_contracts_debug_allowed_platform_ids`

Le lot reste strictement en lecture seule :

- aucune creation de contrat
- aucune creation de route
- aucune creation de location
- aucune modification DB
- aucune correction automatique

Ajout minimal dans `gr-chat` :

- `contractlocationroutes`
- `contractlocationhealth`
- `unusedcontractlocations`

## 12. Tests PostgreSQL effectues

Executes :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, name, is_active, position_x, position_y, position_z, radius FROM contract_delivery_locations ORDER BY key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, is_active, pickup_location_key, delivery_location_key, item_key, item_quantity, reward_money FROM contract_route_templates ORDER BY key;"
```

Constats :

- aucune migration necessaire
- 5 locations presentes
- 4 routes presentes
- toutes les locations actuellement seedees sont utilisees par au moins une route
- les positions restent `NULL`, donc les locations sont actuellement non calibrees

## 13. Tests runtime effectues ou restants

Runtime non execute dans ce lot.

Restent a faire :

```txt
/allcontractlocations
/contractlocationroutes spatioport
/contractlocationhealth spatioport
/unusedcontractlocations
/routehealth
/validateroute scrap_to_spatioport
```

## 14. Risques restants

- pas de test runtime nanos world execute ici
- aucun `lua`, `luac` ou `luajit` local disponible pour validation syntaxique automatique
- le diagnostic de location sappuie sur letat actuel des routes et locations, donc tant que les positions restent `NULL`, les routes resteront signalees comme non calibrees
- `git diff --check` peut encore remonter des warnings `LF -> CRLF`

## 15. Resultat git status -sb

```txt
## feature/issue-140-contract-location-usage-diagnostics
 M server/Packages/gr-chat/Server/Index.lua
 M server/Packages/gr-contracts/Server/ContractRepository.lua
 M server/Packages/gr-contracts/Server/ContractService.lua
 M server/Packages/gr-contracts/Server/Index.lua
?? docs/codex-reports/issue-140-contract-location-usage-diagnostics-report.md
```

## 16. Message de commit recommande

```txt
feat(contracts): add location usage diagnostics
```
