# Issue #132  Contract job requirements MVP

## 1. Résumé de limplémentation

Ajout de prérequis serveur sur les `contract_route_templates` pour filtrer les missions du job board avant création du contrat. Le contrôle est effectué côté `gr-contracts` avant `TakeJobFromRoute`, à partir des données de route stockées en base.

## 2. Agents consultés

- `software-architect`
- `backend-lua`
- `database-engineer`
- `security-reviewer`
- `qa-tester`
- `nanos-world-lua-agent`

## 3. Fichiers créés

- `database/migrations/037_contract_job_requirements.sql`
- `docs/codex-reports/issue-132-contract-job-requirements-report.md`

## 4. Fichiers modifiés

- `database/seeds/contract_route_templates_mvp_seed.sql`
- `server/Packages/gr-contracts/Server/ContractRepository.lua`
- `server/Packages/gr-contracts/Server/ContractService.lua`
- `server/Packages/gr-contracts/Server/Index.lua`
- `server/Packages/gr-chat/Server/Index.lua`

## 5. Fichiers explicitement non modifiés

- `server/Packages/gr-skills/`
- `server/Packages/gr-progression/`
- `server/Packages/gr-reputation/`
- `server/Packages/gr-inventory/`
- `server/Packages/gr-economy/`
- `server/Packages/gr-gathering/`
- `server/Packages/gr-shops/`
- `Config.toml`

## 6. Migration SQL ajoutée

Ajout de `database/migrations/037_contract_job_requirements.sql` avec :

- `required_skill_key`
- `required_skill_level`
- `required_reputation_key`
- `required_reputation_min`

sur `contract_route_templates`, plus :

- contrainte `required_skill_level >= 0`
- index `idx_contract_route_templates_required_skill`
- index `idx_contract_route_templates_required_reputation`

## 7. Seed route templates adapté

Le seed `database/seeds/contract_route_templates_mvp_seed.sql` a été mis à jour pour définir des prérequis MVP relançables.

Point important :

- la skill `transport` n'existe pas dans `gr-skills`
- le fallback retenu est `commerce`

Pré-requis seedés :

- `scrap_to_spatioport` : aucun
- `water_to_industrial` : aucun
- `electronics_to_market` : `required_skill_key=commerce`, `required_skill_level=1`
- `medical_to_government` : `required_skill_key=commerce`, `required_skill_level=2`

Aucun prérequis réputation n'a été seedé dans ce lot.

## 8. Prérequis de mission

Les templates de route normalisent maintenant :

- `required_skill_key`
- `required_skill_level`
- `required_reputation_key`
- `required_reputation_min`

`ContractService:CheckJobRequirements(...)` :

- récupère le niveau skill courant via `GRSkillsBridge.ListSkills(...)`
- récupère la réputation courante via `GRReputationBridge.ListCharacterReputations(...)`
- retourne :
  - `is_met`
  - `missing_requirements`
  - `skill_current_level`
  - `reputation_current_value`

## 9. Commande /jobrequirements

Commande ajoutée :

- `/jobrequirements <route_key>`

Comportement :

- affiche les prérequis de la mission
- affiche `OK` si le personnage actif les remplit
- affiche le détail du manque sinon

## 10. Impact /jobboard et /jobinfo

`/jobboard`, `/jobinfo`, `/contractroutes` et `/contractrouteinfo` affichent maintenant les prérequis de manière compacte avec :

- `req_skill=<skill>:<level>`
- `req_rep=<reputation>:<minimum>`

quand ces valeurs sont définies.

## 11. Impact /takejob

`/takejob <route_key>` vérifie les prérequis avant création du contrat.

Si les prérequis ne sont pas remplis :

- aucun contrat n'est créé
- aucun contrat n'est assigné
- message joueur : `Mission impossible : prerequis non remplis.`

Si le service skills ou réputation est indisponible :

- message joueur : `Mission impossible : prerequis indisponibles.`

## 12. Intégration skills/reputation

Bridges réutilisés sans modification de package :

- `GRSkillsBridge.ListSkills(character_id, callback)`
- `GRReputationBridge.ListCharacterReputations(character_id, callback)`

Le système réutilise directement :

- `skill_row.level`
- `reputation_row.value`

Il n'invente pas de formule de niveau ni de nouvel API nanos world.

## 13. Tests PostgreSQL effectués

Exécutés :

```powershell
Get-Content -Raw ".\database\migrations\037_contract_job_requirements.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
Get-Content -Raw ".\database\seeds\contract_route_templates_mvp_seed.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, item_key, item_quantity, reward_money, required_skill_key, required_skill_level, required_reputation_key, required_reputation_min, reward_skill_key, reward_skill_xp, is_active FROM contract_route_templates ORDER BY key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, quote_nullable(required_skill_key) AS required_skill_key, required_skill_level, quote_nullable(required_reputation_key) AS required_reputation_key, required_reputation_min FROM contract_route_templates ORDER BY key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT DISTINCT skill_key, MIN(level) AS min_level, MAX(level) AS max_level FROM character_skills GROUP BY skill_key ORDER BY skill_key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key FROM reputation_definitions ORDER BY key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT column_name, ordinal_position FROM information_schema.columns WHERE table_name = 'contract_route_templates' ORDER BY ordinal_position;"
```

Constats :

- migration `037` appliquée
- colonnes de prérequis présentes
- seed relancée
- `electronics_to_market` et `medical_to_government` portent bien `required_skill_key='commerce'`
- aucune réputation requise dans le seed MVP
- skills visibles en DB locale : `engineering`, `medicine`, `piloting`
- `commerce` existe côté config skills, mais pas encore dans `character_skills` local observé

## 14. Tests runtime effectués ou restants

Runtime non exécuté dans ce lot.

Restent à faire :

```txt
/jobboard
/jobinfo electronics_to_market
/jobrequirements electronics_to_market
/takejob electronics_to_market

/jobrequirements scrap_to_spatioport
/takejob scrap_to_spatioport
```

## 15. Risques restants

- pas de test runtime nanos world exécuté ici
- aucun `luac` / `lua` / `luajit` disponible localement pour une validation syntaxique automatique
- le seed utilise `commerce` car `transport` n'existe pas dans `gr-skills`
- la DB locale observée ne montre pas encore de ligne `commerce` dans `character_skills`, donc les routes gated peuvent refuser tant qu'aucun personnage n'a ce skill au niveau requis
- aucun prérequis réputation seedé dans le MVP, donc cette branche de logique reste non validée en runtime

## 16. Résultat git status -sb

```txt
## feature/issue-132-contract-job-requirements
 M database/seeds/contract_route_templates_mvp_seed.sql
 M server/Packages/gr-chat/Server/Index.lua
 M server/Packages/gr-contracts/Server/ContractRepository.lua
 M server/Packages/gr-contracts/Server/ContractService.lua
 M server/Packages/gr-contracts/Server/Index.lua
?? database/migrations/037_contract_job_requirements.sql
?? docs/codex-reports/issue-132-contract-job-requirements-report.md
```

## 17. Message de commit recommandé

```txt
feat(contracts): add job requirements
```
