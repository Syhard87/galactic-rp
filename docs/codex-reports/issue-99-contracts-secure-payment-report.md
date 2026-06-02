# Issue #99  Contracts secure payment

## 1. Resume de limplementation

Ajout d'un paiement serveur MVP lors de la completion d'un contrat accepte :

- detection de l'economie existante dans `characters.money_bank`
- ajout de la tracabilite `payment_status` et `paid_at` sur `contracts`
- credit direct de `money_bank` pour l'assigne
- prevention du double paiement via statut de contrat et statut de paiement
- message joueur clair sur l'etat du paiement

## 2. Agents consultes

- software-architect
- database-engineer
- backend-lua
- nanos-world-lua-agent
- security-reviewer
- qa-tester

## 3. Fichiers crees

- `database/migrations/016_contracts_payment.sql`
- `docs/codex-reports/issue-99-contracts-secure-payment-report.md`

## 4. Fichiers modifies

- `server/Packages/gr-contracts/Server/ContractRepository.lua`
- `server/Packages/gr-contracts/Server/ContractService.lua`
- `server/Packages/gr-contracts/Server/Index.lua`

## 5. Fichiers explicitement non modifies

- `server/Packages/gr-database/`
- `server/Packages/gr-quests/`
- `server/Packages/gr-reputation/`
- `server/Packages/gr-crafting/`
- `server/Packages/gr-inventory/`
- `server/Packages/gr-skills/`
- vrai `Config.toml`

## 6. Migration SQL ajoutee ou non necessaire

Migration ajoutee :

- `database/migrations/016_contracts_payment.sql`

Ajouts :

- `contracts.payment_status VARCHAR(32) NOT NULL DEFAULT 'pending'`
- `contracts.paid_at TIMESTAMPTZ`
- contrainte `chk_contracts_payment_status_allowed`
- index `idx_contracts_payment_status`

## 7. Mode paiement retenu

Mode retenu :

- credit direct via `characters.money_bank`

Justification :

- aucun package `gr-economy` n'existe dans le depot
- `money_cash` et `money_bank` existent deja dans `characters`
- le prompt recommande de preferer `money_bank` si la colonne existe

## 8. Details techniques Lua

### Repository

Ajouts dans `ContractRepository.lua` :

- lecture de `payment_status` et `paid_at`
- `MarkContractPayment(contract_id, payment_status, callback)`
- `CreditCharacterBankMoney(character_id, amount, callback)`

### Service

`CompleteContract(character_id, contract_id, callback)` suit maintenant ce flux :

1. charge le contrat
2. refuse si contrat introuvable
3. refuse si deja `completed`
4. refuse si le personnage courant n'est pas l'assigne d'un contrat `accepted`
5. marque le contrat `completed`
6. credite `money_bank` si `reward_money > 0`
7. marque `payment_status` a `paid`, `failed` ou `unavailable`
8. retourne un resultat exploitable par `Index.lua`

## 9. Securite anti double paiement

Protections appliquees :

- le serveur utilise toujours `assignee_character_id`
- le montant vient toujours de `contracts.reward_money`
- un contrat `completed` est refuse sur nouvelle completion
- si un contrat deja complete a `payment_status = paid`, le service loggue :

```txt
[gr_contracts][service] Contract payment skipped reason=already-paid contract_id=%s.
```

Limite connue :

- le workflow n'est pas transactionnel entre `completed`, credit bank et `payment_status`
- si le credit reussit mais que la tracabilite SQL echoue, le contrat reste non repayable car deja `completed`

## 10. Messages joueur

Succes paiement :

```txt
Contrat termine : #1 reward=100 paiement=effectue
```

Paiement indisponible :

```txt
Contrat termine : #1 reward=100 paiement=non-disponible
```

Paiement echoue :

```txt
Contrat termine : #1 reward=100 paiement=echoue
```

Double completion :

```txt
Contrat deja termine.
```

## 11. Tests effectues

Tests locaux realises :

1. verification branche et prerequis #98
2. inspection economie :
   - `database/migrations/001_init.sql`
   - `database/seeds/dev_seed.sql`
   - recherche `money_cash`, `money_bank`, `gr-economy`
3. creation migration `016_contracts_payment.sql`
4. mise a jour de `gr-contracts`
5. application migration PostgreSQL
6. verification de `contracts`
7. verification git :
   - `git status -sb`
   - `git status --short --untracked-files=all`
   - `git diff --name-only`
   - `git diff --check`

## 12. Tests a faire manuellement en runtime nanos world

Activer localement :

```toml
gr_contracts_debug_commands_enabled = true
```

Tests :

```txt
/profile
/contracts
/createcontract delivery 100 Livrer une caisse au spatioport
/contracts
/acceptcontract 1
/mycontracts
/completecontract 1
/mycontracts
/profile
```

Verifier aussi :

```txt
/completecontract 1
/acceptcontract 1
/cancelcontract 1
```

## 13. Requetes PostgreSQL de verification

Migration :

```powershell
Get-Content -Raw ".\database\migrations\016_contracts_payment.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
```

Contrats :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, reward_money, status, payment_status, paid_at FROM contracts ORDER BY id;"
```

Argent personnages :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, money_cash, money_bank FROM characters ORDER BY id;"
```

## 14. Resultat git status -sb

Le resultat final a ete releve apres implementation et verifications locales.

## 15. Risques restants

- runtime nanos world non lance ici, donc validation finale en jeu encore necessaire
- aucun package economie dedie n'existe ; le credit direct `money_bank` reste un MVP
- pas de table de transactions bancaires dans ce lot
- le flux n'est pas transactionnel de bout en bout

## 16. Message de commit recommande

```text
feat(contracts): add secure payment
```
