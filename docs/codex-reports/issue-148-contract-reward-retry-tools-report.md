# Issue #148  Contract reward retry tools MVP

## 1. Résumé de limplémentation

Ajout d'un chemin de retry contrôlé pour le ledger `contract_reward_grants` existant, sans nouveau système de rewards et sans migration SQL.

Le repository expose maintenant des sélections strictement `pending` / `failed`.
Le service applique un grant ledger unitaire, peut retraiter un contrat précis ou un lot global limité, et recalcule ensuite les statuts agrégés du contrat.
Le package `gr-contracts` expose les commandes admin/debug `/retrycontractrewards <contract_id>` et `/retryfailedcontractrewards`.

## 2. Agents consultés

- `.codex/agents/software-architect.toml`
- `.codex/agents/backend-lua.toml`
- `.codex/agents/database-engineer.toml`
- `.codex/agents/security-reviewer.toml`
- `.codex/agents/qa-tester.toml`
- `.codex/agents/nanos-world-lua-agent.md`

Documentation nanos world relue avant modification :

- `external/nanos-world-docs/docs/core-concepts/packages/packages-guide.md`
- `external/nanos-world-docs/docs/core-concepts/scripting/communicating-between-packages.md`
- `docs/nanos-world-reference.md`

## 3. Fichiers créés

- `docs/codex-reports/issue-148-contract-reward-retry-tools-report.md`

## 4. Fichiers modifiés

- `server/Packages/gr-contracts/Server/ContractRepository.lua`
- `server/Packages/gr-contracts/Server/ContractService.lua`
- `server/Packages/gr-contracts/Server/Index.lua`
- `server/Packages/gr-chat/Server/Index.lua`

## 5. Fichiers explicitement non modifiés

- `database/migrations/`
- `database/seeds/`
- `server/Packages/gr-economy/`
- `server/Packages/gr-skills/`
- `server/Packages/gr-reputation/`
- `server/Packages/gr-progression/`
- `server/Packages/gr-inventory/`
- `server/Packages/gr-gathering/`
- `server/Packages/gr-shops/`
- `Config.toml`

## 6. Migration SQL ajoutée ou non

Aucune migration ajoutée.

## 7. Commande /retrycontractrewards

- protégée par les settings debug contracts existants
- recharge le contrat
- prépare le ledger uniquement si le contrat est déjà `completed`
- récupère les grants retryables `pending` / `failed`
- applique seulement les grants non `applied`
- retourne un rendu détaillé ligne par ligne
- affiche `skipped applied` pour les grants déjà `applied`

## 8. Commande /retryfailedcontractrewards

- protégée par les settings debug contracts existants
- traite seulement les grants ledger `pending` / `failed`
- limite MVP fixée à `20`
- applique les grants un par un
- recalcule ensuite les statuts agrégés des contrats impactés
- retourne un résumé global `processed/applied/failed/skipped/limit`

## 9. Idempotence / skip applied

- les sélecteurs retryables repository n'incluent jamais `applied`
- avant chaque tentative unitaire, le service relit le grant via le ledger existant
- si le grant est déjà `applied`, il est ignoré avec l'issue `skipped applied`
- aucune commande de retry ne recrédite intentionnellement un grant déjà `applied`

## 10. Gestion failed/pending

- `pending` et `failed` sont tous deux retryables
- un succès remplace le statut par `applied`, vide `error_message` et met `applied_at`
- un échec remplace ou maintient le statut `failed`, met un message court et met `updated_at`
- après traitement, les statuts agrégés `payment_status` / `rewards_status` du contrat sont recalculés depuis le ledger

## 11. Sécurité admin/debug

- les deux nouvelles commandes sont soumises à `can_use_contracts_debug_commands(...)`
- `gr-chat` autorise seulement `retrycontractrewards` et `retryfailedcontractrewards` en plus des commandes déjà présentes
- aucune commande joueur publique supplémentaire n'a été créée
- aucun changement côté client ou WebUI

## 12. Tests PostgreSQL effectués

Exécuté :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, contract_id, character_id, reward_type, reward_key, amount, status, error_message, applied_at FROM contract_reward_grants ORDER BY id DESC LIMIT 20;"
```

Constat :

- le ledger local est présent mais vide (`0 rows`)

## 13. Tests runtime effectués ou restants

Runtime nanos world non exécuté dans ce lot.

Restent à faire sur serveur relancé :

```txt
/contractrewardstatus <contract_id>
/retrycontractrewards <contract_id>
/contractrewardstatus <contract_id>
/retrycontractrewards <contract_id>
/retryfailedcontractrewards
```

Contrôles attendus :

- les `pending` / `failed` sont retentées
- les `applied` sont ignorées
- un second retry ne redonne pas les rewards
- pas de `chat-command-not-supported`

## 14. Risques restants

- le flux reste non transactionnel globalement entre DB, économie, skills et réputation
- la relecture du ledger avant tentative réduit le risque, mais ne supprime pas totalement une course concurrente inter-systèmes
- aucun test runtime nanos world n'a été exécuté ici
- la base locale ne contient pas de grants ni de contrat de livraison complété pour valider la reprise bout en bout

## 15. Résultat git status -sb

```txt
## feature/issue-148-contract-reward-retry-tools
 M server/Packages/gr-chat/Server/Index.lua
 M server/Packages/gr-contracts/Server/ContractRepository.lua
 M server/Packages/gr-contracts/Server/ContractService.lua
 M server/Packages/gr-contracts/Server/Index.lua
?? docs/codex-reports/issue-148-contract-reward-retry-tools-report.md
```

`git diff --check` ne remonte pas d'erreur de patch bloquante, seulement des warnings de fin de ligne `LF -> CRLF` sur les fichiers Lua modifiés.

## 16. Message de commit recommandé

```txt
feat(contracts): add reward retry tools
```
