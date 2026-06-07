# Issue #122  Contract item delivery MVP

## 1. Résumé de limplémentation

Ajout des contrats de livraison ditems dans `gr-contracts` avec création dédiée, affichage des items requis, vérification serveur de linventaire à la complétion, retrait des items requis, paiement via `GREconomyBridge` et tentative de compensation inventaire si le paiement échoue après retrait.

## 2. Agents consultés

- `software-architect`
- `backend-lua`
- `database-engineer`
- `security-reviewer`
- `qa-tester`
- `nanos-world-lua-agent`

## 3. Fichiers créés

- `database/migrations/028_contract_item_delivery.sql`
- `docs/codex-reports/issue-122-contract-item-delivery-report.md`

## 4. Fichiers modifiés

- `server/Packages/gr-contracts/Package.toml`
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

`database/migrations/028_contract_item_delivery.sql`

Colonnes ajoutées à `contracts` :

- `required_item_key`
- `required_item_quantity`
- `consume_required_items`

Contrainte ajoutée :

- `chk_contracts_required_item_quantity_non_negative`

## 7. Contrats de livraison ditems

Ajout du support serveur des contrats `delivery` avec :

- `required_item_key = item_key`
- `required_item_quantity = quantity`
- `consume_required_items = true`

Le repository normalise maintenant ces champs dans tous les reads de contrats.

## 8. Commande /createdeliverycontract

Commande ajoutée :

`/createdeliverycontract <item_key> <quantity> <reward_money> <description>`

Validation serveur :

- `item_key` non vide et normalisé
- `quantity > 0 && quantity <= 1000`
- `reward_money >= 0 && reward_money <= 1000000`
- `description` non vide

## 9. Intégration inventaire

Le flux `/completecontract <id>` vérifie maintenant :

1. que le contrat accepté exige un item ;
2. que lassigné possède la quantité requise via `GRInventoryBridge.ListInventory(...)` ;
3. que le retrait se fait via `GRInventoryBridge.RemoveItem(...)` avant la suite du flux.

Erreurs gérées :

- `required-item-missing`
- `inventory-check-unavailable`
- `inventory-remove-failed`

## 10. Intégration paiement économie

Après retrait item et passage du contrat en `completed`, le paiement est demandé via :

`GREconomyBridge.AddMoney(character_id, "bank", reward_money, "contract:<id>", metadata, callback)`

La transaction doit rester visible dans `bank_transactions` via la raison `contract:<id>`.

## 11. Compensation en cas déchec paiement

Si le paiement échoue après retrait item :

- le contrat est marqué `payment_status = failed` ;
- une compensation inventaire est tentée via `GRInventoryBridge.AddItem(...)` ;
- le joueur reçoit un message d'échec clair.

Le même principe de compensation est aussi appliqué si la mise à jour de complétion échoue après retrait item.

## 12. Tests PostgreSQL effectués

Exécutés :

```powershell
Get-Content -Raw ".\database\migrations\028_contract_item_delivery.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, type, reward_money, status, payment_status, required_item_key, required_item_quantity, consume_required_items FROM contracts ORDER BY id;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, item_key, quantity, metadata_json FROM inventory_items ORDER BY character_id, item_key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, character_id, target_character_id, amount, currency, wallet, type, reason, created_at FROM bank_transactions ORDER BY id DESC LIMIT 20;"
```

Constats :

- migration `028` appliquée ;
- les nouvelles colonnes existent ;
- `contracts` lisible avec valeurs par défaut ;
- `inventory_items` lisible ;
- `bank_transactions` lisible.

## 13. Tests runtime effectués ou restants

Runtime non exécuté dans ce lot.

Restent à faire :

```txt
/giveitem scrap 5
/inv
/createdeliverycontract scrap 5 150 Livrer du scrap au spatioport
/contracts
/acceptcontract 1
/mycontracts
/completecontract 1
/inv
/money
/transactions
```

## 14. Risques restants

- pas de test runtime nanos world exécuté ici ;
- la complétion reste mise à jour avant confirmation du paiement, comme dans le flux contrats existant ;
- en cas d’échec de compensation inventaire, le contrat peut rester `completed` avec `payment_status=failed` et items non restaurés ;
- pas de validation DB explicite sur lexistence de `required_item_key` dans `items`.

## 15. Résultat git status -sb

```txt
## feature/issue-122-contract-item-delivery
 M server/Packages/gr-chat/Server/Index.lua
 M server/Packages/gr-contracts/Package.toml
 M server/Packages/gr-contracts/Server/ContractRepository.lua
 M server/Packages/gr-contracts/Server/ContractService.lua
 M server/Packages/gr-contracts/Server/Index.lua
?? database/migrations/028_contract_item_delivery.sql
?? docs/codex-reports/issue-122-contract-item-delivery-report.md
```

## 16. Message de commit recommandé

`feat(contracts): add item delivery contracts`
