# Issue #129  Contract deadlines MVP

## 1. Résumé de limplémentation

Ajout dun systeme MVP de deadlines sur les contrats `gr-contracts` avec propagation depuis `contract_route_templates`, marquage serveur en `expired`, refus de pickup/completion apres expiration, et commande batch debug pour expirer les contrats echus.

La logique reste server-authoritative. Le client ne choisit ni `deadline_seconds`, ni `expires_at`.

## 2. Agents consultés

- `software-architect`
- `backend-lua`
- `database-engineer`
- `security-reviewer`
- `qa-tester`
- `nanos-world-lua-agent`

Documentation nanos world verifiee avant modification Lua/package :

- `external/nanos-world-docs/docs/core-concepts/packages/packages-guide.md`
- `external/nanos-world-docs/docs/core-concepts/scripting/communicating-between-packages.md`
- `docs/nanos-world-reference.md`

## 3. Fichiers créés

- `database/migrations/034_contract_deadlines.sql`
- `docs/codex-reports/issue-129-contract-deadlines-report.md`

## 4. Fichiers modifiés

- `database/seeds/contract_route_templates_mvp_seed.sql`
- `server/Packages/gr-contracts/Server/ContractRepository.lua`
- `server/Packages/gr-contracts/Server/ContractService.lua`
- `server/Packages/gr-contracts/Server/Index.lua`
- `server/Packages/gr-chat/Server/Index.lua`

## 5. Fichiers explicitement non modifiés

- `server/Packages/gr-inventory/`
- `server/Packages/gr-economy/`
- `server/Packages/gr-gathering/`
- `server/Packages/gr-shops/`
- `Config.toml`

## 6. Migration SQL ajoutée

Migration ajoutee :

- `database/migrations/034_contract_deadlines.sql`

Contenu principal :

- `contracts.deadline_seconds`
- `contracts.expires_at`
- `contracts.expired_at`
- `contract_route_templates.deadline_seconds`
- index `idx_contracts_expires_at`

Point important :

- la migration remplace la contrainte `chk_contracts_status_allowed` afin dajouter le statut `expired`
- aucun `DROP TABLE` ni suppression de donnees

## 7. Seed route templates adapté

Seed modifie :

- `database/seeds/contract_route_templates_mvp_seed.sql`

Deadlines seedees :

- `scrap_to_spatioport = 3600`
- `electronics_to_market = 3600`
- `medical_to_government = 2700`
- `water_to_industrial = 1800`

Le seed reste relancable via `ON CONFLICT`.

## 8. Deadlines contrats

Ajouts cote repository/service :

- normalisation `deadline_seconds`, `expires_at`, `expired_at`
- calcul de `expires_at = NOW() + deadline_seconds`
- `MarkContractExpired(contract_id, callback)`
- `MarkExpiredContracts(callback)`
- `IsContractExpired(contract)`
- `EnsureContractNotExpired(contract, callback)`

Comportement :

- les contrats routes/jobs recuperent `deadline_seconds` depuis `contract_route_templates`
- `expired` devient un statut terminal
- un contrat `expired` ne doit plus etre paye

## 9. Commandes /contractdeadline et /expirecontracts

Commandes ajoutees :

- `/contractdeadline <contract_id>`
- `/expirecontracts`

Messages cibles implementes :

- `Deadline contrat #1 : expires_at=... status=accepted.`
- `Deadline contrat #1 : aucune deadline.`
- `Expiration contrats : X contrat(s) expire(s).`

La allowlist `gr-chat` a ete etendue uniquement avec :

- `contractdeadline`
- `expirecontracts`

## 10. Impact pickup/completion

`/pickupcontract` :

- refuse avec `contract-expired`
- message joueur : `Pickup impossible : deadline expiree.`

`/completecontract` :

- refuse avec `contract-expired`
- message joueur : `Contrat impossible : deadline expiree.`

Dans les deux cas :

- aucun paiement
- aucun contournement client de la deadline

## 11. Impact limite jobs actifs

`/takejob` declenche dabord `ExpireContracts(...)` avant de recompter les jobs actifs.

Effet MVP :

- un contrat deja eche peut etre bascule en `expired`
- il ne compte plus comme job actif car le filtre existant ne retient que `status=accepted`

## 12. Tests PostgreSQL effectués

Migration :

```powershell
Get-Content -Raw ".\database\migrations\034_contract_deadlines.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
```

Resultat :

- `ALTER TABLE` sur `contracts`
- `ALTER TABLE` sur `contract_route_templates`
- contraintes deadline ajoutees
- index `idx_contracts_expires_at` cree

Seed :

```powershell
Get-Content -Raw ".\database\seeds\contract_route_templates_mvp_seed.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
```

Resultat :

- `INSERT 0 4`

Verifications executees :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, item_key, item_quantity, reward_money, pickup_location_key, delivery_location_key, deadline_seconds, is_active FROM contract_route_templates ORDER BY key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, type, status, payment_status, assignee_character_id, deadline_seconds, expires_at, expired_at, pickup_status, delivery_location_key FROM contracts ORDER BY id DESC LIMIT 20;"
```

Constats :

- `4` routes actives avec `deadline_seconds`
- `contracts` expose bien `deadline_seconds`, `expires_at`, `expired_at`

## 13. Tests runtime effectués ou restants

Non executes dans ce lot :

- `/jobboard`
- `/takejob scrap_to_spatioport`
- `/mycontracts`
- `/contractdeadline 1`
- `/expirecontracts`
- `/pickupcontract 1`
- `/completecontract 1`

Test DB dexpiration forcee non execute dans ce lot.

## 14. Risques restants

- pas de test runtime nanos world execute ici
- pas de retrait automatique de cargaison si un contrat expire apres pickup
- la migration doit remplacer une contrainte de statut existante pour autoriser `expired`
- les affichages chat peuvent contenir un champ `deadline=...` vide si aucune deadline nest definie, sans impact fonctionnel
- warnings potentiels `LF -> CRLF` au `git diff --check`

## 15. Résultat git status -sb

Le resultat final est capture apres implementation et verifications git locales.

## 16. Message de commit recommandé

```txt
feat(contracts): add deadlines
```
