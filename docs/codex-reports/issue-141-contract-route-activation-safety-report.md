# Issue #141  Contract route activation safety MVP

## 1. Résumé de limplémentation

Activation sécurisée des routes ajoutée dans `gr-contracts` :
- `/setrouteactive <route_key> true` valide maintenant la route avant activation ;
- `/setrouteactive <route_key> false` désactive toujours directement ;
- `/forcerouteactive <route_key> <true|false>` conserve un chemin admin explicite sans blocage diagnostic ;
- `/createroute` crée désormais les nouvelles routes avec `is_active=false` par défaut.

## 2. Agents consultés

Références de rôle suivies depuis le prompt :
- `software-architect`
- `backend-lua`
- `database-engineer`
- `security-reviewer`
- `qa-tester`
- `nanos-world-lua-agent`

Documentation nanos world relue avant modification :
- `external/nanos-world-docs/docs/core-concepts/packages/packages-guide.md`
- `external/nanos-world-docs/docs/core-concepts/scripting/communicating-between-packages.md`

## 3. Fichiers créés

- `docs/codex-reports/issue-141-contract-route-activation-safety-report.md`

## 4. Fichiers modifiés

- `server/Packages/gr-contracts/Server/ContractRepository.lua`
- `server/Packages/gr-contracts/Server/ContractService.lua`
- `server/Packages/gr-contracts/Server/Index.lua`
- `server/Packages/gr-chat/Server/Index.lua`

## 5. Fichiers explicitement non modifiés

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

Aucune migration SQL ajoutée.

## 7. Activation sécurisée des routes

`ContractService:SetRouteActive(...)` a été adapté :
- si `is_active=false`, la désactivation passe directement ;
- si `is_active=true`, le service appelle `ValidateRouteTemplate(...)` ;
- si la route est invalide, lactivation est refusée avec `route-invalid` et la liste des issues ;
- si la route est valide, `UpdateRouteActive(...)` est exécuté.

La logique de diagnostic réutilisée vient de `#138` :
- `ValidateRouteTemplate`
- `EvaluateRouteTemplateHealth`

## 8. Commande /forcerouteactive

Nouvelle commande admin/debug :
- `/forcerouteactive <route_key> <true|false>`

Ajouts associés :
- `ContractService:ForceSetRouteActive(...)`
- `GRContractsBridge.ForceSetRouteActive(...)`
- allowlist `gr-chat` mise à jour avec `forcerouteactive`

Cette commande ne bloque pas sur le diagnostic et affiche `force=true`.

## 9. Création de routes inactives par défaut

`ContractService:CreateRouteTemplate(...)` transmet désormais :
- `is_active = false`

`ContractRepository:CreateRouteTemplate(...)` et la requête SQL dinsert ont été adaptés pour accepter la valeur `is_active` au lieu de forcer `true`.

Conséquence :
- une nouvelle route est créée inactive ;
- ladmin doit ensuite lancer `/validateroute` puis `/setrouteactive ... true`.

## 10. Sécurité / protection debug

Les commandes de modification restent protégées par :
- `gr_contracts_debug_commands_enabled`
- `gr_contracts_debug_allowed_platform_ids`

Règles de sécurité conservées :
- pas de création de contrat ;
- pas de modification automatique de location ;
- pas de calibration automatique ;
- pas de suppression de route.

## 11. Tests PostgreSQL effectués

Exécuté :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, is_active, pickup_location_key, delivery_location_key, item_key, item_quantity, reward_money FROM contract_route_templates ORDER BY key;"
```

Constats :
- aucune migration nécessaire ;
- les 4 routes seedées existent toujours ;
- elles sont actuellement actives en base ;
- les locations associées restent celles attendues.

## 12. Tests runtime effectués ou restants

Runtime non exécuté dans ce lot.

Reste à tester :

```txt
/createroute test_safety_route scrap 1 100 industrial_zone spatioport Route test safety
/validateroute test_safety_route
/setrouteactive test_safety_route true
/forcerouteactive test_safety_route true
/setrouteactive test_safety_route false
/routehealth
/jobboard
```

## 13. Risques restants

- pas de test runtime nanos world exécuté ici ;
- aucun `lua`, `luac` ou `luajit` local disponible pour validation syntaxique automatique ;
- les locations observées localement ont encore des positions `NULL`, donc une activation sécurisée peut refuser des routes tant que la calibration na pas été faite ;
- `git diff --check` risque de remonter uniquement des warnings `LF -> CRLF` selon les fichiers touchés.

## 14. Résultat git status -sb

```txt
## feature/issue-141-contract-route-activation-safety
 M server/Packages/gr-chat/Server/Index.lua
 M server/Packages/gr-contracts/Server/ContractRepository.lua
 M server/Packages/gr-contracts/Server/ContractService.lua
 M server/Packages/gr-contracts/Server/Index.lua
?? docs/codex-reports/issue-141-contract-route-activation-safety-report.md
```

## 15. Message de commit recommandé

```txt
feat(contracts): add route activation safety
```
