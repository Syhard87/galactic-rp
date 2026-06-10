# Issue #143  Contract job board details MVP

## 1. Resume de limplementation

Les commandes joueur du job board ont ete reformatees pour etre plus lisibles dans le chat nanos world, sans changer la logique metier de filtrage et de refus ajoutee en `#142`.

## 2. Agents consultes

- `software-architect`
- `backend-lua`
- `security-reviewer`
- `qa-tester`
- `nanos-world-lua-agent`

Documentation relue avant modification :
- `docs/cahier-des-charges.md`
- `external/nanos-world-docs/docs/core-concepts/packages/packages-guide.md`
- `external/nanos-world-docs/docs/core-concepts/scripting/communicating-between-packages.md`

## 3. Fichiers crees

- `docs/codex-reports/issue-143-contract-job-board-details-report.md`

## 4. Fichiers modifies

- `server/Packages/gr-contracts/Server/Index.lua`

## 5. Fichiers explicitement non modifies

- `server/Packages/gr-contracts/Server/ContractService.lua`
- `server/Packages/gr-contracts/Server/ContractRepository.lua`
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

## 6. Migration SQL ajoutee ou non

Aucune migration ajoutee.

## 7. Amelioration /jobboard

- affichage reformate en lignes lisibles :
  - `route_key`
  - `item xquantite`
  - `reward`
  - `pickup -> destination`
  - `deadline`
- ajout d une seconde ligne :
  - `Prendre : /takejob <route_key>`
- le message vide reste :
  - `Aucune mission jouable disponible actuellement.`

## 8. Amelioration /availablejobs

- en tete changee en :
  - `Missions disponibles pour votre personnage :`
- chaque mission disponible affiche maintenant :
  - details courts
  - ligne `Prendre : /takejob <route_key>`

## 9. Amelioration /lockedjobs

- les routes bloquees par prerequis affichent maintenant :
  - details courts de mission
  - `reason=...`
- les routes techniquement indisponibles conservent le format `#142` :
  - `- route_key indisponible : issue1, issue2`

## 10. Amelioration /jobinfo

- `/jobinfo` distingue maintenant :
  - `DISPONIBLE`
  - `BLOQUEE`
  - `INDISPONIBLE`
- route disponible :
  - item
  - reward
  - route
  - deadline
  - prerequis
  - commande `/takejob`
- route bloquee :
  - item
  - reward
  - route
  - deadline
  - liste des prerequis manquants
- route indisponible techniquement :
  - `Issues :`
  - liste des issues de diagnostic

## 11. Securite joueur

- aucune commande admin exposee
- aucune mission indisponible n est rendue prenable
- la logique de securite de `#142` n a pas ete modifiee
- `/jobinfo` reutilise `GetJobRequirements(...)` pour rester coherent avec les refus existants

## 12. Tests PostgreSQL effectues

Execute :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, is_active, item_key, item_quantity, reward_money, pickup_location_key, delivery_location_key, deadline_seconds FROM contract_route_templates ORDER BY key;"
```

Constats :
- 4 routes presentes
- les routes sont toujours actives en base
- les deadlines sont bien renseignees sur les templates observes

## 13. Tests runtime effectues ou restants

Runtime non execute dans ce lot.

Restent a faire :

```txt
/jobboard
/availablejobs
/lockedjobs
/jobinfo scrap_to_spatioport
/jobinfo fuel_to_spatioport
/takejob scrap_to_spatioport
```

## 14. Risques restants

- pas de test runtime nanos world execute ici
- aucun `lua`, `luac` ou `luajit` local disponible pour validation syntaxique automatique
- si toutes les routes restent techniquement non calibrees localement, `/jobboard` peut rester vide, ce qui sera conforme a `#142`
- `git diff --check` peut encore ne remonter que des warnings `LF -> CRLF`

## 15. Resultat git status -sb

```txt
## feature/issue-143-contract-job-board-details
 M server/Packages/gr-contracts/Server/Index.lua
?? docs/codex-reports/issue-143-contract-job-board-details-report.md
```

## 16. Message de commit recommande

```txt
feat(contracts): improve job board details
```
