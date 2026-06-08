# Issue #130  Expired contract cargo cleanup MVP

## 1. Résumé de limplémentation

Le lot ajoute un nettoyage serveur de la cargaison quand un contrat passe en `expired` après pickup. Le statut du contrat reste `expired`, aucun paiement n'est effectué, et le résultat du nettoyage est tracé dans `contracts`.

Les scripts Lua ont été modifiés après lecture de `docs/cahier-des-charges.md` et des pages nanos world suivantes :
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

- `database/migrations/035_contract_expired_cargo_cleanup.sql`
- `docs/codex-reports/issue-130-contract-expired-cargo-cleanup-report.md`

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

## 6. Migration SQL ajoutée

Migration ajoutée :

- `database/migrations/035_contract_expired_cargo_cleanup.sql`

Champs ajoutés sur `contracts` :

- `cargo_cleanup_status`
- `cargo_cleaned_at`
- `cargo_cleanup_error`

Index ajouté :

- `idx_contracts_cargo_cleanup_status`

## 7. Nettoyage de cargaison expirée

Statuts utilisés :

- `none`
- `not_required`
- `pending`
- `cleaned`
- `failed`

Règles appliquées :

- un contrat expiré avant pickup reçoit `cargo_cleanup_status = not_required`
- un contrat expiré après pickup reçoit d'abord `cargo_cleanup_status = pending`
- `CleanupExpiredContractCargo(...)` tente `GRInventoryBridge.RemoveItem(...)` avec les données du contrat
- en cas de succès : `cargo_cleanup_status = cleaned` et `cargo_cleaned_at = NOW()`
- en cas d'échec : `cargo_cleanup_status = failed` et `cargo_cleanup_error` reçoit une raison courte

## 8. Commandes /cleanupcontractcargo et /expiredcontracts

Commandes ajoutées :

- `/cleanupcontractcargo <contract_id>`
- `/expiredcontracts`

Protection MVP :

- commandes gardées derrière `gr_contracts_debug_commands_enabled`
- commandes gardées derrière `gr_contracts_debug_allowed_platform_ids`

## 9. Impact sur /expirecontracts

`/expirecontracts` continue d'expirer les contrats dépassés, puis enchaîne désormais le cleanup cargo pour chaque contrat nouvellement expiré.

Le résumé retourné expose :

- `expired_count`
- `cleanup_cleaned_count`
- `cleanup_failed_count`
- `cleanup_not_required_count`

## 10. Intégration inventaire

Le lot réutilise uniquement `GRInventoryBridge.ListInventory(...)` et `GRInventoryBridge.RemoveItem(...)`.

Le client ne choisit jamais les items retirés. Les données de cleanup viennent du contrat :

- `assignee_character_id`
- `required_item_key`
- `required_item_quantity`

## 11. Tests PostgreSQL effectués

Exécutés :

```powershell
Get-Content -Raw ".\database\migrations\035_contract_expired_cargo_cleanup.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, status, payment_status, assignee_character_id, required_item_key, required_item_quantity, pickup_status, expires_at, expired_at, cargo_cleanup_status, cargo_cleaned_at, cargo_cleanup_error FROM contracts ORDER BY id DESC LIMIT 20;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, item_key, quantity, metadata_json FROM inventory_items ORDER BY character_id, item_key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT column_name FROM information_schema.columns WHERE table_name = 'contracts' AND column_name IN ('cargo_cleanup_status', 'cargo_cleaned_at', 'cargo_cleanup_error') ORDER BY column_name;"
```

Constats :

- migration `035` appliquée
- colonnes cleanup présentes sur `contracts`
- `inventory_items` reste lisible
- aucun test runtime nanos world exécuté dans ce lot

## 12. Tests runtime effectués ou restants

Runtime non exécuté dans ce lot.

Restent à faire :

```txt
/jobboard
/takejob scrap_to_spatioport
/pickupcontract 1
/inv

forcer expires_at en DB dans le passé

/expirecontracts
/expiredcontracts
/inv
/completecontract 1
```

## 13. Risques restants

- pas de test runtime nanos world exécuté ici
- si la cargaison a déjà été déplacée ou partiellement consommée, le cleanup peut passer en `failed`
- aucun rollback vers un statut actif n'est permis après expiration, même si le cleanup réussit
- aucun paiement n'est effectué sur contrat expiré
- aucun outillage Lua local (`luac`, `lua`, `luajit`) n'était disponible pour une validation syntaxique automatique

## 14. Résultat git status -sb

```txt
## feature/issue-130-contract-expired-cargo-cleanup
 M server/Packages/gr-chat/Server/Index.lua
 M server/Packages/gr-contracts/Server/ContractRepository.lua
 M server/Packages/gr-contracts/Server/ContractService.lua
 M server/Packages/gr-contracts/Server/Index.lua
?? database/migrations/035_contract_expired_cargo_cleanup.sql
?? docs/codex-reports/issue-130-contract-expired-cargo-cleanup-report.md
```

## 15. Message de commit recommandé

```txt
feat(contracts): clean expired cargo
```
