# Issue #97 - Quest reputation requirements

## 1. Resume de l'implementation

Ajout d'un prerequis de reputation minimale pour demarrer certaines quetes :

- migration SQL pour etendre `quests`
- seed de quetes mis a jour avec les colonnes de prerequis
- verification serveur du prerequis dans `StartQuestForActiveCharacter(...)`
- refus explicite si la reputation est insuffisante
- refus explicite si la verification reputation est impossible
- rapport technique du lot ajoute

Le controle reste serveur-only et passe par `GRReputationBridge`.

## 2. Agents consultes

- software-architect
- database-engineer
- backend-lua
- nanos-world-lua-agent
- security-reviewer
- qa-tester

## 3. Fichiers crees

- `database/migrations/014_quest_reputation_requirements.sql`
- `docs/codex-reports/issue-97-quest-reputation-requirements-report.md`

## 4. Fichiers modifies

- `database/seeds/quests_mvp_seed.sql`
- `server/Packages/gr-quests/Server/QuestRepository.lua`
- `server/Packages/gr-quests/Server/QuestService.lua`
- `server/Packages/gr-quests/Server/Index.lua`

## 5. Fichiers explicitement non modifies

- `server/Packages/gr-database/`
- `server/Packages/gr-characters/`
- `server/Packages/gr-factions/`
- `server/Packages/gr-inventory/`
- `server/Packages/gr-progression/`
- `server/Packages/gr-skills/`
- `server/Packages/gr-crafting/`
- `server/Packages/gr-reputation/`
- vrai `Config.toml`

## 6. Migration SQL ajoutee

Fichier :

- `database/migrations/014_quest_reputation_requirements.sql`

Ajouts sur `quests` :

- `required_reputation_key VARCHAR(64)`
- `required_reputation_min_value INTEGER NOT NULL DEFAULT 0`

Contrainte ajoutee :

- `chk_quests_required_reputation_min_value_range`
- borne `required_reputation_min_value BETWEEN -1000 AND 1000`

La migration est idempotente et non destructive.

## 7. Seed modifie

Fichier :

- `database/seeds/quests_mvp_seed.sql`

Colonnes ajoutees :

- `required_reputation_key`
- `required_reputation_min_value`

Quetes de base laissees accessibles :

- `first_steps -> NULL, 0`
- `medic_training -> NULL, 0`
- `explorer_report -> NULL, 0`

Quetes de test ajoutees pour valider le verrou reputation :

- `government_contract -> government, 50`
- `underworld_delivery -> underworld, 25`
- `explorer_sensitive_task -> explorers, 30`

Ces quetes restent minimales et servent a tester le gate serveur de #97.

## 8. Details techniques Lua

### Repository

Les lectures de quetes recuperent maintenant :

- `required_reputation_key`
- `required_reputation_min_value`

Zones impactees :

- `ListAvailableQuests`
- `GetQuestByKey`
- `ListCharacterQuests`
- `StartQuest`

### Service

Le check de reputation a ete ajoute dans `StartQuestForActiveCharacter(...)` :

1. resolution du personnage actif
2. chargement de la quete
3. lecture du prerequis de reputation
4. si aucun prerequis, comportement actuel conserve
5. sinon appel a `GRReputationBridge.ListCharacterReputations(...)`
6. comparaison `actual >= required`
7. demarrage si ok, refus sinon

Le repository n'a pas ete charge de logique reputation.

## 9. Integration avec GRReputationBridge

Bridge utilise :

```lua
GRReputationBridge.ListCharacterReputations(character_id, callback)
```

Choix technique :

- pas de modification de `gr-reputation`
- reutilisation du merge deja fait dans `ListCharacterReputations`, qui expose une valeur par defaut coherente meme sans ligne personnage persistante

Comportements :

- si le bridge manque : refus
- si la lecture echoue : refus
- si la reputation manque dans les lignes retournees : valeur actuelle consideree a `0`

## 10. Verification serveur au startquest

Logs ajoutes :

- `[gr_quests][service] Quest has no reputation requirement quest_key=%s.`
- `[gr_quests][service] Quest reputation requirement passed character_id=%s quest_key=%s reputation_key=%s required=%s actual=%s.`
- `[gr_quests][service] Quest reputation requirement failed character_id=%s quest_key=%s reputation_key=%s required=%s actual=%s.`
- `[gr_quests][service] Quest reputation requirement failed reason=reputation-bridge-unavailable quest_key=%s.`

En cas d'echec de lecture reputation :

- log serveur avec `reason=%s`
- retour joueur bloque

## 11. Messages joueur

Si reputation insuffisante :

```txt
Quete indisponible : reputation government insuffisante. Requis=50 actuel=25.
```

Si verification impossible :

```txt
Quete indisponible : verification de reputation impossible.
```

Si la quete n'a pas de condition ou si la condition est validee :

- messages existants conserves

## 12. Tests effectues

Tests locaux realises :

1. verification branche et prerequis
2. lecture docs projet, docs nanos world et reports #95/#96
3. lecture de `QuestRepository.lua`, `QuestService.lua`, `Quest Index.lua`, `quests_mvp_seed.sql`
4. application migration PostgreSQL :
   - `database/migrations/014_quest_reputation_requirements.sql`
5. reapplication seed quetes :
   - `database/seeds/quests_mvp_seed.sql`
6. verification PostgreSQL :
   - `quests`
   - `reputation_definitions`
   - `character_reputations`
7. verification git :
   - `git status -sb`
   - `git status --short --untracked-files=all`
   - `git diff --name-only`
   - `git diff --check`

## 13. Tests a faire manuellement en runtime nanos world

Ne pas modifier le vrai `Config.toml`.

Activer localement :

```toml
gr_quests_debug_commands_enabled = true
gr_reputation_debug_commands_enabled = true
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

Tests :

```txt
/reputations
/quests
/startquest first_steps
/startquest medic_training
/givereputation government 100 test
/reputations
/startquest government_contract
/questprogress
```

## 14. Requetes PostgreSQL de verification

Migration :

```powershell
Get-Content -Raw ".\database\migrations\014_quest_reputation_requirements.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
```

Seed :

```powershell
Get-Content -Raw ".\database\seeds\quests_mvp_seed.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
```

Quetes :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, title, required_reputation_key, required_reputation_min_value, reward_reputation_key, reward_reputation_amount FROM quests ORDER BY key;"
```

Definitions reputation :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, name, min_value, max_value, default_value, is_active FROM reputation_definitions ORDER BY key;"
```

Valeurs personnage :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, reputation_key, value, rank, updated_at FROM character_reputations ORDER BY character_id, reputation_key;"
```

## 15. Resultat git status -sb

Le resultat final a ete releve apres modifications et tests git.

## 16. Risques restants

- le runtime nanos world n'a pas ete lance ici, donc la validation finale en jeu reste manuelle
- les trois quetes verrouillees ajoutees dans le seed sont minimales et sans objectifs, uniquement pour rendre le gate reputation testable
- `server/Packages/gr-quests/Server/Index.lua` etait deja modifie dans le worktree a l'ouverture du lot ; le patch a ete garde limite au mapping des nouveaux refus
- `git diff --check` peut ne remonter que des warnings CRLF Windows selon le poste

## 17. Message de commit recommande

```text
feat(quests): add reputation requirements
```
