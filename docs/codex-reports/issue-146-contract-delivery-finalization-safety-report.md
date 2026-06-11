# Issue #146  Contract delivery finalization safety MVP

## 1. Résumé de limplémentation

Le lot durcit la finalisation de `/delivercontract` en déplaçant le verrou principal côté repository, en refusant explicitement les contrats déjà `completed`, `cancelled` ou `expired`, en revalidant le pickup avant `completed`, et en améliorant le mapping d’erreurs côté chat.

Le flux de récompenses existant est conservé. En revanche, le service ne masque plus un échec de paiement ou de rewards secondaires derrière un faux succès complet.

## 2. Agents consultés

- `software-architect`
- `backend-lua`
- `database-engineer`
- `security-reviewer`
- `qa-tester`
- `nanos-world-lua-agent`

Documentation relue avant modification :
- `docs/cahier-des-charges.md`
- `external/nanos-world-docs/docs/core-concepts/packages/packages-guide.md`
- `external/nanos-world-docs/docs/core-concepts/scripting/communicating-between-packages.md`
- `docs/codex-reports/issue-125-contract-pickup-locations-report.md`
- `docs/codex-reports/issue-128-contract-abandon-cancel-report.md`
- `docs/codex-reports/issue-129-contract-deadlines-report.md`
- `docs/codex-reports/issue-130-contract-expired-cargo-cleanup-report.md`
- `docs/codex-reports/issue-131-contract-completion-rewards-report.md`
- `docs/codex-reports/issue-144-player-active-contracts-status-report.md`
- `docs/codex-reports/issue-145-player-contract-delivery-report.md`

## 3. Fichiers créés

- `docs/codex-reports/issue-146-contract-delivery-finalization-safety-report.md`

## 4. Fichiers modifiés

- `server/Packages/gr-contracts/Server/ContractRepository.lua`
- `server/Packages/gr-contracts/Server/ContractService.lua`
- `server/Packages/gr-contracts/Server/Index.lua`

## 5. Fichiers explicitement non modifiés

- `server/Packages/gr-chat/Server/Index.lua`
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

Aucune migration ajoutée.

## 7. Sécurité /delivercontract

`/delivercontract` continue de vérifier :

- personnage actif ;
- appartenance du contrat ;
- statut actif ;
- deadline ;
- pickup effectué ;
- destination existante, active, calibrée ;
- proximité joueur / destination.

Le mapping distingue maintenant aussi :

- `contract-already-completed`
- `contract-cancelled`
- `contract-expired`

## 8. Anti double livraison

`ContractRepository:CompleteContract(...)` :

- recharge d’abord le contrat ;
- refuse si `assignee_character_id` ne correspond pas ;
- refuse si `status` est déjà `completed`, `cancelled` ou `expired` ;
- refuse si `requires_pickup_location = true` et `pickup_status ~= picked_up` ;
- ne passe `status='completed'` que pour un contrat encore `accepted`.

Si l’`UPDATE` ne retourne aucune ligne, le repository relit le contrat et remappe la vraie raison. Cela couvre mieux la double livraison et les courses concurrentes.

## 9. Anti double récompense

Le lot ne crée pas de second système de reward.

Le verrou MVP reste :

- un contrat déjà `completed` ne repasse jamais dans le flux normal ;
- `GrantContractRewards(...)` conserve son garde-fou `rewards_status = granted`.

Le service ne présente plus un succès plein si la phase rewards échoue après complétion.

## 10. Finalisation completed/cargo

La finalisation reste pilotée par le flux existant :

- retrait des items requis si nécessaire ;
- `CompleteContract(...)` ;
- paiement économie ;
- rewards skill / réputation.

Le repository garantit maintenant que `completed` ne peut pas être écrit pour :

- un contrat d’un autre personnage ;
- un contrat terminal ;
- un contrat pickup non récupéré.

`/mycontracts` reste cohérent car il ne liste que `status = accepted`.

## 11. Mapping erreurs

`/delivercontract` distingue maintenant explicitement :

- `Livraison impossible : contrat deja termine.`
- `Livraison impossible : contrat annule.`
- `Livraison impossible : contrat expire.`
- `Livraison impossible : vous devez d'abord recuperer le cargo.`

Si la DB passe bien le contrat en `completed` mais que le paiement ou des rewards échouent ensuite, le chat n’annonce plus un faux succès complet :

- `Contrat #<id> finalise, mais le paiement ou certaines recompenses ont echoue.`

## 12. Tests PostgreSQL effectués

Exécuté :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, assignee_character_id, status, pickup_status, source_route_key, required_item_key, required_item_quantity, reward_money, expires_at, completed_at, rewards_status, payment_status FROM contracts ORDER BY id DESC LIMIT 10;"
```

Constats :

- le schéma local expose bien `assignee_character_id`, `pickup_status`, `completed_at`, `rewards_status`, `payment_status` ;
- la base locale observée contient seulement 1 contrat `open` non assigné ;
- aucun cas réel `accepted -> picked_up -> completed` n’est disponible localement pour un test DB plus profond.

## 13. Tests runtime effectués ou restants

Runtime non exécuté dans ce lot.

Restent à faire :

```txt
/jobboard
/takejob scrap_to_spatioport
/mycontracts
/pickupcontract <contract_id>
/delivercontract <contract_id>
/delivercontract <contract_id>
/mycontracts
/contractstatus <contract_id>

/delivercontract 999999
/delivercontract <contract_id_non_pickup>
```

## 14. Risques restants

- pas de test runtime nanos world exécuté ici ;
- aucun `lua`, `luac` ou `luajit` local disponible pour validation syntaxique automatique ;
- le flux reste non transactionnel entre DB, économie, inventaire, skills et réputation ;
- si le paiement ou une reward échoue après passage `completed`, le contrat reste correctement verrouillé, mais une compensation atomique complète n’existe pas ;
- `/contractstatus` reste actuellement centré sur les contrats actifs, donc la lisibilité post-complétion détaillée reste limitée hors historique.

## 15. Résultat git status -sb

```txt
## feature/issue-146-contract-delivery-finalization-safety
 M server/Packages/gr-contracts/Server/ContractRepository.lua
 M server/Packages/gr-contracts/Server/ContractService.lua
 M server/Packages/gr-contracts/Server/Index.lua
?? docs/codex-reports/issue-146-contract-delivery-finalization-safety-report.md
```

## 16. Message de commit recommandé

```txt
fix(contracts): secure delivery finalization
```
