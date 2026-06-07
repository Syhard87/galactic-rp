# Issue #125  Contract pickup locations MVP

## 1. Résumé de limplémentation

Ajout dun flux MVP de transport pickup + delivery dans `gr-contracts`.

Le lot ajoute :

- de nouveaux champs pickup sur `contracts` ;
- une creation de contrat transport via `/createhaulcontract` ;
- une action serveur `/pickupcontract` qui donne la cargaison si le joueur est au bon point de recuperation ;
- un verrou sur `/completecontract` tant que la cargaison na pas ete recuperee.

Les anciens contrats continuent de fonctionner avec :

- `requires_pickup_location = false`
- `pickup_status = none`

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
- `docs/codex-reports/issue-123-contract-delivery-locations-report.md`
- `docs/codex-reports/issue-124-contract-delivery-location-tools-report.md`

## 3. Fichiers créés

- `database/migrations/030_contract_pickup_locations.sql`
- `docs/codex-reports/issue-125-contract-pickup-locations-report.md`

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
- `database/seeds/`
- `Config.toml`

## 6. Migration SQL ajoutée

Fichier ajoute :

```txt
database/migrations/030_contract_pickup_locations.sql
```

Colonnes ajoutees sur `contracts` :

- `pickup_location_key`
- `requires_pickup_location`
- `pickup_status`
- `picked_up_at`

Contrainte ajoutee :

- `pickup_status IN ('none', 'pending', 'picked_up')`

## 7. Contrats transport pickup + delivery

Les contrats transport crees par `/createhaulcontract` enregistrent :

- `required_item_key`
- `required_item_quantity`
- `consume_required_items = true`
- `pickup_location_key`
- `requires_pickup_location = true`
- `pickup_status = pending`
- `delivery_location_key`
- `requires_delivery_location = true`

Le MVP reutilise `contract_delivery_locations` pour le pickup et la livraison.

## 8. Commandes /createhaulcontract et /pickupcontract

Commandes ajoutees :

- `/createhaulcontract <item_key> <quantity> <reward_money> <pickup_location_key> <delivery_location_key> <description>`
- `/pickupcontract <contract_id>`

Protection conservee :

- `gr_contracts_debug_commands_enabled`
- `gr_contracts_debug_allowed_platform_ids`

## 9. Validation de proximité pickup

Le pickup verifie cote serveur :

- que le contrat existe ;
- quil est accepte ;
- quil est assigne au personnage actif ;
- que `pickup_status = pending` ;
- que le point de pickup existe et est actif ;
- que la position du point est complete ;
- que la position du `ControlledCharacter` est disponible ;
- que la distance au pickup est inferieure ou egale au radius.

La position du joueur vient uniquement de :

- `player:GetControlledCharacter()`
- `controlled_character:GetLocation()`

## 10. Impact sur /completecontract

Avant le flux delivery existant, `/completecontract` refuse maintenant si :

- `requires_pickup_location = true`
- et `pickup_status ~= 'picked_up'`

Dans ce cas :

- pas de retrait item ;
- pas de paiement ;
- pas de completion.

Si le pickup est valide, le flux existant de `#122` et `#123` continue :

- verification destination ;
- retrait item ;
- completion contrat ;
- paiement economie.

## 11. Intégration inventaire

`/pickupcontract` donne la cargaison via :

- `GRInventoryBridge.AddItem(...)`

Le statut pickup nest marque `picked_up` quapres succes inventaire.

Si le marquage pickup echoue apres ajout inventaire, une compensation est tentee via :

- `GRInventoryBridge.RemoveItem(...)`

La completion continue dutiliser :

- `GRInventoryBridge.ListInventory(...)`
- `GRInventoryBridge.RemoveItem(...)`

## 12. Tests PostgreSQL effectués

Migration executee :

```powershell
Get-Content -Raw ".\database\migrations\030_contract_pickup_locations.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
```

Verification executees :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, type, reward_money, status, payment_status, required_item_key, required_item_quantity, pickup_location_key, requires_pickup_location, pickup_status, picked_up_at, delivery_location_key, requires_delivery_location FROM contracts ORDER BY id;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, name, position_x, position_y, position_z, radius, is_active FROM contract_delivery_locations ORDER BY key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, item_key, quantity, metadata_json FROM inventory_items ORDER BY character_id, item_key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, character_id, target_character_id, amount, currency, wallet, type, reason, created_at FROM bank_transactions ORDER BY id DESC LIMIT 20;"
```

Constats :

- la migration `030` est appliquee ;
- `contracts` expose maintenant `pickup_location_key`, `requires_pickup_location`, `pickup_status`, `picked_up_at` ;
- les points de `contract_delivery_locations` sont toujours presents ;
- `inventory_items` et `bank_transactions` restent lisibles.

## 13. Tests runtime effectués ou restants

Tests runtime non executes dans ce lot.

Restent a faire :

```txt
/deliverylocations
/setdeliverylocationhere industrial_zone 500
/setdeliverylocationhere spatioport 500

/createhaulcontract scrap 5 200 industrial_zone spatioport Transporter du scrap au spatioport
/contracts
/acceptcontract 1
/mycontracts

/completecontract 1
/pickupcontract 1
/inv
/completecontract 1
/inv
/money
/transactions
```

Attendus :

- `/completecontract 1` avant pickup refuse avec cargaison non recuperee ;
- `/pickupcontract 1` donne les items et passe `pickup_status` a `picked_up` ;
- `/completecontract 1` proche de destination retire les items et paie ;
- pas de double pickup ;
- pas de double paiement.

## 14. Risques restants

- pas de test runtime nanos world execute ici ;
- la compensation inventaire sur echec de marquage pickup reste applicative et non transactionnelle ;
- le lot suppose que `GRInventoryBridge.AddItem` et `GRInventoryBridge.RemoveItem` restent disponibles comme dans `#122` ;
- `git diff --check` ne remonte ici que des warnings `LF -> CRLF`.

## 15. Résultat git status -sb

Resultat obtenu apres implementation :

```txt
## feature/issue-125-contract-pickup-locations
 M server/Packages/gr-chat/Server/Index.lua
 M server/Packages/gr-contracts/Server/ContractRepository.lua
 M server/Packages/gr-contracts/Server/ContractService.lua
 M server/Packages/gr-contracts/Server/Index.lua
?? database/migrations/030_contract_pickup_locations.sql
?? docs/codex-reports/issue-125-contract-pickup-locations-report.md
```

## 16. Message de commit recommandé

```txt
feat(contracts): add pickup locations
```
