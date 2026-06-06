# Issue #110  Economy safe transfers

## 1. Resume de l'implementation

`GREconomyBridge.TransferMoney(...)` a ete securise pour eviter les etats partiels silencieux.
Le transfert passe maintenant par une requete PostgreSQL atomique en une seule instruction SQL avec CTE, au lieu d'une suite de callbacks debit / credit / insert transaction.

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
- `external/nanos-world-docs/docs/scripting-reference/classes/database.mdx`

## 3. Fichiers crees

- `docs/codex-reports/issue-110-economy-safe-transfers-report.md`

## 4. Fichiers modifies

- `server/Packages/gr-economy/Server/EconomyRepository.lua`
- `server/Packages/gr-economy/Server/EconomyService.lua`
- `server/Packages/gr-economy/Server/Index.lua`

## 5. Fichiers explicitement non modifies

- `server/Packages/gr-contracts/`
- `server/Packages/gr-chat/`
- `database/migrations/`
- `database/seeds/`
- vrai `Config.toml`

## 6. Analyse du support transaction DB

Constat apres lecture de `gr-database` et de la doc locale nanos world :

- `GRDatabaseBridge` expose un service qui fournit un objet `Database`
- cet objet est considere utilisable si `SelectAsync` et `ExecuteAsync` existent
- aucun helper projet n'expose explicitement `BEGIN`, `COMMIT`, `ROLLBACK`
- la documentation locale `database.mdx` decrit `Execute` / `Select`, mais ne documente pas un helper transaction dedie

Conclusion :
- aucune API transaction projet/documentee n'est disponible avec un niveau de certitude suffisant
- la strategie retenue est une requete PostgreSQL atomique en une seule instruction SQL via CTE

## 7. Securisation TransferMoney

`EconomyService:TransferMoney(...)` :

- valide `from_character_id`
- valide `to_character_id`
- refuse `from_character_id == to_character_id`
- valide `wallet`
- valide `amount`
- delegue ensuite a `EconomyRepository:TransferMoneyAtomic(...)`

Codes retour utilises cote service :

- `invalid-source-character`
- `invalid-target-character`
- `same-character`
- `invalid-wallet`
- `invalid-amount`
- `insufficient-funds`
- `transfer-incomplete`
- `database-error`

## 8. Rollback ou strategie atomique

Strategie retenue : atomicite SQL par requete unique.

Implementation :

- lecture source / cible
- debit source
- credit cible
- insertion `transfer_out`
- insertion `transfer_in`

Tout cela est execute dans une seule instruction SQL PostgreSQL avec CTE.

Impact :

- si une sous-etape SQL echoue, PostgreSQL annule toute l'instruction
- il n'y a plus de debit source reussi suivi d'un credit cible non fait dans ce flux
- il n'y a plus de rollback applicatif manuel a maintenir pour ce cas

Limite restante :

- cela repose sur l'atomicite d'une instruction PostgreSQL unique, pas sur une API `BEGIN/COMMIT/ROLLBACK` explicite du runtime nanos world
- aucun verrouillage applicatif supplementaire n'a ete ajoute dans ce lot

## 9. Commande /pay

`/pay` conserve le meme nom et le meme flux, mais mappe maintenant plus proprement les retours de `TransferMoney` :

- `Paiement impossible : solde insuffisant.`
- `Paiement impossible : transfert incomplet.`
- `Paiement impossible : erreur economie.`

Les validations cible / wallet / montant / auto-paiement restent cote serveur.

## 10. Tests PostgreSQL effectues

Commandes executees :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, first_name, last_name, money_cash, money_bank FROM characters ORDER BY id;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, character_id, target_character_id, amount, currency, wallet, type, reason, created_at FROM bank_transactions ORDER BY id DESC LIMIT 20;"
```

Constat :

- les soldes personnages sont lisibles
- `bank_transactions` est accessible
- aucun schema supplementaire n'a ete necessaire

## 11. Tests runtime effectues ou restants

Non executes dans ce lot.

Retest runtime recommande :

```txt
/givemoney cash 200 transfer_setup
/pay 4 cash 50 transfer_test
/money
/transactions
```

Cas d'erreur :

```txt
/pay 3 cash 50 self_test
/pay 4 cash 999999999 too_much
/pay 4 fake 10 bad_wallet
/pay 999 cash 10 bad_target
```

## 12. Risques restants

- aucun helper transaction explicite `BEGIN/COMMIT/ROLLBACK` n'est documente/encapsule dans `gr-database`
- la robustesse repose sur une requete atomique PostgreSQL unique
- le comportement runtime nanos world de cette requete CTE complete reste a confirmer en jeu
- aucun controle de concurrence metier supplementaire n'a ete ajoute au-dela du garde-fou SQL sur le solde

## 13. Resultat git status -sb

```txt
## feature/issue-110-economy-safe-transfers
 M server/Packages/gr-economy/Server/EconomyRepository.lua
 M server/Packages/gr-economy/Server/EconomyService.lua
 M server/Packages/gr-economy/Server/Index.lua
?? docs/codex-reports/issue-110-economy-safe-transfers-report.md
```

## 14. Message de commit recommande

```txt
fix(economy): make player transfers safer
```
