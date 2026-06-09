# Issue #139  Contract location admin tools MVP

## 1. Resume de limplementation

Ajout de commandes admin/debug dans `gr-contracts` pour creer et administrer les locations de `contract_delivery_locations` depuis le serveur, sans migration ni modification des seeds.

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
- `docs/codex-reports/issue-137-contract-route-creation-tools-report.md`
- `docs/codex-reports/issue-138-contract-route-diagnostics-report.md`

## 3. Fichiers crees

- `docs/codex-reports/issue-139-contract-location-admin-tools-report.md`

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

## 7. Commandes admin locations

Commandes ajoutees :

- `/allcontractlocations`
- `/createcontractlocation <location_key> <radius> <name>`
- `/setcontractlocationactive <location_key> <true|false>`
- `/setcontractlocationradius <location_key> <radius>`
- `/setcontractlocationname <location_key> <name>`

## 8. Creation de location

Ajouts repository :

- `ListAllContractLocations(callback)`
- `CreateContractLocation(location, callback)`

Ajouts service :

- `ListAllContractLocations(callback)`
- `CreateContractLocation(location_key, radius, name, callback)`

Regles appliquees :

- `location_key` valide
- `radius > 0` et `<= 100000`
- `name` non vide et borne
- refus si la location existe deja
- creation active par defaut
- position laissee a `NULL`

## 9. Activation/radius/name

Ajouts repository :

- `UpdateContractLocationActive(location_key, is_active, callback)`
- `UpdateContractLocationRadius(location_key, radius, callback)`
- `UpdateContractLocationName(location_key, name, callback)`

Ajouts service :

- `SetContractLocationActive(location_key, is_active, callback)`
- `SetContractLocationRadius(location_key, radius, callback)`
- `SetContractLocationName(location_key, name, callback)`

La position nest pas modifiee dans ce lot. Elle reste geree par :

- `/setdeliverylocationhere`

## 10. Securite / protection debug

Toutes les nouvelles commandes restent derriere :

- `gr_contracts_debug_commands_enabled`
- `gr_contracts_debug_allowed_platform_ids`

Ajout minimal dans `gr-chat` :

- `allcontractlocations`
- `createcontractlocation`
- `setcontractlocationactive`
- `setcontractlocationradius`
- `setcontractlocationname`

Aucune suppression physique de location.
Aucune modification automatique de route.

## 11. Tests PostgreSQL effectues

Executes :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, name, is_active, position_x, position_y, position_z, radius FROM contract_delivery_locations ORDER BY key;"
```

Constats :

- aucune migration necessaire
- les colonnes attendues existent deja
- les 5 locations seedees sont presentes
- les positions restent actuellement `NULL` sur les locations observees

## 12. Tests runtime effectues ou restants

Runtime non execute dans ce lot.

Restent a faire :

```txt
/allcontractlocations
/createcontractlocation fuel_depot 500 Depot de carburant
/setcontractlocationname fuel_depot Depot carburant prioritaire
/setcontractlocationradius fuel_depot 750
/setcontractlocationactive fuel_depot true
/deliverylocationinfo fuel_depot
/setdeliverylocationhere fuel_depot 750
/deliverylocationinfo fuel_depot
/routehealth
```

## 13. Risques restants

- pas de test runtime nanos world execute ici
- aucun `lua`, `luac` ou `luajit` local disponible pour validation syntaxique automatique
- les nouvelles commandes admin ne verifient pas encore un usage par des routes existantes, ce qui est volontaire dans ce lot
- `git diff --check` peut encore remonter des warnings `LF -> CRLF`

## 14. Resultat git status -sb

```txt
## feature/issue-139-contract-location-admin-tools
 M server/Packages/gr-chat/Server/Index.lua
 M server/Packages/gr-contracts/Server/ContractRepository.lua
 M server/Packages/gr-contracts/Server/ContractService.lua
 M server/Packages/gr-contracts/Server/Index.lua
?? docs/codex-reports/issue-139-contract-location-admin-tools-report.md
```

## 15. Message de commit recommande

```txt
feat(contracts): add location admin tools
```
