# Issue #98  Contracts foundation

## 1. Resume de limplementation

Ajout d'une premiere fondation serveur pour les contrats joueurs :

- migration PostgreSQL `contracts`
- nouveau package `gr-contracts`
- repository + service Lua separes
- bridge serveur `GRContractsBridge`
- commandes debug `/contracts`, `/mycontracts`, `/createcontract`, `/acceptcontract`, `/completecontract`, `/cancelcontract`
- allowlist `gr-chat` mise a jour

Le lot reste volontairement MVP :

- stockage de `reward_money`
- aucun paiement automatique
- aucun datapad
- aucune UI

## 2. Agents consultes

- software-architect
- database-engineer
- backend-lua
- nanos-world-lua-agent
- security-reviewer
- qa-tester

## 3. Fichiers crees

- `database/migrations/015_contracts_foundation.sql`
- `server/Packages/gr-contracts/Package.toml`
- `server/Packages/gr-contracts/Shared/Index.lua`
- `server/Packages/gr-contracts/Server/Index.lua`
- `server/Packages/gr-contracts/Server/ContractRepository.lua`
- `server/Packages/gr-contracts/Server/ContractService.lua`
- `docs/codex-reports/issue-98-contracts-foundation-report.md`

## 4. Fichiers modifies

- `server/Packages/gr-chat/Server/Index.lua`

## 5. Fichiers explicitement non modifies

- `server/Packages/gr-database/`
- `server/Packages/gr-characters/`
- `server/Packages/gr-factions/`
- `server/Packages/gr-inventory/`
- `server/Packages/gr-progression/`
- `server/Packages/gr-skills/`
- `server/Packages/gr-quests/`
- `server/Packages/gr-crafting/`
- `server/Packages/gr-reputation/`
- vrai `Config.toml`

## 6. Migration SQL ajoutee

Fichier :

- `database/migrations/015_contracts_foundation.sql`

Table ajoutee :

- `contracts`

Champs principaux :

- `creator_character_id`
- `assignee_character_id`
- `type`
- `title`
- `description`
- `reward_money`
- `status`
- `created_at`
- `accepted_at`
- `completed_at`
- `cancelled_at`
- `deadline_at`

Contraintes :

- `reward_money >= 0`
- `status IN ('open', 'accepted', 'completed', 'cancelled')`
- index sur `status`
- index sur `creator_character_id`
- index sur `assignee_character_id`

La migration est non destructive et idempotente sur la creation de table / index.

## 7. Seed ajoute ou non necessaire

Aucun seed ajoute.

La base de contrats MVP peut etre testee directement via les commandes debug de creation en runtime.

## 8. Details techniques Lua

### Repository

`ContractRepository.lua` gere uniquement l'acces DB :

- creation de contrat
- liste des contrats ouverts
- liste des contrats d'un personnage
- lecture d'un contrat par id
- transitions `accept`, `complete`, `cancel`

### Service

`ContractService.lua` applique les regles metier :

- types autorises :
  - `delivery`
  - `protection`
  - `repair`
  - `crafting`
  - `information`
  - `medical`
- `reward_money` borne entre `0` et `100000`
- `description` obligatoire, max `500`
- acceptation uniquement depuis `open`
- completion uniquement par l'assigne
- annulation uniquement par le createur tant que le contrat est `open`

## 9. Package gr-contracts

Structure creee :

- `Package.toml`
- `Shared/Index.lua`
- `Server/Index.lua`
- `Server/ContractRepository.lua`
- `Server/ContractService.lua`

Dependances :

- `gr-core`
- `gr-database`
- `gr-characters`

Pas de dependance forte a `gr-quests`, `gr-crafting` ou `gr-reputation`.

## 10. Bridge GRContractsBridge

Bridge exporte :

```lua
GRContractsBridge.CreateContract
GRContractsBridge.ListOpenContracts
GRContractsBridge.ListMyContracts
GRContractsBridge.AcceptContract
GRContractsBridge.CompleteContract
GRContractsBridge.CancelContract
```

Ce bridge prepare les lots futurs :

- datapad contrats
- recompenses / paiements
- reputation liee aux contrats
- generation de contrats par d'autres systemes

## 11. Commandes contrats

Commandes debug ajoutees :

- `/contracts`
- `/mycontracts`
- `/createcontract <type> <reward_money> <description>`
- `/acceptcontract <contract_id>`
- `/completecontract <contract_id>`
- `/cancelcontract <contract_id>`

Guard local via `custom_settings` :

- `gr_contracts_debug_commands_enabled`
- `gr_contracts_debug_allowed_platform_ids`

Le vrai `Config.toml` n'a pas ete modifie.

## 12. Impact gr-chat

Allowlist externe enrichie avec :

- `contracts`
- `mycontracts`
- `createcontract`
- `acceptcontract`
- `completecontract`
- `cancelcontract`

Objectif :

- eviter `chat-command-not-supported`
- laisser `gr-contracts` intercepter proprement ses commandes runtime

## 13. Tests effectues

Tests locaux realises :

1. lecture du cahier des charges, docs projet, docs nanos world et report #97
2. lecture des patterns existants `gr-reputation`, `gr-crafting`, `gr-chat`
3. creation de la migration `015_contracts_foundation.sql`
4. creation du package `gr-contracts`
5. mise a jour de l'allowlist `gr-chat`
6. application migration PostgreSQL locale
7. verification PostgreSQL de la table `contracts`
8. controles git :
   - `git status -sb`
   - `git status --short --untracked-files=all`
   - `git diff --name-only`
   - `git diff --check`

## 14. Tests a faire manuellement en runtime nanos world

Ne pas modifier le vrai `Config.toml` versionne.

Ajouter localement dans `[custom_settings]` :

```toml
gr_contracts_debug_commands_enabled = true
gr_contracts_debug_allowed_platform_ids = "ID_LOCAL_NON_VERSIONNE"
```

Ajouter localement le package si necessaire :

```toml
packages = [
    "gr-core",
    "gr-database",
    "gr-characters",
    "gr-factions",
    "gr-inventory",
    "gr-progression",
    "gr-skills",
    "gr-quests",
    "gr-chat",
    "gr-crafting",
    "gr-reputation",
    "gr-contracts",
]
```

Tests en jeu :

```txt
/contracts
/createcontract delivery 100 Livrer une caisse au spatioport
/contracts
/acceptcontract 1
/mycontracts
/completecontract 1
/mycontracts
```

Erreurs a tester :

```txt
/createcontract fake 100 test
/createcontract delivery -10 test
/acceptcontract 999
/cancelcontract 1
```

## 15. Requetes PostgreSQL de verification

Migration :

```powershell
Get-Content -Raw ".\database\migrations\015_contracts_foundation.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
```

Table :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, creator_character_id, assignee_character_id, type, reward_money, status, created_at, accepted_at, completed_at, cancelled_at FROM contracts ORDER BY id;"
```

## 16. Resultat git status -sb

Le resultat final a ete releve apres implementation et verifications locales.

## 17. Risques restants

- runtime nanos world non lance ici, donc validation finale des commandes en jeu encore necessaire
- `reward_money` est seulement persiste dans ce lot ; aucun paiement automatique n'est effectue
- le MVP n'ajoute ni deadline active, ni UI, ni workflow d'entreprise
- `git diff --check` peut remonter seulement des warnings CRLF Windows selon le poste

## 18. Message de commit recommande

```text
feat(contracts): add contracts foundation
```
