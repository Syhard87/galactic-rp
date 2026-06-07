# Issue #124  Contract delivery location tools MVP

## 1. Résumé de limplémentation

Ajout doutils debug dans `gr-contracts` pour calibrer les points de livraison directement depuis la position serveur du joueur.

Le lot ajoute :

- la lecture detaillee dun point de livraison ;
- la mise a jour de `position_x`, `position_y`, `position_z` et `radius` depuis `player:GetControlledCharacter():GetLocation()`.

Le flux de completion des contrats de livraison ciblee reste compatible avec `#123` et peut maintenant etre debloque apres calibration runtime.

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
- `docs/codex-reports/issue-123-contract-delivery-locations-report.md`

## 3. Fichiers créés

- `docs/codex-reports/issue-124-contract-delivery-location-tools-report.md`

## 4. Fichiers modifiés

- `server/Packages/gr-contracts/Server/ContractRepository.lua`
- `server/Packages/gr-contracts/Server/ContractService.lua`
- `server/Packages/gr-contracts/Server/Index.lua`
- `server/Packages/gr-chat/Server/Index.lua`

## 5. Fichiers explicitement non modifiés

- `database/migrations/`
- `database/seeds/`
- `server/Packages/gr-inventory/`
- `server/Packages/gr-economy/`
- `server/Packages/gr-gathering/`
- `server/Packages/gr-shops/`
- `Config.toml`

## 6. Commandes ajoutées

- `/deliverylocationinfo <location_key>`
- `/setdeliverylocationhere <location_key> [radius]`

Les deux commandes restent protegees par :

- `gr_contracts_debug_commands_enabled`
- `gr_contracts_debug_allowed_platform_ids`

## 7. Mise à jour des positions de livraison

Ajouts repository :

- `UpdateDeliveryLocationPosition(location_key, position_x, position_y, position_z, radius, callback)`

Ajouts service :

- `GetDeliveryLocationInfo(location_key, callback)`
- `SetDeliveryLocationHere(player, location_key, radius, callback)`

Regles appliquees :

- `location_key` doit etre valide ;
- la location doit exister ;
- la location doit etre active ;
- la position vient uniquement du serveur ;
- le radius doit etre `> 0` et `<= 5000` ;
- si le radius nest pas fourni, la valeur existante ou `500` est reutilisee.

## 8. Sécurité debug

Le joueur ne fournit jamais de coordonnees arbitraires.

La position retenue provient de :

- `player:GetControlledCharacter()`
- `controlled_character:GetLocation()`

En cas dindisponibilite :

- refus propre avec `player-position-unavailable`.

La mise a jour DB est limitee aux locations actives.

## 9. Tests PostgreSQL effectués

Commandes executees :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, name, position_x, position_y, position_z, radius, is_active FROM contract_delivery_locations ORDER BY key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, name, position_x, position_y, position_z, radius, is_active, updated_at FROM contract_delivery_locations ORDER BY key;"
```

Constats :

- les 5 points de livraison sont presents ;
- les positions sont encore `NULL` avant calibration runtime ;
- `updated_at` est bien lisible.

La verification post-calibration reste a faire apres execution de `/setdeliverylocationhere` en jeu.

## 10. Tests runtime effectués ou restants

Tests runtime non executes dans ce lot.

Restent a faire :

```txt
/deliverylocations
/deliverylocationinfo spatioport
/setdeliverylocationhere spatioport 500
/deliverylocationinfo spatioport
/giveitem scrap 5
/createdeliverycontractat scrap 5 150 spatioport Livrer du scrap au spatioport
/contracts
/acceptcontract 1
/completecontract 1
/inv
/money
/transactions
```

Attendus :

- `/deliverylocationinfo` affiche les coordonnees avant/apres ;
- `/setdeliverylocationhere` persiste la position actuelle ;
- `/completecontract` ne bloque plus sur `position destination manquante` si le joueur reste proche.

## 11. Risques restants

- pas de test runtime nanos world execute ici ;
- pas de verification automatique locale de syntaxe Lua disponible dans lenvironnement ;
- le lot ne fait que calibrer la destination ; il ne change pas la logique de paiement/compensation deja en place dans `#122` et `#123` ;
- `git diff --check` peut encore remonter uniquement des warnings `LF -> CRLF` selon la configuration locale.

## 12. Résultat git status -sb

Resultat attendu apres ce lot :

```txt
## feature/issue-124-contract-delivery-location-tools
 M server/Packages/gr-chat/Server/Index.lua
 M server/Packages/gr-contracts/Server/ContractRepository.lua
 M server/Packages/gr-contracts/Server/ContractService.lua
 M server/Packages/gr-contracts/Server/Index.lua
?? docs/codex-reports/issue-124-contract-delivery-location-tools-report.md
```

## 13. Message de commit recommandé

```txt
feat(contracts): add delivery location tools
```
