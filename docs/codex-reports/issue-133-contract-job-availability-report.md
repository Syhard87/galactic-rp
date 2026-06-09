# Issue #133  Contract job availability MVP

## 1. Résumé de limplémentation

Ajout de deux commandes serveur de lisibilité du job board :

- `/availablejobs`
- `/lockedjobs`

La logique reste dans `gr-contracts` et réutilise les prérequis de `#132` sans créer de contrat. Une évaluation unifiée de disponibilité décide si une route est prenable maintenant par le personnage actif.

Documentation relue avant modification :

- `docs/cahier-des-charges.md`
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

- `docs/codex-reports/issue-133-contract-job-availability-report.md`

## 4. Fichiers modifiés

- `server/Packages/gr-contracts/Server/ContractService.lua`
- `server/Packages/gr-contracts/Server/Index.lua`
- `server/Packages/gr-chat/Server/Index.lua`

## 5. Fichiers explicitement non modifiés

- `server/Packages/gr-contracts/Server/ContractRepository.lua`
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

Le schéma et le seed existants de `#132` suffisent pour ce lot.

## 7. Commandes /availablejobs et /lockedjobs

Commandes ajoutées :

- `/availablejobs`
- `/lockedjobs`

`gr-chat` autorise maintenant uniquement :

- `availablejobs`
- `lockedjobs`

## 8. Évaluation des prérequis

Ajout dans `ContractService.lua` :

- `EvaluateJobAvailability(character_id, route_template, callback)`
- `GetAvailableJobs(character_id, callback)`
- `GetLockedJobs(character_id, callback)`

`EvaluateJobAvailability(...)` vérifie :

- route active
- limite de jobs actifs
- prérequis skills/réputation via `CheckJobRequirements(...)`
- pickup existant et actif
- destination existante et active

Structure renvoyée :

- `route`
- `is_available`
- `reasons`
- `missing_requirements`
- `skill_current_level`
- `reputation_current_value`
- `active_job_count`

Raisons normalisées côté affichage :

- `skill commerce niveau 1 requis, niveau actuel=0`
- `reputation faction_x minimum 10 requis, valeur actuelle=0`
- `limite de jobs actifs atteinte`
- `pickup introuvable`
- `destination introuvable`
- `service skill indisponible`
- `service reputation indisponible`

## 9. Impact limite jobs actifs

La limite MVP de `3` jobs actifs est intégrée dans l’évaluation.

Si elle est atteinte :

- aucune route n’apparaît dans `/availablejobs`
- toutes les routes actives concernées peuvent remonter dans `/lockedjobs` avec la raison `limite de jobs actifs atteinte`

La logique de comptage réutilise `is_active_job_contract(...)`.

## 10. Intégration skills/reputation

Réutilisation des bridges existants uniquement :

- `GRSkillsBridge.ListSkills(character_id, callback)`
- `GRReputationBridge.ListCharacterReputations(character_id, callback)`

Le système considère explicitement :

- skill absente pour le personnage => niveau `0`
- réputation absente pour le personnage => valeur `0`

Cela évite de traiter l’absence de ligne DB comme une panne système.

## 11. Tests PostgreSQL effectués

Exécutés :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, item_key, item_quantity, reward_money, required_skill_key, required_skill_level, required_reputation_key, required_reputation_min, is_active FROM contract_route_templates ORDER BY key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT column_name FROM information_schema.columns WHERE table_name = 'character_skills' ORDER BY ordinal_position;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, skill_key, level, xp FROM character_skills ORDER BY character_id, skill_key;"
```

Constats :

- aucune migration nécessaire
- les routes gated utilisent bien `required_skill_key=commerce`
- `character_skills` expose bien `level`
- la DB locale observée ne contient toujours pas de ligne `commerce`, donc le comportement attendu reste `niveau actuel=0`

## 12. Tests runtime effectués ou restants

Runtime non exécuté dans ce lot.

Restent à faire :

```txt
/jobboard
/availablejobs
/lockedjobs
/jobrequirements electronics_to_market
/takejob electronics_to_market
/takejob scrap_to_spatioport
```

## 13. Risques restants

- pas de test runtime nanos world exécuté ici
- aucun outillage local `luac` / `lua` / `luajit` disponible pour validation syntaxique automatique
- `EvaluateJobAvailability(...)` relit les contrats du personnage pour chaque route, ce qui reste acceptable pour le MVP mais n’est pas optimal
- si les services skills ou réputation deviennent indisponibles, les routes concernées seront classées bloquées avec raison système

## 14. Résultat git status -sb

```txt
## feature/issue-133-contract-job-availability
 M server/Packages/gr-chat/Server/Index.lua
 M server/Packages/gr-contracts/Server/ContractService.lua
 M server/Packages/gr-contracts/Server/Index.lua
?? docs/codex-reports/issue-133-contract-job-availability-report.md
```

## 15. Message de commit recommandé

```txt
feat(contracts): add job availability commands
```
