# Issue #149  Contract reward smoke fixture MVP

## 1. Résumé de limplémentation

Ajout de la commande debug/admin `/createcontractrewardsmoke`.

La commande crée un contrat `delivery` marque `[DEBUG] Reward smoke delivery`, lie la fixture au personnage actif, puis accepte immediatement le contrat pour le rendre compatible avec le flux standard `/delivercontract <contract_id>`.

La fixture ne cree pas de ledger applique a lavance, ne rejoue aucune reward, et ne bypass pas la finalisation existante. Les rewards restent traitees par `/delivercontract`, puis observables via `/contractrewardstatus`, `/retrycontractrewards` et `/retryfailedcontractrewards`.

## 2. Agents consultés

- `software-architect`
- `backend-lua`
- `database-engineer`
- `security-reviewer`
- `qa-tester`
- `nanos-world-lua-agent`

## 3. Fichiers créés

- `docs/codex-reports/issue-149-contract-reward-smoke-fixture-report.md`

## 4. Fichiers modifiés

- `server/Packages/gr-contracts/Server/ContractService.lua`
- `server/Packages/gr-contracts/Server/Index.lua`
- `server/Packages/gr-chat/Server/Index.lua`

## 5. Fichiers explicitement non modifiés

- `server/Packages/gr-contracts/Server/ContractRepository.lua`
- `database/migrations/`
- `database/seeds/`
- `server/Packages/gr-skills/`
- `server/Packages/gr-progression/`
- `server/Packages/gr-reputation/`
- `server/Packages/gr-inventory/`
- `server/Packages/gr-economy/`
- `server/Packages/gr-gathering/`
- `server/Packages/gr-shops/`
- `Config.toml`

## 6. Migration SQL ajoutée ou non

Aucune migration ajoutee.

## 7. Commande /createcontractrewardsmoke

La commande :

- verifie la garde debug/admin existante ;
- recupere le personnage actif via `GRCharactersBridge.GetActiveCharacter` ;
- cree un contrat `delivery` debug ;
- assigne le contrat au personnage actif via le flux existant dacception ;
- affiche `contract_id`, `character_id` et les prochaines commandes de test.

Messages specifiques geres :

- `Commandes debug contracts desactivees.`
- `Acces refuse.`
- `Aucun personnage actif trouve.`

## 8. Sécurité admin/debug

La commande reuse la meme logique que les autres commandes debug contracts :

- `gr_contracts_debug_commands_enabled`
- allowlist `gr_contracts_debug_allowed_platform_ids`

Aucune nouvelle mecanique de permission na ete ajoutee.

`gr-chat` a seulement recu lallowlist `createcontractrewardsmoke`.

## 9. Fixture créée

La fixture cree un contrat :

- `type = delivery`
- `title = [DEBUG] Reward smoke delivery`
- `status = accepted` apres creation
- `required_item_key = NULL`
- `required_item_quantity = 0`
- `requires_pickup_location = false`
- `requires_delivery_location = false`

Ce choix permet de laisser `/delivercontract` finaliser le contrat sans imposer dinventaire ou de position runtime supplementaire pour ce smoke MVP.

## 10. Rewards couvertes

Rewards configurees dans la fixture :

- `money` : `+150`
- `skill_xp` : `commerce +25`
- `reputation` : `merchant_guild +5`

Choix fondes sur lexistant local :

- `commerce` existe dans `server/Packages/gr-skills/Shared/SkillsConfig.lua`
- `merchant_guild` existe dans `database/seeds/reputation_mvp_seed.sql`

La cle `spatioport` na pas ete retenue car elle nest pas presente dans les reputations seed locales.

## 11. Interaction avec /delivercontract

La commande fixture naccorde aucune reward directement.

Elle se limite a creer un contrat acceptee et livrable, puis laisse `/delivercontract <contract_id>` executer le flux normal :

- completion contrat
- preparation du ledger
- tentative dattribution argent / skill / reputation
- mise a jour des statuts payment/rewards existants

## 12. Interaction avec le ledger

La fixture ne cree pas de grant `applied` a lavance.

Le ledger `contract_reward_grants` doit continuer a etre cree par le flux existant de livraison. Les commandes `/contractrewardstatus`, `/retrycontractrewards` et `/retryfailedcontractrewards` restent les seuls outils de diagnostic et reprise.

Lidempotence continue dêtre portee par le ledger existant : une reward deja `applied` ne doit pas etre rejouee.

## 13. Tests PostgreSQL effectués

Requetes executees en lecture seule :

- `\dt *contract*`
- `SELECT ... FROM contract_reward_grants ORDER BY id DESC LIMIT 20;`
- `SELECT ... FROM contracts ORDER BY id DESC LIMIT 10;`

Etat local observe :

- tables contracts presentes : `contracts`, `contract_route_templates`, `contract_delivery_locations`, `contract_reward_grants`
- `contract_reward_grants` contenait toujours `0 rows`
- la table `contracts` contenait un seul contrat local preexistant :
  - `id=1`
  - `title=Delivery`
  - `status=open`
  - `rewards_status=none`

Aucune modification manuelle de row na ete faite.

## 14. Tests runtime effectués ou restants

Aucun runtime nanos world na ete lance ici.

La fixture na donc pas ete testee en jeu dans cette session.

Scenario runtime restant a executer :

- `/createcontractrewardsmoke`
- `/delivercontract <contract_id>`
- `/contractrewardstatus <contract_id>`
- `/retrycontractrewards <contract_id>`
- `/contractrewardstatus <contract_id>`
- `/retrycontractrewards <contract_id>`
- `/retryfailedcontractrewards`

Verifications attendues :

- creation dun contrat livrable
- creation du ledger a la livraison
- rewards successful en `applied`
- rewards failed en `failed` avec message
- second retry sans double paiement / XP / reputation
- absence de `chat-command-not-supported`

## 15. Risques restants

- le runtime nanos world na pas confirme ici que `/delivercontract` accepte bien ce contrat debug sans item ni destination obligatoire ;
- le flux global reste non transactionnel entre DB, economie, skills et reputation ;
- la commande cree une nouvelle fixture a chaque execution, sans deduplication volontaire ;
- le repository na pas ete etendu, car les primitives existantes `CreateContract` + `AcceptContract` suffisaient pour ce MVP.

## 16. Message de commit recommandé

`test(contracts): add reward smoke fixture command`
