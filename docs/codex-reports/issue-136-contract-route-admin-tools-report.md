# Issue #136  Contract route admin tools MVP

## 1. Résumé de limplémentation

Ajout dun outillage admin/debug côté `gr-contracts` pour lister toutes les routes et modifier leur activation, deadline, reward et prérequis skill sans passer par un seed SQL ou une mise à jour manuelle en base.

## 2. Agents consultés

Références de rôle consultées depuis le prompt :

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

## 3. Fichiers créés

- `docs/codex-reports/issue-136-contract-route-admin-tools-report.md`

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

## 7. Commandes admin routes

Commandes ajoutées :

- `/allcontractroutes`
- `/setrouteactive <route_key> <true|false>`
- `/setroutedeadline <route_key> <seconds|none>`
- `/setroutereward <route_key> <reward_money> [reward_skill_xp]`
- `/setrouterequirement <route_key> <skill_key|none> <level>`

## 8. Activation/désactivation de route

Ajout de `UpdateRouteActive(...)` côté repository et `SetRouteActive(...)` côté service.

- validation de `route_key`
- parsing strict de `true|false`
- update ciblé de `contract_route_templates.is_active`
- retour de la route mise à jour

## 9. Réglage deadline

Ajout de `UpdateRouteDeadline(...)` côté repository et `SetRouteDeadline(...)` côté service.

- accepte un entier positif
- accepte `none` pour remettre `deadline_seconds` à `NULL`
- refuse les deadlines négatives ou invalides

## 10. Réglage reward

Ajout de `UpdateRouteReward(...)` côté repository et `SetRouteReward(...)` côté service.

- valide `reward_money >= 0`
- valide `reward_skill_xp >= 0` si fourni
- si `reward_skill_xp` nest pas fourni, la valeur existante de la route est conservée

## 11. Réglage prérequis

Ajout de `UpdateRouteRequirement(...)` côté repository et `SetRouteRequirement(...)` côté service.

- accepte `none 0` pour retirer le prérequis skill
- exige un `level >= 1` si un `skill_key` est fourni
- refuse les clés invalides ou niveaux négatifs

## 12. Sécurité / protection debug

Toutes les nouvelles commandes restent derrière les mêmes settings debug contracts :

- `gr_contracts_debug_commands_enabled`
- `gr_contracts_debug_allowed_platform_ids`

Ajout minimal dans `gr-chat` :

- `allcontractroutes`
- `setrouteactive`
- `setroutedeadline`
- `setroutereward`
- `setrouterequirement`

Sans ouvrir dautres commandes.

## 13. Tests PostgreSQL effectués

Exécutés :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, is_active, reward_money, deadline_seconds, reward_skill_xp, required_skill_key, required_skill_level FROM contract_route_templates ORDER BY key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, is_active, reward_money, deadline_seconds, reward_skill_xp, required_skill_key, required_skill_level FROM contract_route_templates WHERE key='scrap_to_spatioport';"
```

Constats :

- aucune migration nécessaire
- les colonnes requises existent bien
- les routes seedées sont lisibles en base

## 14. Tests runtime effectués ou restants

Runtime non exécuté dans ce lot.

Restent à faire :

```txt
/allcontractroutes
/setrouteactive scrap_to_spatioport true
/setroutedeadline scrap_to_spatioport 3600
/setroutedeadline scrap_to_spatioport none
/setroutereward scrap_to_spatioport 300 75
/setrouterequirement electronics_to_market commerce 1
/setrouterequirement electronics_to_market none 0
/jobboard
/jobrequirements electronics_to_market
```

## 15. Risques restants

- pas de test runtime nanos world exécuté ici
- aucun `lua`, `luac` ou `luajit` local disponible pour validation syntaxique automatique
- `setroutereward` conserve lXP existante si le second argument est omis, ce qui est volontaire mais doit être connu côté admin
- `git diff --check` ne remonte ici que des warnings `LF -> CRLF`

## 16. Résultat git status -sb

```txt
## feature/issue-136-contract-route-admin-tools
 M server/Packages/gr-chat/Server/Index.lua
 M server/Packages/gr-contracts/Server/ContractRepository.lua
 M server/Packages/gr-contracts/Server/ContractService.lua
 M server/Packages/gr-contracts/Server/Index.lua
```

## 17. Message de commit recommandé

```txt
feat(contracts): add route admin tools
```
