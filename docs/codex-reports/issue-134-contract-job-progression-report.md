# Issue #134  Contract job progression MVP

## 1. Résumé de limplémentation

Ajout de deux commandes lecture seule dans `gr-contracts` :

- `/jobprogress`
- `/jobunlocks`

Le lot améliore la lisibilité de la progression liée au job board sans créer de contrat, sans attribuer d’XP et sans modifier les prérequis existants. La logique réutilise les évaluations déjà en place dans `#133`.

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

- `docs/codex-reports/issue-134-contract-job-progression-report.md`

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

Aucun seed modifié.

## 7. Commandes /jobprogress et /jobunlocks

Commandes ajoutées :

- `/jobprogress`
- `/jobunlocks`

Allowlist `gr-chat` étendue uniquement avec :

- `jobprogress`
- `jobunlocks`

## 8. Progression métier affichée

Ajout de `ContractService:GetJobProgress(character_id, callback)`.

La méthode :

- charge les routes actives ;
- extrait les skills requis distincts ;
- lit les skills du personnage via `GRSkillsBridge.ListSkills(...)` ;
- affiche un skill absent comme `niveau=0 xp=0` ;
- compte les missions disponibles et bloquées via la logique `#133` ;
- compte les jobs actifs du personnage.

Structure renvoyée :

- `skills`
- `has_required_skills`
- `available_count`
- `locked_count`
- `active_job_count`
- `max_active_job_count`

## 9. Déblocages de missions

Ajout de `ContractService:GetJobUnlocks(character_id, callback)`.

La méthode :

- réutilise `GetLockedJobs(...)` ;
- filtre uniquement les blocages liés aux prérequis skill/réputation ;
- ignore les routes bloquées seulement par la limite de jobs actifs ;
- expose `unlock_reasons` pour l’affichage.

Exemples de sortie visée :

- `electronics_to_market : skill commerce niveau 1 requis, niveau actuel=0`
- `medical_to_government : skill commerce niveau 2 requis, niveau actuel=0`

## 10. Intégration skills/reputation

Bridges réutilisés :

- `GRSkillsBridge.ListSkills(character_id, callback)`
- `GRReputationBridge.ListCharacterReputations(character_id, callback)`

Règles conservées :

- aucun skill n’est créé automatiquement ;
- aucune XP n’est donnée ;
- aucune réputation n’est modifiée ;
- skill absente pour le personnage => niveau `0`, xp `0`.

## 11. Tests PostgreSQL effectués

Exécutés :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, required_skill_key, required_skill_level, required_reputation_key, required_reputation_min, is_active FROM contract_route_templates ORDER BY key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT * FROM character_skills ORDER BY character_id, skill_key LIMIT 20;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, skill_key, level, xp FROM character_skills ORDER BY character_id, skill_key;"
```

Constats :

- aucune migration nécessaire
- les routes actives gated utilisent toujours `required_skill_key=commerce`
- la table `character_skills` expose bien `level`, `xp`, `current_xp`, `total_xp`
- la DB locale observée ne contient toujours pas de ligne `commerce`, donc l’affichage attendu reste `niveau=0 xp=0`

## 12. Tests runtime effectués ou restants

Runtime non exécuté dans ce lot.

Restent à faire :

```txt
/jobprogress
/jobunlocks
/availablejobs
/lockedjobs
/jobrequirements electronics_to_market
```

## 13. Risques restants

- pas de test runtime nanos world exécuté ici
- aucun outillage local `luac` / `lua` / `luajit` disponible pour validation syntaxique automatique
- tant que `commerce` reste absent de `character_skills`, les routes gated resteront affichées comme bloquées avec niveau actuel `0`
- `GetJobProgress(...)` s’appuie sur `GetAvailableJobs(...)` et `GetLockedJobs(...)`, donc il réévalue les routes plusieurs fois ; acceptable pour le MVP, pas optimal

## 14. Résultat git status -sb

```txt
## feature/issue-134-contract-job-progression
 M server/Packages/gr-chat/Server/Index.lua
 M server/Packages/gr-contracts/Server/ContractService.lua
 M server/Packages/gr-contracts/Server/Index.lua
?? docs/codex-reports/issue-134-contract-job-progression-report.md
```

## 15. Message de commit recommandé

```txt
feat(contracts): add job progression commands
```
