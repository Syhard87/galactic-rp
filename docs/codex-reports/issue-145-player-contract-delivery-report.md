# Issue #145  Player contract delivery MVP

## 1. Resume de limplementation

Le lot ajoute une commande joueur `/delivercontract` qui reutilise le flux serveur existant de completion de contrat, avec un meilleur filtrage proprietaire/personnage et un mapping d erreurs lisible pour le chat nanos world.

## 2. Agents consultes

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

## 3. Fichiers crees

- `docs/codex-reports/issue-145-player-contract-delivery-report.md`

## 4. Fichiers modifies

- `server/Packages/gr-contracts/Server/ContractService.lua`
- `server/Packages/gr-contracts/Server/Index.lua`
- `server/Packages/gr-chat/Server/Index.lua`

## 5. Fichiers explicitement non modifies

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

## 6. Migration SQL ajoutee ou non

Aucune migration ajoutee.

## 7. Commande /delivercontract

- ajout de `/delivercontract <contract_id>` comme commande joueur normale
- ajout dans `gr-chat` de :
  - `delivercontract`
- ajout bridge :
  - `GRContractsBridge.DeliverContract(...)`
- la commande renvoie :
  - succes de livraison
  - reward monetaire
  - recompenses skill/reputation seulement si effectivement `granted`

## 8. Verification proprietaire/personnage

Le service :

- recupere le personnage actif depuis le joueur via le bridge personnages existant
- charge le contrat par id
- refuse si `assignee_character_id` ne correspond pas au personnage actif
- renvoie dans ce cas :
  - `Contrat introuvable pour votre personnage.`

Aucune information sur les contrats d un autre personnage n est exposee.

## 9. Verification pickup/destination/deadline

Avant completion, `DeliverContract(...)` verifie :

- contrat actif
- contrat non `completed`
- contrat non `cancelled`
- contrat non expire via `EnsureContractNotExpired(...)`
- cargo deja pickup si `requires_pickup_location = true`
- destination presente
- destination active
- destination calibree
- joueur dans le rayon de destination

Mapping joueur ajoute :

- `Livraison impossible : vous devez d'abord recuperer le cargo.`
- `Utilisez /pickupcontract <id> au point de pickup.`
- `Livraison impossible : destination indisponible.`
- `Issue : destination introuvable|inactive|non calibree.`
- `Livraison impossible : vous devez etre a la destination <location_key>.`
- `Livraison impossible : contrat expire.`
- `Livraison impossible : contrat deja termine ou annule.`

## 10. Completion et recompenses

`DeliverContract(...)` ne cree pas un nouveau chemin de completion.

Il reutilise :

- `CompleteContract(...)`
- paiement economie existant
- `GrantContractRewards(...)`

Au succes :

- le contrat passe dans le statut terminal existant
- le paiement est gere par le flux existant
- les rewards skill/reputation restent gerees par le systeme existant
- la commande affiche :
  - `Contrat #id livre avec succes.`
  - `Reward : <montant> credits`
  - `Recompenses : ...` seulement si `rewards_status = granted`

## 11. Securite anti double recompense

Le lot evite la double attribution en reutilisant les garde-fous deja presents dans `CompleteContract(...)` et `GrantContractRewards(...)` :

- pas de deuxieme systeme de paiement
- pas de deuxieme systeme de rewards
- pas de completion si le contrat n est plus actif
- pas de livraison possible si le contrat est deja termine ou annule

## 12. Tests PostgreSQL effectues

Execute :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, assignee_character_id, status, source_route_key, pickup_status, required_item_key, required_item_quantity, reward_money, expires_at, completed_at FROM contracts ORDER BY id DESC LIMIT 10;"
```

Constats :

- le schema local utilise `assignee_character_id`, `source_route_key` et `required_item_key`
- la base locale observee contient seulement 1 contrat `open` non assigne
- aucun contrat `accepted` local disponible pour valider un vrai flux de livraison en base

## 13. Tests runtime effectues ou restants

Runtime non execute dans ce lot.

Restent a faire :

```txt
/jobboard
/takejob scrap_to_spatioport
/mycontracts
/pickupcontract <contract_id>
/contractstatus <contract_id>
/delivercontract <contract_id>
/mycontracts
/contractstatus <contract_id>

/delivercontract 999999
/delivercontract <contract_id_non_pickup>
```

## 14. Risques restants

- pas de test runtime nanos world execute ici
- aucun `lua`, `luac` ou `luajit` local disponible pour validation syntaxique automatique
- la base locale n expose pas de contrat `accepted`, donc le flux complet pickup -> delivery -> rewards reste a valider en runtime
- `/delivercontract` repose sur `CompleteContract(...)`, qui peut encore retourner des erreurs internes non mappees specifiquement et tomber dans `Livraison impossible.`
- `git diff --check` peut encore ne remonter que des warnings `LF -> CRLF`

## 15. Resultat git status -sb

```txt
## feature/issue-145-player-contract-delivery
 M server/Packages/gr-chat/Server/Index.lua
 M server/Packages/gr-contracts/Server/ContractService.lua
 M server/Packages/gr-contracts/Server/Index.lua
?? docs/codex-reports/issue-145-player-contract-delivery-report.md
```

## 16. Message de commit recommande

```txt
feat(contracts): add player contract delivery
```
