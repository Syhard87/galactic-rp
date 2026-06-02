# Issue #95 - Reputation foundation

## 1. Résumé de limplémentation

Ajout d'une fondation MVP serveur pour la reputation :

- migration SQL `reputation_definitions` / `character_reputations`
- seed MVP de cinq reputations
- package serveur `gr-reputation`
- repository SQL dedie
- service de lecture / ajout / set de reputation
- calcul de rang textuel
- bridge `GRReputationBridge`
- commandes debug `/reputations` et `/givereputation`
- allowlist `gr-chat` pour laisser passer les commandes

Le lot reste limite a la persistance serveur, au debug local et a l'exposition d'un bridge pour les futures issues.

## 2. Agents consultés

- software-architect
- database-engineer
- backend-lua
- nanos-world-lua-agent
- security-reviewer
- qa-tester

## 3. Fichiers créés

- `database/migrations/012_reputation_foundation.sql`
- `database/seeds/reputation_mvp_seed.sql`
- `server/Packages/gr-reputation/Package.toml`
- `server/Packages/gr-reputation/Shared/Index.lua`
- `server/Packages/gr-reputation/Server/Index.lua`
- `server/Packages/gr-reputation/Server/ReputationRepository.lua`
- `server/Packages/gr-reputation/Server/ReputationService.lua`
- `docs/codex-reports/issue-95-reputation-foundation-report.md`

## 4. Fichiers modifiés

- `server/Packages/gr-chat/Server/Index.lua`

## 5. Fichiers explicitement non modifiés

- `server/Packages/gr-database/`
- `server/Packages/gr-characters/`
- `server/Packages/gr-factions/`
- `server/Packages/gr-inventory/`
- `server/Packages/gr-progression/`
- `server/Packages/gr-skills/`
- `server/Packages/gr-quests/`
- `server/Packages/gr-crafting/`
- vrai `Config.toml`

## 6. Migration SQL ajoutée

Fichier :

- `database/migrations/012_reputation_foundation.sql`

Tables ajoutees :

- `reputation_definitions`
- `character_reputations`

Points notables :

- aucune destruction de donnees
- aucun `DROP`
- cle primaire sur `reputation_definitions.key`
- unicite `(character_id, reputation_key)` sur `character_reputations`
- FK vers `characters(id)` et `reputation_definitions(key)`
- index sur `character_id`
- index sur `reputation_key`
- contraintes sur les bornes et la valeur par defaut des definitions

## 7. Seed ajouté

Fichier :

- `database/seeds/reputation_mvp_seed.sql`

Definitions seedees :

- `government`
- `military`
- `merchant_guild`
- `underworld`
- `explorers`

Regles seedees :

- `min_value = -1000`
- `max_value = 1000`
- `default_value = 0`
- `is_active = TRUE`

Le seed est relancable via `ON CONFLICT (key) DO UPDATE`.

## 8. Détails techniques Lua

### Package

Nouveau package :

- `server/Packages/gr-reputation/`

Structure :

- `Package.toml`
- `Shared/Index.lua`
- `Server/Index.lua`
- `Server/ReputationRepository.lua`
- `Server/ReputationService.lua`

Dependances declarees :

- `gr-core`
- `gr-database`
- `gr-characters`

### Repository

Methodes ajoutees :

- `ListDefinitions(callback)`
- `GetDefinition(reputation_key, callback)`
- `ListCharacterReputations(character_id, callback)`
- `GetCharacterReputation(character_id, reputation_key, callback)`
- `UpsertCharacterReputation(character_id, reputation_key, value, rank, callback)`

Le repository reste strictement limite a l'acces DB.

### Service

Methodes ajoutees :

- `ListCharacterReputations(character_id, callback)`
- `AddReputation(character_id, reputation_key, amount, reason, callback)`
- `SetReputation(character_id, reputation_key, value, reason, callback)`
- `ComputeRank(value)`

Rangs MVP :

- `hostile <= -500`
- `unfriendly <= -100`
- `neutral` entre `-99` et `249`
- `friendly >= 250`
- `trusted >= 750`

Comportement :

- refuse une reputation inconnue ou inactive
- lit la valeur existante ou prend `default_value`
- applique le delta ou la valeur cible
- borne entre `min_value` et `max_value`
- recalcule le rang
- sauvegarde via upsert

Validation cle reputation :

- normalisation en minuscule
- motif autorise `^[a-z0-9_]+$`

## 9. Package gr-reputation

Le package reste isole :

- aucune dependance a `gr-quests`
- aucune dependance a `gr-crafting`
- aucune mutation gameplay cote client

Il ne fait que :

- lire les definitions
- lire l'etat d'un personnage
- modifier la reputation cote serveur
- exposer un bridge pour les futurs systemes

## 10. Bridge GRReputationBridge

Bridge exporte :

- `GRReputationBridge.GetService()`
- `GRReputationBridge.AddReputation(character_id, reputation_key, amount, reason, callback)`
- `GRReputationBridge.SetReputation(character_id, reputation_key, value, reason, callback)`
- `GRReputationBridge.ListCharacterReputations(character_id, callback)`

Ce bridge est prevu pour les futures integrations :

- recompenses de quete
- conditions de quete
- Datapad reputation
- logique faction

## 11. Commande /reputations

Commande debug/dev :

```txt
/reputations
```

Comportement :

- verifie la garde debug locale
- recupere le personnage actif
- liste toutes les reputations actives avec valeur et rang
- si aucune ligne personnage n'existe encore, affiche les valeurs par defaut

Sortie type :

```txt
Reputations :
- government : 25 neutral
- military : 0 neutral
```

## 12. Commande /givereputation

Commande debug/dev :

```txt
/givereputation <reputation_key> <amount> [reason]
```

Exemple :

```txt
/givereputation government 25 test
```

Regles :

- refuse sans personnage actif
- refuse si `reputation_key` invalide
- refuse si `amount = 0`
- refuse si `abs(amount) > 1000`
- la logique sensible reste cote serveur

Messages principaux :

- `Reputation modifiee : government +25 => 25 neutral`
- `Reputation inconnue : government_fake`
- `Montant invalide.`
- `Personnage actif introuvable.`
- `Commande reputation desactivee.`

## 13. Impact gr-chat

Allowlist externe ajoutee dans `server/Packages/gr-chat/Server/Index.lua` :

- `reputations = true`
- `givereputation = true`

Aucune autre commande n'a ete modifiee.

## 14. Tests effectués

Tests locaux reels effectues :

1. verification branche et prerequis :
   - `git status -sb`
   - `git branch --show-current`
   - `Test-Path "server\Packages\gr-crafting"`
   - `Test-Path "docs\codex-reports\issue-94-crafting-diagnostics-report.md"`
2. lecture docs projet, agents et docs nanos world minimales
3. lecture des patterns `gr-chat`, `gr-skills`, `gr-progression`, `gr-inventory`
4. application migration PostgreSQL :
   - `database/migrations/012_reputation_foundation.sql`
5. application seed PostgreSQL :
   - `database/seeds/reputation_mvp_seed.sql`
6. verification PostgreSQL :
   - `reputation_definitions`
   - `character_reputations`
7. verification git :
   - `git status -sb`
   - `git status --short --untracked-files=all`
   - `git diff --name-only`
   - `git diff --check`

Note :

- les premieres commandes Docker ont echoue en sandbox locale
- elles ont ensuite ete rejouees avec autorisation hors sandbox pour finir la validation

## 15. Tests à faire manuellement en runtime nanos world

Ne pas modifier le vrai `Config.toml` dans le depot.

Ajouter localement dans `[custom_settings]` :

```toml
gr_reputation_debug_commands_enabled = true
gr_reputation_debug_allowed_platform_ids = "ID_LOCAL_NON_VERSIONNE"
```

Et ajouter localement le package si necessaire dans l'ordre :

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
]
```

Copie packages :

```powershell
$Repo = "C:\Users\Syhar\OneDrive - educ-valadon-limoges.fr\Bureau\galactic-rp\galactic-rp"
$ServerRoot = "C:\Program Files (x86)\Steam\steamapps\common\nanos-world-playtest\Server"

robocopy "$Repo\server\Packages" "$ServerRoot\Packages" /E /FFT /R:2 /W:2 /NP /XF ".gitkeep"
```

Lancement :

```powershell
cd "C:\Program Files (x86)\Steam\steamapps\common\nanos-world-playtest\Server"
.\NanosWorldServer.exe --playtest
```

Tests en jeu :

```txt
/reputations
/givereputation government 25 test
/reputations
/givereputation underworld -50 test
/reputations
/profile
/quests
/inv
/skills
/xpinfo
/craftrecipes
/craftinfo ration_pack
```

## 16. Requêtes PostgreSQL de vérification

Migration :

```powershell
Get-Content -Raw ".\database\migrations\012_reputation_foundation.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
```

Seed :

```powershell
Get-Content -Raw ".\database\seeds\reputation_mvp_seed.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
```

Definitions :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, name, min_value, max_value, default_value, is_active FROM reputation_definitions ORDER BY key;"
```

Valeurs personnage :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, reputation_key, value, rank, updated_at FROM character_reputations ORDER BY character_id, reputation_key;"
```

## 17. Résultat git status -sb

```text
## feature/issue-95-reputation-foundation
 M server/Packages/gr-chat/Server/Index.lua
?? database/migrations/012_reputation_foundation.sql
?? database/seeds/reputation_mvp_seed.sql
?? server/Packages/gr-reputation/
```

## 18. Risques restants

- le runtime nanos world n'a pas ete lance ici, donc la validation finale des commandes `/reputations` et `/givereputation` reste manuelle
- `character_reputations` est vide juste apres migration + seed, ce qui est normal avant le premier usage runtime
- le service borne la valeur finale entre `min_value` et `max_value`, mais le delta brut de `/givereputation` reste un outil debug et ne doit pas etre expose hors dev
- `git diff --check` ne remonte ici que des warnings CRLF Windows

## 19. Message de commit recommandé

```text
feat(reputation): add reputation foundation
```
