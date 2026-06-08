# Issue #128  Contract abandon/cancel MVP

## 1. Résumé de limplémentation

Ajout dun flux MVP dabandon joueur et dannulation debug/admin dans `gr-contracts`.

Le système réutilise le statut existant `cancelled` au lieu dintroduire `abandoned` en base, afin de rester compatible avec la contrainte SQL déjà présente sur `contracts.status`.

## 2. Agents consultés

- `software-architect`
- `backend-lua`
- `database-engineer`
- `security-reviewer`
- `qa-tester`
- `nanos-world-lua-agent`

Documentation nanos world vérifiée avant modification :
- `external/nanos-world-docs/docs/core-concepts/packages/packages-guide.md`
- `external/nanos-world-docs/docs/core-concepts/scripting/communicating-between-packages.md`
- `docs/cahier-des-charges.md`

## 3. Fichiers créés

- `database/migrations/033_contract_abandon_cancel.sql`
- `docs/codex-reports/issue-128-contract-abandon-cancel-report.md`

## 4. Fichiers modifiés

- `server/Packages/gr-contracts/Server/ContractRepository.lua`
- `server/Packages/gr-contracts/Server/ContractService.lua`
- `server/Packages/gr-contracts/Server/Index.lua`
- `server/Packages/gr-chat/Server/Index.lua`

## 5. Fichiers explicitement non modifiés

- `database/seeds/`
- `server/Packages/gr-inventory/`
- `server/Packages/gr-economy/`
- `server/Packages/gr-gathering/`
- `server/Packages/gr-shops/`
- `Config.toml`

## 6. Migration SQL ajoutée ou non

Migration ajoutée :

- `database/migrations/033_contract_abandon_cancel.sql`

Colonnes ajoutées :

- `cancelled_by_character_id`
- `cancel_reason`

Pas de colonne `abandoned_at` ajoutée.

Raison :

- `cancelled_at` existait déjà
- la contrainte `chk_contracts_status_allowed` de `015_contracts_foundation.sql` autorise déjà `cancelled`
- introduire `abandoned` aurait imposé une modification plus risquée de la contrainte de statut

## 7. Commandes /abandoncontract et /cancelcontract

Ajouts :

- `/abandoncontract <contract_id>`
- `/cancelcontract <contract_id> [reason]`

`gr-chat` autorise maintenant :

- `abandoncontract`
- `cancelcontract`

## 8. Nettoyage de cargaison

`AbandonContract(...)` :

- vérifie que le contrat est assigné au personnage actif
- refuse les contrats terminaux
- si `pickup_status = picked_up` et si une cargaison logique existe :
  - tente `GRInventoryBridge.RemoveItem(...)`
  - si le retrait échoue, labandon est refusé
- si le changement de statut échoue après retrait inventaire :
  - tente une compensation via `GRInventoryBridge.AddItem(...)`

`CancelContract(...)` debug/admin :

- ne tente pas de flux complexe de nettoyage cargo pour un contrat déjà pris
- cette limite est volontairement documentée

## 9. Impact sur limite jobs actifs

Le contrôle anti-abus du job board compte déjà seulement les contrats avec `status = accepted`.

Conséquence :

- un contrat passé en `cancelled` sort automatiquement du comptage des jobs actifs
- aucune refonte supplémentaire du filtre na été nécessaire

## 10. Tests PostgreSQL effectués

Exécutés :

```powershell
Get-Content -Raw ".\database\migrations\033_contract_abandon_cancel.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, type, reward_money, status, payment_status, assignee_character_id, required_item_key, required_item_quantity, pickup_status, cancelled_at, cancelled_by_character_id, cancel_reason FROM contracts ORDER BY id DESC LIMIT 20;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, item_key, quantity, metadata_json FROM inventory_items ORDER BY character_id, item_key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, character_id, target_character_id, amount, currency, wallet, type, reason, created_at FROM bank_transactions ORDER BY id DESC LIMIT 20;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT column_name FROM information_schema.columns WHERE table_name = 'contracts' ORDER BY ordinal_position;"
```

Constats :

- migration `033` appliquée
- `cancelled_by_character_id` et `cancel_reason` présents sur `contracts`
- `inventory_items` reste lisible
- `bank_transactions` reste lisible

## 11. Tests runtime effectués ou restants

Non exécutés dans ce lot :

```txt
/jobboard
/takejob scrap_to_spatioport
/mycontracts
/abandoncontract 1
/mycontracts
/takejob scrap_to_spatioport
/pickupcontract 2
/inv
/abandoncontract 2
/inv
/mycontracts
```

## 12. Risques restants

- aucun test runtime nanos world exécuté ici
- `abandoncontract` réutilise `status=cancelled`, donc la distinction abandon/admin passe par le message joueur et `cancel_reason`
- `cancelcontract` debug/admin ne retire pas automatiquement une cargaison déjà récupérée
- la compensation inventaire après échec SQL reste best-effort
- `git diff --check` ne remonte ici que des warnings `LF -> CRLF`

## 13. Résultat git status -sb

```txt
## feature/issue-128-contract-abandon-cancel
 M server/Packages/gr-chat/Server/Index.lua
 M server/Packages/gr-contracts/Server/ContractRepository.lua
 M server/Packages/gr-contracts/Server/ContractService.lua
 M server/Packages/gr-contracts/Server/Index.lua
?? database/migrations/033_contract_abandon_cancel.sql
?? docs/codex-reports/issue-128-contract-abandon-cancel-report.md
```

## 14. Message de commit recommandé

```txt
feat(contracts): add abandon and cancel flow
```
