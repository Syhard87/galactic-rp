# Issue #142  Contract route auto availability MVP

## 1. Résumé de limplémentation

Le job board public filtre maintenant automatiquement les routes non jouables. Une route active mais invalide, y compris forcée active via `/forcerouteactive`, reste visible dans les diagnostics admin mais n’est plus proposée ni prenable côté joueur.

## 2. Agents consultés

- `software-architect`
- `backend-lua`
- `database-engineer`
- `security-reviewer`
- `qa-tester`
- `nanos-world-lua-agent`

Documentation nanos world relue avant modification :
- `docs/cahier-des-charges.md`
- `external/nanos-world-docs/docs/core-concepts/packages/packages-guide.md`
- `external/nanos-world-docs/docs/core-concepts/scripting/communicating-between-packages.md`

## 3. Fichiers créés

- `docs/codex-reports/issue-142-contract-route-auto-availability-report.md`

## 4. Fichiers modifiés

- `server/Packages/gr-contracts/Server/ContractService.lua`
- `server/Packages/gr-contracts/Server/Index.lua`

## 5. Fichiers explicitement non modifiés

- `server/Packages/gr-contracts/Server/ContractRepository.lua`
- `server/Packages/gr-chat/Server/Index.lua`
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

## 6. Migration SQL ajoutée ou non

Aucune migration ajoutée.

## 7. Filtrage job board

Ajouts service :
- `IsRoutePlayable(route_key_or_route, callback)`
- `FilterPlayableRoutes(route_templates, callback)`

Adaptations :
- `ListJobBoardRoutes(...)` filtre maintenant les routes via le diagnostic `#138`
- une route doit être :
  - active
  - valide
  - calibrée
  - techniquement jouable

Les routes invalides restent visibles dans :
- `/allcontractroutes`
- `/routehealth`
- `/validateroute`
- `/invalidroutes`
- `/contractlocationhealth`

Mais elles ne remontent plus dans `/jobboard`.

## 8. Refus takejob/createhaulfromroute sur route invalide

Adaptations :
- `TakeJobFromRoute(...)`
- `CreateHaulContractFromRoute(...)`
- `GetJobRequirements(...)`

Avant toute création de contrat, le service vérifie maintenant `IsRoutePlayable(...)`.

Si la route est invalide :
- aucun contrat n’est créé
- le service retourne `route-unavailable`
- les commandes affichent :
  - `Mission impossible : route indisponible.`
  - puis la liste des issues

## 9. Impact availablejobs/lockedjobs/jobinfo

`EvaluateJobAvailability(...)` réutilise désormais le diagnostic de route au lieu de refaire des checks partiels pickup/delivery.

Conséquences :
- `/availablejobs` n’inclut jamais une route techniquement invalide
- `/lockedjobs` distingue :
  - `bloque` pour les prérequis joueur / limite
  - `indisponible` pour une route techniquement non jouable
- `/jobinfo <route_key>` affiche `INDISPONIBLE` avec issues si la route est active mais invalide
- `/jobrequirements <route_key>` refuse aussi les routes non jouables avant le check des prérequis

## 10. Sécurité joueur

- une route forcée active mais invalide ne devient pas prenable côté joueur
- aucune commande de listing joueur ne crée de contrat
- aucune commande joueur ne masque les diagnostics admin
- la logique de validation n’est pas dupliquée : elle réutilise `ValidateRouteTemplate(...)` et `EvaluateRouteTemplateHealth(...)`

## 11. Tests PostgreSQL effectués

Exécutés :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, is_active, pickup_location_key, delivery_location_key, item_key, item_quantity, reward_money FROM contract_route_templates ORDER BY key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, is_active, position_x, position_y, position_z, radius FROM contract_delivery_locations ORDER BY key;"
```

Constats :
- aucune migration nécessaire
- les 4 routes existantes sont toujours actives en base
- les 5 locations existent
- les `position_x/y/z` observées sont toujours `NULL`, donc les routes restent techniquement non calibrées tant que ces positions ne sont pas renseignées

## 12. Tests runtime effectués ou restants

Runtime non exécuté dans ce lot.

Restent à faire :

```txt
/validateroute fuel_to_spatioport
/forcerouteactive fuel_to_spatioport true
/jobboard
/availablejobs
/lockedjobs
/jobinfo fuel_to_spatioport
/takejob fuel_to_spatioport
```

## 13. Risques restants

- pas de test runtime nanos world exécuté ici
- aucun `lua`, `luac` ou `luajit` local disponible pour validation syntaxique automatique
- tant que les locations restent sans positions, le job board joueur peut légitimement devenir vide
- `GetJobBoardRoute(...)` laisse toujours la route consultable par clé pour `/jobinfo`, ce qui est voulu pour exposer `INDISPONIBLE` sans la proposer
- `git diff --check` peut encore ne remonter que des warnings `LF -> CRLF`

## 14. Résultat git status -sb

```txt
## feature/issue-142-contract-route-auto-availability
 M server/Packages/gr-contracts/Server/ContractService.lua
 M server/Packages/gr-contracts/Server/Index.lua
?? docs/codex-reports/issue-142-contract-route-auto-availability-report.md
```

## 15. Message de commit recommandé

```txt
feat(contracts): filter unavailable routes
```
