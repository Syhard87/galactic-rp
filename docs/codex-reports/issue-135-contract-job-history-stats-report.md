# Issue #135  Contract job history/stats MVP

## 1. Résumé de limplémentation

Ajout de deux commandes lecture seule dans `gr-contracts` :

- `/jobstats`
- `/jobhistory [limit]`

Le lot donne au joueur une vue serveur de son historique transporteur sans créer de contrat, sans attribuer de reward et sans déclencher de paiement.

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

- `docs/codex-reports/issue-135-contract-job-history-stats-report.md`

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

Aucun seed modifié.

## 7. Commandes /jobstats et /jobhistory

Commandes ajoutées :

- `/jobstats`
- `/jobhistory [limit]`

Allowlist `gr-chat` étendue uniquement avec :

- `jobstats`
- `jobhistory`

## 8. Statistiques joueur

Ajouts côté code :

- `ContractRepository:GetCharacterJobStats(character_id, callback)`
- `ContractService:GetJobStats(character_id, callback)`

Le calcul repose uniquement sur les contrats transport du personnage assigné :

- `source_route_key IS NOT NULL`
- ou `job_source IN ('route_template', 'job_board')`
- ou `requires_pickup_location = true`

Statistiques exposées :

- `completed_count`
- `active_count`
- `cancelled_count`
- `abandoned_count`
- `expired_count`
- `money_earned`
- `granted_skill_xp`
- `success_rate_percentage`

Choix MVP :

- `argent_gagne` additionne seulement les contrats `completed` avec `payment_status = paid`
- `xp_jobs` additionne seulement les contrats avec `rewards_status = granted`
- `abandonnes` côté affichage regroupe les contrats passés en `cancelled`

## 9. Historique joueur

Ajouts côté code :

- `ContractRepository:ListCharacterJobHistory(character_id, limit, callback)`
- `ContractService:GetJobHistory(character_id, limit, callback)`

Règles :

- historique borné entre `1` et `20`
- valeur par défaut `5`
- tri du plus récent au plus ancien via `COALESCE(completed_at, cancelled_at, expired_at, accepted_at, created_at) DESC`

Champs affichés selon le statut :

- `status`
- `route`
- `reward`
- `pickup`
- `destination`
- `rewards`
- `cleanup`
- `error`
- `reason`

## 10. Sécurité / isolation par personnage

Le lot reste strictement lecture seule.

Garanties :

- filtrage repository par `assignee_character_id = character_id`
- aucun contrat d'un autre personnage n'est exposé
- aucune création de contrat
- aucun paiement
- aucune attribution de reward
- aucune écriture DB hors lecture des requêtes SQL

## 11. Tests PostgreSQL effectués

Exécutés :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, status, payment_status, assignee_character_id, reward_money, source_route_key, pickup_location_key, delivery_location_key, rewards_status, reward_skill_xp, cargo_cleanup_status, cancel_reason, created_at FROM contracts ORDER BY id DESC LIMIT 20;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT column_name FROM information_schema.columns WHERE table_name = 'contracts' AND column_name IN ('status','payment_status','reward_money','assignee_character_id','source_route_key','pickup_location_key','delivery_location_key','rewards_status','reward_skill_xp','cargo_cleanup_status','cancel_reason','created_at','completed_at','cancelled_at','expired_at') ORDER BY ordinal_position;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT COUNT(*) AS contract_count, COUNT(*) FILTER (WHERE assignee_character_id IS NOT NULL) AS assigned_count FROM contracts;"
```

Constats :

- aucune migration nécessaire
- les colonnes exploitées par stats/historique sont bien présentes localement
- la base locale observée ne contient pour l'instant qu'un contrat `open` non assigné

## 12. Tests runtime effectués ou restants

Runtime non exécuté dans ce lot.

Restent à faire :

```txt
/jobstats
/jobhistory
/jobhistory 10
/takejob scrap_to_spatioport
/mycontracts
/jobstats
```

## 13. Risques restants

- pas de test runtime nanos world exécuté ici
- aucun outillage local `luac` / `lua` / `luajit` disponible pour validation syntaxique automatique
- la base locale observée contient trop peu de contrats assignés pour valider réellement les agrégats métier en conditions utiles
- `abandonnes` côté affichage correspond au total `cancelled`, ce qui agrège abandon joueur et annulation admin dans le même compteur MVP

## 14. Résultat git status -sb

```txt
## feature/issue-135-contract-job-history-stats
 M server/Packages/gr-chat/Server/Index.lua
 M server/Packages/gr-contracts/Server/ContractRepository.lua
 M server/Packages/gr-contracts/Server/ContractService.lua
 M server/Packages/gr-contracts/Server/Index.lua
?? docs/codex-reports/issue-135-contract-job-history-stats-report.md
```

## 15. Message de commit recommandé

```txt
feat(contracts): add job history stats
```
