# Issue #123  Contract delivery locations MVP

## 1. Résumé de limplémentation

Ajout dun systeme MVP de points de livraison serveur pour les contrats `delivery`.

Les contrats existants restent compatibles grace a :

- `requires_delivery_location = false` par defaut ;
- `delivery_location_key = NULL` par defaut.

Un nouveau flux permet maintenant de creer un contrat de livraison lie a un point serveur, puis de refuser `/completecontract` si le joueur nest pas proche de la destination.

## 2. Agents consultés

- `software-architect`
- `backend-lua`
- `database-engineer`
- `security-reviewer`
- `qa-tester`
- `nanos-world-lua-agent`

Documentation consultee avant modification :

- `docs/cahier-des-charges.md`
- `external/nanos-world-docs/docs/core-concepts/packages/packages-guide.md`
- `external/nanos-world-docs/docs/core-concepts/scripting/communicating-between-packages.md`
- `docs/codex-reports/issue-122-contract-item-delivery-report.md`

## 3. Fichiers créés

- `database/migrations/029_contract_delivery_locations.sql`
- `database/seeds/contract_delivery_locations_mvp_seed.sql`
- `docs/codex-reports/issue-123-contract-delivery-locations-report.md`

## 4. Fichiers modifiés

- `server/Packages/gr-contracts/Server/ContractRepository.lua`
- `server/Packages/gr-contracts/Server/ContractService.lua`
- `server/Packages/gr-contracts/Server/Index.lua`
- `server/Packages/gr-chat/Server/Index.lua`

## 5. Fichiers explicitement non modifiés

- `server/Packages/gr-inventory/`
- `server/Packages/gr-economy/`
- `server/Packages/gr-gathering/`
- `server/Packages/gr-shops/`
- `Config.toml`

Note : `server/Packages/gr-contracts/Package.toml` etait deja modifie dans le worktree avant ce lot et na pas ete touche ici.

## 6. Migration SQL ajoutée

Migration ajoutee :

- `database/migrations/029_contract_delivery_locations.sql`

Contenu principal :

- creation de `contract_delivery_locations`
- ajout de `contracts.delivery_location_key`
- ajout de `contracts.requires_delivery_location`
- check `radius > 0`
- indexes sur `key` et `is_active`

## 7. Seed MVP ajouté

Seed ajoute :

- `database/seeds/contract_delivery_locations_mvp_seed.sql`

Points seedes :

- `spatioport`
- `market`
- `industrial_zone`
- `medical_kiosk`
- `government_office`

Pour ce MVP :

- positions `NULL`
- `radius = 500`
- `is_active = true`

## 8. Points de livraison

Ajout des concepts :

- `contract_delivery_locations`
- `contracts.delivery_location_key`
- `contracts.requires_delivery_location`

Ajout repository :

- `ListDeliveryLocations(callback)`
- `GetDeliveryLocation(location_key, callback)`

Normalisation ajoutee :

- `delivery_location_key`
- `requires_delivery_location`
- normalisation robuste des booleens PostgreSQL

## 9. Commandes /deliverylocations et /createdeliverycontractat

Commandes ajoutees :

- `/deliverylocations`
- `/createdeliverycontractat <item_key> <quantity> <reward_money> <location_key> <description>`

Comportement :

- listing des points de livraison actifs/inactifs
- creation dun contrat `delivery` cible
- la commande historique `/createdeliverycontract` reste disponible

## 10. Validation de proximité livraison

La verification est faite cote serveur dans `ContractService`.

Source de position joueur retenue, conforme aux usages deja presents dans le projet :

- `player:GetControlledCharacter()`
- `controlled_character:GetLocation()`

Regles :

- si `requires_delivery_location = false`, ancien comportement conserve ;
- si `requires_delivery_location = true`, le service charge la location ;
- refuse si location introuvable ou inactive ;
- refuse si `position_x/y/z` manquants ;
- refuse si position joueur indisponible ;
- refuse si distance `> radius`.

Erreurs gerees :

- `delivery-location-not-found`
- `delivery-location-inactive`
- `delivery-location-position-missing`
- `player-position-unavailable`
- `too-far-from-delivery-location`

## 11. Impact sur /completecontract

Nouveau flux de completion :

1. verifier que le contrat est accepte par lassigne ;
2. si une destination est requise, verifier la proximite serveur ;
3. verifier les items requis ;
4. retirer les items requis ;
5. completer le contrat ;
6. payer via `GREconomyBridge.AddMoney(...)` ;
7. tenter une compensation inventaire si le paiement echoue apres retrait item.

Le check de position est donc effectue avant retrait item et avant paiement.

## 12. Tests PostgreSQL effectués

Commandes executees :

```powershell
Get-Content -Raw ".\database\migrations\029_contract_delivery_locations.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
Get-Content -Raw ".\database\seeds\contract_delivery_locations_mvp_seed.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, name, location_type, position_x, position_y, position_z, radius, is_active FROM contract_delivery_locations ORDER BY key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, type, reward_money, status, payment_status, required_item_key, required_item_quantity, delivery_location_key, requires_delivery_location FROM contracts ORDER BY id;"
```

Constats :

- migration `029` appliquee ;
- table `contract_delivery_locations` presente ;
- 5 points de livraison seedes ;
- colonnes `delivery_location_key` et `requires_delivery_location` presentes sur `contracts`.

## 13. Tests runtime effectués ou restants

Tests runtime non executes dans ce lot.

Restent a faire :

```txt
/deliverylocations
/giveitem scrap 5
/createdeliverycontractat scrap 5 150 spatioport Livrer du scrap au spatioport
/contracts
/acceptcontract 1
/mycontracts
/completecontract 1
```

Attendu MVP actuel avec positions `NULL` :

- `/completecontract` doit refuser proprement avec destination invalide/manquante si `requires_delivery_location=true`.

## 14. Risques restants

- pas de test runtime nanos world execute ici ;
- les points seedes ont des positions `NULL`, donc les contrats cibles refuseront la completion tant quune position DB nest pas renseignee ;
- pas datomicite SQL parfaite entre retrait item, changement de statut contrat et paiement ;
- si la compensation inventaire echoue apres echec paiement, le contrat peut rester dans un etat partiellement incoherent, comme deja documente sur le lot #122.

## 15. Résultat git status -sb

Resultat obtenu :

```txt
## feature/issue-123-contract-delivery-locations
 M server/Packages/gr-chat/Server/Index.lua
 M server/Packages/gr-contracts/Package.toml
 M server/Packages/gr-contracts/Server/ContractRepository.lua
 M server/Packages/gr-contracts/Server/ContractService.lua
 M server/Packages/gr-contracts/Server/Index.lua
?? database/migrations/029_contract_delivery_locations.sql
?? database/seeds/contract_delivery_locations_mvp_seed.sql
?? docs/codex-reports/issue-123-contract-delivery-locations-report.md
```

Le changement sur `server/Packages/gr-contracts/Package.toml` etait preexistant au lot et na pas ete modifie ici.

## 16. Message de commit recommandé

```txt
feat(contracts): add delivery locations
```
