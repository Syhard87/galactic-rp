# Issue #111  Economy salaries MVP

## 1. Resume de l'implementation

Ajout d'un MVP de salaire revendicable cote serveur dans `gr-economy`.
Le flux principal est `ClaimSalary(character_id, callback)` avec :

- resolution de la regle active selon la faction / le rang du personnage
- controle de cooldown
- versement via `AddMoney(...)`
- ecriture du claim seulement si le versement reussit
- compensation via `RemoveMoney(...)` si le paiement a reussi mais que l'upsert du claim echoue

## 2. Agents consultes

- `software-architect`
- `backend-lua`
- `database-engineer`
- `security-reviewer`
- `qa-tester`
- `nanos-world-lua-agent`

Documentation nanos world consultee avant modification Lua :
- `external/nanos-world-docs/docs/core-concepts/packages/packages-guide.md`
- `external/nanos-world-docs/docs/core-concepts/scripting/communicating-between-packages.md`

## 3. Fichiers crees

- `database/migrations/018_economy_salaries.sql`
- `database/seeds/economy_salaries_mvp_seed.sql`
- `docs/codex-reports/issue-111-economy-salaries-report.md`

## 4. Fichiers modifies

- `server/Packages/gr-economy/Server/EconomyRepository.lua`
- `server/Packages/gr-economy/Server/EconomyService.lua`
- `server/Packages/gr-economy/Server/Index.lua`
- `server/Packages/gr-chat/Server/Index.lua`

## 5. Fichiers explicitement non modifies

- `server/Packages/gr-contracts/`
- `server/Packages/gr-crafting/`
- `server/Packages/gr-quests/`
- `server/Packages/gr-reputation/`
- vrai `Config.toml`

## 6. Migration SQL ajoutee

Migration ajoutee :

```txt
database/migrations/018_economy_salaries.sql
```

Tables creees :

- `economy_salary_rules`
- `character_salary_claims`

Choix schema MVP :

- `faction_id` nullable pour lier directement aux factions numeriques existantes
- `faction_key` nullable pour garder une compatibilite texte simple basee sur `factions.type`
- `rank_id` nullable pour permettre une evolution future vers des salaires par grade
- `wallet` borne a `cash|bank`
- `amount` borne a `> 0` et `<= 1000000`
- `cooldown_seconds` borne a `> 0`

## 7. Seed MVP ajoute

Seed ajoute :

```txt
database/seeds/economy_salaries_mvp_seed.sql
```

Regles MVP inserees :

- `civil_salary`
- `government_salary`
- `military_salary`
- `merchant_salary`
- `criminal_salary`

Cooldown MVP :

```txt
3600
```

Note :
- le premier lancement du seed a echoue parce qu'il avait ete execute en parallele avec la migration
- aucun probleme SQL du seed lui-meme
- le seed relance apres migration a insere correctement 5 regles

## 8. Systeme de salaire

Repository ajoute :

- `GetSalaryRuleForCharacter(character_id, callback)`
- `GetSalaryClaim(character_id, salary_rule_id, callback)`
- `UpsertSalaryClaim(character_id, salary_rule_id, callback)`
- `ListSalaryRules(callback)`

Service ajoute :

- `ClaimSalary(character_id, callback)`
- `ListSalaryRules(callback)`

Selection de regle :

- lecture de `characters.faction_id`
- lecture de `characters.rank_id`
- fallback textuel via `factions.type`
- priorite aux regles de rang si un `rank_id` correspondant existe

Versement :

- `AddMoney(character_id, wallet, amount, reason, metadata, callback)`
- `reason = salary:<salary_rule_key>`
- metadata :
  - `salary_rule_id`
  - `salary_rule_key`

## 9. Cooldown anti-abus

Le cooldown est porte par `character_salary_claims.last_claimed_at`.

Logique :

- lecture du dernier claim
- comparaison avec `cooldown_seconds`
- refus si delai restant > 0

Message joueur :

```txt
Salaire indisponible : cooldown restant 2400s.
```

## 10. Commandes /claimsalary et /salaryrules

Commandes ajoutees :

- `/claimsalary`
- `/salaryrules`

Elles restent derriere les memes protections debug que les autres commandes economie :

- `gr_economy_debug_commands_enabled`
- `gr_economy_debug_allowed_platform_ids`

Allowlist `gr-chat` mise a jour :

- `claimsalary`
- `salaryrules`

## 11. Tests PostgreSQL effectues

Commandes executees :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1 -f /workspace/database/migrations/018_economy_salaries.sql
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1 -f /workspace/database/seeds/economy_salaries_mvp_seed.sql
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, key, label, faction_id, faction_key, wallet, amount, cooldown_seconds, is_active FROM economy_salary_rules ORDER BY id;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, salary_rule_id, last_claimed_at, claim_count FROM character_salary_claims ORDER BY character_id, salary_rule_id;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, first_name, last_name, faction_id, money_cash, money_bank FROM characters ORDER BY id;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, character_id, target_character_id, amount, currency, wallet, type, reason, created_at FROM bank_transactions ORDER BY id DESC LIMIT 20;"
```

Constats :

- migration `018` appliquee
- seed MVP applique
- 5 regles de salaire presentes
- `character_salary_claims` vide avant runtime, ce qui est attendu

## 12. Tests runtime effectues ou restants

Non executes dans ce lot.

Retest runtime recommande :

```txt
/money
/salaryrules
/claimsalary
/money
/transactions
/claimsalary
```

## 13. Risques restants

- `AddMoney(...)` puis `UpsertSalaryClaim(...)` ne forment pas une transaction SQL unique
- compensation par `RemoveMoney(...)` ajoute une robustesse pratique, mais pas une atomicite parfaite
- pas de detection AFK avancee dans ce lot
- pas de timer automatique global dans ce lot
- le comportement runtime nanos world reste a confirmer en jeu

## 14. Resultat git status -sb

```txt
## feature/issue-111-economy-salaries
 M server/Packages/gr-chat/Server/Index.lua
 M server/Packages/gr-economy/Server/EconomyRepository.lua
 M server/Packages/gr-economy/Server/EconomyService.lua
 M server/Packages/gr-economy/Server/Index.lua
?? database/migrations/018_economy_salaries.sql
?? database/seeds/economy_salaries_mvp_seed.sql
?? docs/codex-reports/issue-111-economy-salaries-report.md
```

## 15. Message de commit recommande

```txt
feat(economy): add faction salary claims
```
