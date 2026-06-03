# Issue #108  Contracts economy integration

## 1. Résumé de limplémentation

Cette issue remplace le paiement direct des contrats par une intégration avec `GREconomyBridge`.

Le flux de completion d'un contrat passe maintenant par `gr-economy` pour :

- créditer `money_bank` de l'assigné ;
- écrire une transaction dans `bank_transactions` ;
- ne marquer `payment_status = paid` qu'après succès du bridge économie.

Aucune migration supplémentaire n'a été ajoutée.

## 2. Agents consultés

- `software-architect`
- `backend-lua`
- `database-engineer`
- `security-reviewer`
- `qa-tester`
- `nanos-world-lua-agent`

## 3. Fichiers créés

- `docs/codex-reports/issue-108-contracts-economy-integration-report.md`

## 4. Fichiers modifiés

- `server/Packages/gr-contracts/Package.toml`
- `server/Packages/gr-contracts/Server/ContractService.lua`
- `server/Packages/gr-contracts/Server/ContractRepository.lua`

## 5. Fichiers explicitement non modifiés

- `server/Packages/gr-economy/`
- `server/Packages/gr-chat/`
- `database/migrations/`
- `database/seeds/`
- vrai `Config.toml`

## 6. Intégration GREconomyBridge

`gr-contracts` dépend maintenant explicitement de `gr-economy` via `packages_requirements`.

Le paiement utilise :

```lua
GREconomyBridge.AddMoney(
    assignee_character_id,
    "bank",
    reward_money,
    "contract:<id>",
    metadata,
    callback
)
```

Metadata transmises :

- `contract_id`
- `contract_type`
- `source = "gr-contracts"`

## 7. Paiement contrat

Flux mis à jour dans `ContractService:CompleteContract(...)` :

1. vérifier contrat et assigné ;
2. compléter le contrat ;
3. refuser le double paiement si déjà `completed` ;
4. marquer `payment_status = unavailable` si `reward_money <= 0` ;
5. marquer `payment_status = unavailable` si `GREconomyBridge` est absent ;
6. appeler `GREconomyBridge.AddMoney(...)` si le paiement est éligible ;
7. marquer `payment_status = paid` seulement si l'économie confirme le crédit ;
8. marquer `payment_status = failed` si le bridge répond en erreur.

Logs ajoutés côté contrats :

- `Contract payment requested through economy`
- `Contract payment completed through economy`
- `Contract payment failed through economy`
- `Contract payment unavailable reason=economy-bridge-unavailable`

## 8. Sécurité anti double paiement

Garanties conservées :

- bénéficiaire imposé par `assignee_character_id`
- montant imposé par `contracts.reward_money`
- aucun solde final piloté par le client
- pas de second paiement sur un contrat déjà `completed`
- pas de `payment_status = paid` si `GREconomyBridge` est absent ou échoue

L'ancien crédit direct dans `ContractRepository.lua` a été retiré du flux normal et supprimé du repository.

## 9. Transactions bancaires

La traçabilité du paiement est désormais centralisée dans `gr-economy`.

Résultat attendu au runtime :

- `characters.money_bank` augmenté via `gr-economy`
- une ligne `bank_transactions` créée avec :
  - `wallet = bank`
  - `type = credit`
  - `reason = contract:<id>`

## 10. Ordre de chargement recommandé

Ordre local recommandé :

```txt
gr-core
gr-database
gr-characters
gr-factions
gr-inventory
gr-progression
gr-skills
gr-reputation
gr-quests
gr-chat
gr-crafting
gr-economy
gr-contracts
default-blank-map
```

## 11. Tests PostgreSQL effectués

Exécutés :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, first_name, last_name, money_cash, money_bank FROM characters ORDER BY id;"
```

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, creator_character_id, assignee_character_id, type, reward_money, status, payment_status, paid_at FROM contracts ORDER BY id;"
```

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, character_id, target_character_id, amount, currency, wallet, type, reason, created_at FROM bank_transactions ORDER BY id DESC LIMIT 20;"
```

Résultats observés avant retest runtime :

- `Ari Voss` : `cash=500 bank=2500`
- `Test Character` : `cash=0 bank=0`
- contrat `#1` encore `open / pending`
- `bank_transactions` vide

Ces résultats sont cohérents : le nouveau flux n'a pas encore été exécuté en jeu.

## 12. Tests runtime effectués ou restants

Runtime non exécuté dans ce lot.

Reste à exécuter :

```txt
/money
/contracts
/createcontract delivery 100 Livrer une caisse au spatioport
/contracts
/acceptcontract 1
/mycontracts
/completecontract 1
/mycontracts
/money
/transactions
/profile
```

Vérifications attendues :

- `gr-economy` chargé avant `gr-contracts`
- `money_bank` augmente après `/completecontract`
- une transaction apparaît dans `/transactions`
- `contracts.payment_status = paid`
- `contracts.paid_at` renseigné
- aucun double paiement si `/completecontract 1` est rejoué

## 13. Risques restants

- le flux dépend toujours de l'atomicité limitée de `gr-economy` :
  - si l'update wallet réussit mais que l'insertion `bank_transactions` échoue, le bridge peut remonter un échec après crédit effectif
- aucun retest nanos world n'a encore confirmé le chargement réel de `gr-economy` avant `gr-contracts`
- si un contrat a déjà été complété avant cette intégration, il ne sera pas repayé, ce qui est voulu mais à garder en tête pendant les tests

## 14. Résultat git status -sb

Les changements attendus portent sur :

- `server/Packages/gr-contracts/Package.toml`
- `server/Packages/gr-contracts/Server/ContractService.lua`
- `server/Packages/gr-contracts/Server/ContractRepository.lua`
- `docs/codex-reports/issue-108-contracts-economy-integration-report.md`

## 15. Message de commit recommandé

```txt
feat(contracts): pay contracts through economy bridge
```
