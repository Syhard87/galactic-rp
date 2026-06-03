# Issue #107  Economy foundation

## 1. Résumé de limplémentation

Cette issue ajoute une fondation serveur `gr-economy` isolée, avec :

- une migration SQL idempotente `017_economy_foundation.sql` ;
- une table `bank_transactions` pour journaliser les opérations ;
- un package nanos world `gr-economy` structuré en `Shared/` et `Server/` ;
- un bridge `GREconomyBridge` pour les futures intégrations ;
- des commandes debug protégées par custom settings.

Le lot ne refactorise pas `gr-contracts` et ne modifie pas le vrai `Config.toml`.

## 2. Agents consultés

- `software-architect`
- `backend-lua`
- `database-engineer`
- `security-reviewer`
- `qa-tester`
- `nanos-world-lua-agent`

Documentation nanos world relue avant modification :

- `external/nanos-world-docs/docs/getting-started/essential-concepts.mdx`
- `external/nanos-world-docs/docs/core-concepts/packages/packages-guide.md`
- `external/nanos-world-docs/docs/core-concepts/scripting/communicating-between-packages.md`
- `external/nanos-world-docs/docs/scripting-reference/utility-libraries/json.mdx`

## 3. Fichiers créés

- `database/migrations/017_economy_foundation.sql`
- `server/Packages/gr-economy/Package.toml`
- `server/Packages/gr-economy/Shared/Index.lua`
- `server/Packages/gr-economy/Server/Index.lua`
- `server/Packages/gr-economy/Server/EconomyRepository.lua`
- `server/Packages/gr-economy/Server/EconomyService.lua`
- `docs/codex-reports/issue-107-economy-foundation-report.md`

## 4. Fichiers modifiés

- aucun fichier existant n'a dû être modifié dans ce lot
- le worktree contient deja `server/Packages/gr-chat/Server/Index.lua` en fichier modifie, mais ce lot ne l'a pas touche

## 5. Fichiers explicitement non modifiés

- `server/Packages/gr-contracts/`
- `server/Packages/gr-crafting/`
- `server/Packages/gr-quests/`
- `server/Packages/gr-reputation/`
- `database/seeds/`
- vrai `Config.toml`

## 6. Migration SQL ajoutée

Migration ajoutée :

- `database/migrations/017_economy_foundation.sql`

Effets :

- vérifie la présence de `characters.money_cash` ;
- vérifie la présence de `characters.money_bank` ;
- crée `bank_transactions` si absente ;
- crée les index `character_id`, `target_character_id`, `created_at`.

Note importante :

- `money_cash` et `money_bank` existent déjà dans `001_init.sql` en `BIGINT` ;
- la migration `017` ne change pas leur type, elle garantit seulement leur présence.

## 7. Package gr-economy

Le package `gr-economy` dépend de :

- `gr-core`
- `gr-database`
- `gr-characters`

Il expose :

- `EconomyRepository`
- `EconomyService`
- `GREconomyBridge`

Le repository reste limité à l'accès PostgreSQL.
Le service garde la validation métier et la journalisation.

## 8. Bridge GREconomyBridge

Bridge exporté via `Package.Export("GREconomyBridge", GREconomyBridge)`.

Méthodes exposées :

- `GetBalance`
- `AddMoney`
- `RemoveMoney`
- `TransferMoney`
- `ListTransactions`

Objectif futur :

- remplacer le crédit direct des contrats ;
- supporter `/pay` ;
- supporter l'historique économique côté datapad.

## 9. Commandes debug économie

Commandes ajoutées dans `gr-economy/Server/Index.lua` :

- `/money`
- `/givemoney <wallet> <amount> [reason]`
- `/takemoney <wallet> <amount> [reason]`
- `/transactions`

Protection :

- `gr_economy_debug_commands_enabled`
- `gr_economy_debug_allowed_platform_ids`

Messages gérés :

- `Commande economie desactivee.`
- `Personnage actif introuvable.`
- `Wallet invalide.`
- `Montant invalide.`
- `Solde insuffisant.`

## 10. Sécurité serveur

Garanties mises en place :

- logique server-authoritative ;
- aucun solde final transmis par le client ;
- `wallet` limité à `cash` ou `bank` ;
- `amount` entier strictement positif ;
- plafond service à `1000000` ;
- retraits refusés si solde insuffisant ;
- transferts journalisés des deux côtés ;
- aucun SQL dynamique dangereux ;
- metadata JSON normalisée côté serveur.

## 11. Tests PostgreSQL effectués

Exécutés :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1 -f /workspace/database/migrations/017_economy_foundation.sql
```

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, first_name, last_name, money_cash, money_bank FROM characters ORDER BY id;"
```

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, character_id, target_character_id, amount, currency, wallet, type, reason, created_at FROM bank_transactions ORDER BY id DESC LIMIT 20;"
```

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT schemaname, tablename FROM pg_tables WHERE tablename = 'bank_transactions';"
```

Résultats observés :

- migration `017` appliquée avec succès ;
- `money_cash` et `money_bank` déjà présents, notices PostgreSQL conformes ;
- `bank_transactions` créée dans le schéma `public` ;
- table vide juste après migration, ce qui est attendu ;
- lecture des soldes personnages OK :
  - `Ari Voss` -> `cash=500 bank=2500`
  - `Test Character` -> `cash=0 bank=0`

## 12. Tests runtime effectués ou restants

Tests runtime non exécutés dans ce lot.

Reste à exécuter localement :

```txt
/money
/givemoney bank 100 test
/money
/takemoney bank 50 test
/money
/transactions
/profile
/contracts
/mycontracts
```

Préparation locale requise hors dépôt :

- activer `gr_economy_debug_commands_enabled = true`
- renseigner `gr_economy_debug_allowed_platform_ids`
- ajouter `gr-economy` à la liste de packages du serveur nanos world local

## 13. Risques restants

- le flux `TransferMoney` n'est pas transactionnel SQL de bout en bout ;
- si une insertion dans `bank_transactions` échoue après mise à jour d'un wallet, il n'y a pas encore de rollback applicatif ;
- `gr-contracts` n'est pas encore branché sur `GREconomyBridge` dans ce lot ;
- le runtime nanos world doit encore valider le chargement package et les commandes debug en jeu.

## 14. Résultat git status -sb

À la fin du lot, les changements attendus portent sur :

- `database/migrations/017_economy_foundation.sql`
- `server/Packages/gr-economy/`
- `docs/codex-reports/issue-107-economy-foundation-report.md`

Etat du worktree observe :

- `server/Packages/gr-chat/Server/Index.lua` apparait deja modifie et a ete laisse intact

## 15. Message de commit recommandé

```txt
feat(economy): add economy foundation
```
