# Issue #127  Contract job board MVP

## 1. Résumé de limplémentation

Ajout dun job board MVP côté serveur dans `gr-contracts`, basé directement sur `contract_route_templates`. Les routes actives servent de missions disponibles. Un joueur peut lister les missions, consulter le détail dune route et prendre une mission qui crée puis assigne immédiatement un contrat haul.

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

- `database/migrations/032_contract_job_board.sql`
- `docs/codex-reports/issue-127-contract-job-board-report.md`

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

## 6. Job board routes

Le job board lit directement `contract_route_templates`.

- une mission disponible = une route active
- aucune table séparée de missions instanciées na été ajoutée
- la liste visible par `/jobboard` est filtrée sur `is_active = true`

## 7. Commandes /jobboard /jobinfo /takejob

Commandes ajoutées :

- `/jobboard`
- `/jobinfo <route_key>`
- `/takejob <route_key>`

`gr-chat` autorise maintenant :

- `jobboard`
- `jobinfo`
- `takejob`

## 8. Intégration route templates

Ajouts service/repository :

- `ListJobBoardRoutes(callback)`
- `GetJobBoardRoute(route_key, callback)`
- `TakeJobFromRoute(character_id, route_key, callback)`

Le client ne fournit que `route_key`. Tous les paramètres sensibles viennent de la DB :

- `item_key`
- `item_quantity`
- `reward_money`
- `pickup_location_key`
- `delivery_location_key`

## 9. Création + assignation du contrat

Une migration légère `032_contract_job_board.sql` ajoute :

- `contracts.source_route_key`
- `contracts.job_source`

Valeurs utilisées :

- `job_source = 'route_template'` pour `/createhaulfromroute`
- `job_source = 'job_board'` pour `/takejob`

`/takejob` :

1. valide le personnage actif ;
2. vérifie la route ;
3. vérifie les limites de jobs actifs ;
4. crée un contrat haul depuis la route ;
5. assigne immédiatement le contrat au personnage.

En cas déchec dassignation après création, une tentative de nettoyage par `CancelContract(...)` est faite si le contrat est encore `open`.

## 10. Contrôle anti-abus MVP

Contrôle simple ajouté côté service :

- maximum `3` jobs actifs par personnage

Le comptage cible les contrats acceptés assignés au personnage qui correspondent à un flux transport (`job_board` explicite ou contrat avec pickup requis).

## 11. Tests PostgreSQL effectués

Exécutés :

```powershell
Get-Content -Raw ".\database\migrations\032_contract_job_board.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, item_key, item_quantity, reward_money, pickup_location_key, delivery_location_key, is_active FROM contract_route_templates ORDER BY key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, name, position_x, position_y, position_z, radius, is_active FROM contract_delivery_locations ORDER BY key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, type, reward_money, status, payment_status, required_item_key, required_item_quantity, pickup_location_key, pickup_status, delivery_location_key, source_route_key, job_source FROM contracts ORDER BY id DESC LIMIT 10;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT column_name FROM information_schema.columns WHERE table_name = 'contracts' ORDER BY ordinal_position;"
```

Constats :

- migration `032` appliquée
- `source_route_key` et `job_source` présents sur `contracts`
- `contract_route_templates` contient `4` routes actives
- `contract_delivery_locations` reste cohérente

## 12. Tests runtime effectués ou restants

Non exécutés dans ce lot :

```txt
/jobboard
/jobinfo scrap_to_spatioport
/takejob scrap_to_spatioport
/mycontracts
/pickupcontract 1
/completecontract 1
```

## 13. Risques restants

- aucun test runtime nanos world exécuté ici
- le cleanup après échec dassignation reste best-effort
- les points pickup/delivery peuvent encore bloquer proprement si leurs positions DB ne sont pas calibrées
- aucun contrôle plus fin par type de mission, seulement une limite simple à `3`
- `git diff --check` ne remonte ici que des warnings `LF -> CRLF`

## 14. Résultat git status -sb

```txt
## feature/issue-127-contract-job-board
 M server/Packages/gr-chat/Server/Index.lua
 M server/Packages/gr-contracts/Server/ContractRepository.lua
 M server/Packages/gr-contracts/Server/ContractService.lua
 M server/Packages/gr-contracts/Server/Index.lua
?? database/migrations/032_contract_job_board.sql
?? docs/codex-reports/issue-127-contract-job-board-report.md
```

## 15. Message de commit recommandé

```txt
feat(contracts): add job board
```
