# Issue #144  Player active contracts status MVP

## 1. Resume de limplementation

Le lot ajoute une vue joueur en lecture seule sur les contrats actifs via `/mycontracts` et `/contractstatus`, avec filtrage strict par personnage actif, statut affiche adapte au pickup, deadline restante simplifiee et prochaine action conseillee.

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

## 3. Fichiers crees

- `docs/codex-reports/issue-144-player-active-contracts-status-report.md`

## 4. Fichiers modifies

- `server/Packages/gr-contracts/Server/ContractRepository.lua`
- `server/Packages/gr-contracts/Server/ContractService.lua`
- `server/Packages/gr-contracts/Server/Index.lua`
- `server/Packages/gr-chat/Server/Index.lua`

## 5. Fichiers explicitement non modifies

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

## 7. Commande /mycontracts

- `/mycontracts` devient une commande joueur normale, non debug
- elle liste uniquement les contrats actifs du personnage courant :
  - `status = accepted`
  - `assignee_character_id = personnage actif`
- chaque ligne affiche :
  - `contract_id`
  - `route_label`
  - `display_status`
  - `item xquantite`
  - `pickup -> destination`
  - `reward`
  - `deadline restante`
- une seconde ligne propose :
  - `Detail : /contractstatus <id>`

## 8. Commande /contractstatus

- `/contractstatus <contract_id>` devient une commande joueur normale, non debug
- elle retourne le detail uniquement si le contrat actif appartient au personnage courant
- la fiche affiche :
  - `Contrat #id : route`
  - `Status`
  - `Item`
  - `Reward`
  - `Route`
  - `Deadline`
  - `Prochaine action`

## 9. Securite joueur / isolation personnage

- ajout repository :
  - `ListActiveContractsByCharacter(...)`
  - `GetContractByIdForCharacter(...)`
- filtrage SQL par :
  - `assignee_character_id`
  - `status = 'accepted'`
- un contrat d un autre personnage n est jamais retourne
- un contrat terminal, annule ou expire ne remonte plus dans `/mycontracts`
- `/contractstatus` retourne `Contrat introuvable pour votre personnage.` si le contrat n est pas visible pour ce personnage

## 10. Prochaine action joueur

Le service enrichit les contrats actifs avec :

- `display_status`
- `deadline_remaining_text`
- `next_action`
- `route_label`

Regles MVP :

- `accepted` + `pickup_status = pending` :
  - `allez au pickup <location> puis utilisez /pickupcontract <id>`
- `accepted` + `pickup_status = picked_up` :
  - `allez a la destination <location> puis utilisez /completecontract <id>`
- pas de deadline :
  - `Deadline : none`

## 11. Tests PostgreSQL effectues

Execute :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, assignee_character_id, status, source_route_key, required_item_key, required_item_quantity, reward_money, expires_at, pickup_status FROM contracts ORDER BY id DESC LIMIT 10;"
```

Constats :

- le schema local utilise `assignee_character_id` et `source_route_key`, pas `character_id` / `route_key`
- la base locale observee contient 1 contrat `open` non assigne
- aucun contrat `accepted` disponible localement pour valider un vrai affichage joueur sur donnees reelles

## 12. Tests runtime effectues ou restants

Runtime non execute dans ce lot.

Restent a faire :

```txt
/jobboard
/takejob scrap_to_spatioport
/mycontracts
/contractstatus <contract_id>
/pickupcontract <contract_id>
/contractstatus <contract_id>
/abandoncontract <contract_id>
/mycontracts
```

## 13. Risques restants

- pas de test runtime nanos world execute ici
- aucun `lua`, `luac` ou `luajit` local disponible pour validation syntaxique automatique
- la base locale n expose pas de contrat `accepted`, donc le rendu final sur vrai contrat actif reste a valider en runtime
- le statut affiche `picked_up` est derive de `pickup_status` alors que le statut DB reste `accepted`, ce qui est volontaire pour la lisibilite joueur
- `git diff --check` peut encore ne remonter que des warnings `LF -> CRLF`

## 14. Resultat git status -sb

```txt
## feature/issue-144-player-active-contracts-status
 M server/Packages/gr-chat/Server/Index.lua
 M server/Packages/gr-contracts/Server/ContractRepository.lua
 M server/Packages/gr-contracts/Server/ContractService.lua
 M server/Packages/gr-contracts/Server/Index.lua
?? docs/codex-reports/issue-144-player-active-contracts-status-report.md
```

## 15. Message de commit recommande

```txt
feat(contracts): show player active contracts
```
