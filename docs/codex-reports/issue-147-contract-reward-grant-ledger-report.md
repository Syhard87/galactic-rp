# Issue #147  Contract reward grant ledger MVP

## 1. Résumé de limplémentation

Ajout d'un ledger SQL `contract_reward_grants` pour tracer les rewards de contrat, sécuriser l'idempotence et améliorer le diagnostic du flux `/delivercontract`. Le service prépare désormais les grants avant finalisation, applique les rewards via le ledger et expose un statut admin/debug lisible.

## 2. Agents consultés

- `.codex/agents/software-architect.toml`
- `.codex/agents/backend-lua.toml`
- `.codex/agents/database-engineer.toml`
- `.codex/agents/security-reviewer.toml`
- `.codex/agents/qa-tester.toml`
- `.codex/agents/nanos-world-lua-agent.md`

## 3. Fichiers créés

- `database/migrations/038_contract_reward_grants.sql`
- `docs/codex-reports/issue-147-contract-reward-grant-ledger-report.md`

## 4. Fichiers modifiés

- `server/Packages/gr-contracts/Server/ContractRepository.lua`
- `server/Packages/gr-contracts/Server/ContractService.lua`
- `server/Packages/gr-contracts/Server/Index.lua`
- `server/Packages/gr-chat/Server/Index.lua`

## 5. Fichiers explicitement non modifiés

- `database/seeds/`
- `server/Packages/gr-economy/`
- `server/Packages/gr-skills/`
- `server/Packages/gr-reputation/`
- `server/Packages/gr-inventory/`
- `Config.toml`

## 6. Migration SQL ajoutée ou non

Migration ajoutée :

- `database/migrations/038_contract_reward_grants.sql`

Caractéristiques :

- `CREATE TABLE IF NOT EXISTS contract_reward_grants`
- contrainte unique anti doublon sur `(contract_id, reward_type, reward_key)`
- index sur `contract_id` et `character_id`
- contraintes de contrôle sur `reward_type`, `status` et `amount > 0`

## 7. Table contract_reward_grants

Champs ajoutés :

- `id`
- `contract_id`
- `character_id`
- `reward_type`
- `reward_key`
- `amount`
- `status`
- `error_message`
- `created_at`
- `updated_at`
- `applied_at`

Statuts ledger gérés :

- `pending`
- `applied`
- `failed`

Types gérés :

- `money`
- `skill_xp`
- `reputation`

## 8. Intégration /delivercontract

Le flux `/delivercontract` utilise maintenant le ledger :

1. validation du contrat ;
2. préparation des grants attendus ;
3. finalisation du contrat ;
4. application des grants `pending` ;
5. mise à jour des statuts `payment_status` / `rewards_status` ;
6. retour d'un résumé lisible au joueur.

Le flux reste conservateur : le contrat est toujours passé `completed` avant l'application effective des rewards, mais il n'est plus possible d'avoir un contrat `completed` sans ledger préparé.

## 9. Idempotence rewards

Mesures MVP :

- contrainte SQL unique anti doublon par reward logique ;
- skip automatique des grants déjà `applied` ;
- marquage `failed` avec message court en cas d'erreur ;
- préparation initiale capable de créer des grants déjà `applied` ou `failed` pour les contrats historiques déjà complétés, afin d'éviter un double paiement via `/grantcontractrewards`.

## 10. Commande /contractrewardstatus

Commande admin/debug ajoutée :

- `/contractrewardstatus <contract_id>`

Protection :

- `gr_contracts_debug_commands_enabled`
- `gr_contracts_debug_allowed_platform_ids`

Affichage :

- une ligne par grant avec type, clé, montant, statut et erreur éventuelle.

## 11. Sécurité anti double reward

- pas de deuxième système économie / skills / réputation ;
- verrou principal conservé : `status=completed` côté contrat ;
- verrou complémentaire ajouté : ledger unique et idempotent ;
- `/delivercontract` et `/grantcontractrewards` ne réappliquent pas une ligne ledger déjà `applied` ;
- un contrat déjà payé ou déjà récompensé peut maintenant recevoir des grants ledger initialisés directement en `applied`, évitant un doublon lors d'une reprise manuelle.

## 12. Tests PostgreSQL effectués

Exécutés :

```powershell
Get-Content -Raw 'database/migrations/038_contract_reward_grants.sql' | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "\dt contract_reward_grants"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, contract_id, character_id, reward_type, reward_key, amount, status, error_message, applied_at FROM contract_reward_grants ORDER BY id DESC LIMIT 20;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, assignee_character_id, status, pickup_status, source_route_key, reward_money, completed_at, payment_status, rewards_status FROM contracts ORDER BY id DESC LIMIT 10;"
```

Constats :

- migration appliquée avec succès ;
- table `contract_reward_grants` présente ;
- ledger encore vide en base locale ;
- la base locale observée contient seulement un contrat `open` non assigné.

## 13. Tests runtime effectués ou restants

Runtime non exécuté dans ce lot.

Restants :

- `/jobboard`
- `/takejob scrap_to_spatioport`
- `/pickupcontract <contract_id>`
- `/delivercontract <contract_id>`
- `/contractrewardstatus <contract_id>`
- `/delivercontract <contract_id>` une seconde fois
- `/contractrewardstatus <contract_id>` après seconde tentative

## 14. Risques restants

- le flux reste non transactionnel globalement entre DB, économie, skills et réputation ;
- si le contrat passe `completed` puis qu'une partie des rewards échoue, le ledger devient traçable et anti doublon, mais il n'y a toujours pas de rollback atomique global ;
- aucun test runtime nanos world exécuté ici ;
- aucun `lua`, `luac` ou `luajit` local détecté pour une validation syntaxique automatique ;
- la base locale n'expose pas de contrat `accepted/completed`, donc le flux réel de livraison et de ledger reste à valider en runtime.

## 15. Résultat git status -sb

À relever après implémentation :

- migration SQL ajoutée ;
- modifications limitées à `gr-contracts`, `gr-chat` et au rapport.

## 16. Message de commit recommandé

```txt
feat(contracts): add reward grant ledger
```
