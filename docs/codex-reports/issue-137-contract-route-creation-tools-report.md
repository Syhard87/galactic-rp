# Issue #137  Contract route creation tools MVP

## 1. Résumé de limplémentation

Ajout de deux commandes admin/debug dans `gr-contracts` pour créer une route de transport et modifier sa description directement depuis le serveur, sans migration ni modification du seed.

## 2. Agents consultés

Références de rôle utilisées depuis le prompt :

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
- `docs/codex-reports/issue-126-contract-route-templates-report.md`
- `docs/codex-reports/issue-136-contract-route-admin-tools-report.md`

## 3. Fichiers créés

- `docs/codex-reports/issue-137-contract-route-creation-tools-report.md`

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

Aucune migration ajoutée.

## 7. Commandes /createroute et /setroutedescription

Commandes ajoutées :

- `/createroute <route_key> <item_key> <quantity> <reward_money> <pickup_location_key> <delivery_location_key> <description>`
- `/setroutedescription <route_key> <description>`

## 8. Création de route

Ajouts repository :

- `CreateRouteTemplate(route, callback)`

Ajouts service :

- `CreateRouteTemplate(route_key, item_key, quantity, reward_money, pickup_location_key, delivery_location_key, description, callback)`

Règles appliquées :

- `route_key` validé et autorisé avec lettres, chiffres, `_`, `-`
- `item_key` validé
- `quantity > 0` et `<= 1000`
- `reward_money >= 0` et `<= 1000000`
- vérification pickup existant et actif
- vérification destination existante et active
- refus si route déjà existante
- création avec valeurs par défaut propres :
  - `is_active=true`
  - `deadline_seconds=NULL`
  - rewards RPG à `NULL/0`
  - prérequis à `NULL/0`

## 9. Mise à jour description

Ajouts repository :

- `UpdateRouteDescription(route_key, description, callback)`

Ajouts service :

- `SetRouteDescription(route_key, description, callback)`

La mise à jour ne touche que :

- `description`
- `updated_at`

## 10. Sécurité / protection debug

Les deux commandes restent derrière les mêmes settings debug contracts :

- `gr_contracts_debug_commands_enabled`
- `gr_contracts_debug_allowed_platform_ids`

Ajout minimal dans `gr-chat` :

- `createroute`
- `setroutedescription`

Sans ouvrir dautres commandes.

## 11. Tests PostgreSQL effectués

Exécuté :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, item_key, item_quantity, reward_money, pickup_location_key, delivery_location_key, is_active, description FROM contract_route_templates ORDER BY key;"
```

Constats :

- aucune migration nécessaire
- les colonnes attendues existent déjà
- les routes seedées restent lisibles en base

## 12. Tests runtime effectués ou restants

Runtime non exécuté dans ce lot.

Restent à faire :

```txt
/allcontractroutes
/createroute fuel_to_spatioport fuel_cell 3 450 industrial_zone spatioport Transporter du carburant au spatioport
/setroutedescription fuel_to_spatioport Livraison prioritaire de carburant
/allcontractroutes
/jobboard
/jobinfo fuel_to_spatioport
/takejob fuel_to_spatioport
```

## 13. Risques restants

- pas de test runtime nanos world exécuté ici
- aucun `lua`, `luac` ou `luajit` local disponible pour validation syntaxique automatique
- le `name` de route est initialisé à `route_key` par défaut, sans édition dédiée dans ce lot
- les erreurs DB basses hors cas de doublon restent agrégées en `database-error`
- `git diff --check` ne remonte ici que des warnings `LF -> CRLF`

## 14. Résultat git status -sb

```txt
## feature/issue-137-contract-route-creation-tools
 M server/Packages/gr-chat/Server/Index.lua
 M server/Packages/gr-contracts/Server/ContractRepository.lua
 M server/Packages/gr-contracts/Server/ContractService.lua
 M server/Packages/gr-contracts/Server/Index.lua
?? docs/codex-reports/issue-137-contract-route-creation-tools-report.md
```

## 15. Message de commit recommandé

```txt
feat(contracts): add route creation tools
```
