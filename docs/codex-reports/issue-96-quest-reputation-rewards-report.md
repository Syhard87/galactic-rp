# Issue #96 - Quest reputation rewards

## 1. Resume de l'implementation

Ajout des recompenses de reputation aux quetes MVP :

- migration SQL pour etendre `quests`
- seed MVP des quetes mis a jour
- dependance `gr-reputation` ajoutee a `gr-quests`
- repository de quetes etendu pour charger les champs de reputation
- service de quetes etendu pour appeler `GRReputationBridge.AddReputation(...)`
- message joueur ajoute lors d'une recompense de reputation reussie

Le flux reste best-effort : une erreur reputation ne rollback pas la completion de quete.

## 2. Agents consultes

- software-architect
- database-engineer
- backend-lua
- nanos-world-lua-agent
- security-reviewer
- qa-tester

## 3. Fichiers crees

- `database/migrations/013_quest_reputation_rewards.sql`
- `docs/codex-reports/issue-96-quest-reputation-rewards-report.md`

## 4. Fichiers modifies

- `database/seeds/quests_mvp_seed.sql`
- `server/Packages/gr-quests/Package.toml`
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

- `database/migrations/013_quest_reputation_rewards.sql`

Ajouts sur `quests` :

- `reward_reputation_key VARCHAR(64)`
- `reward_reputation_amount INTEGER NOT NULL DEFAULT 0`

Contrainte ajoutee :

- `chk_quests_reward_reputation_amount_range`
- borne `reward_reputation_amount BETWEEN -1000 AND 1000`

La migration reste idempotente et non destructive.

## 7. Seed modifie

Fichier :

- `database/seeds/quests_mvp_seed.sql`

Colonnes ajoutees :

- `reward_reputation_key`
- `reward_reputation_amount`

Valeurs MVP :

- `first_steps -> NULL, 0`
- `medic_training -> government, 10`
- `explorer_report -> explorers, 15`

Le seed reste relancable via `ON CONFLICT (key) DO UPDATE`.

## 8. Details techniques Lua

### Package.toml

Ajout de `gr-reputation` dans `packages_requirements` de `gr-quests`.

### Repository

Les lectures de quetes recuperent maintenant :

- `reward_reputation_key`
- `reward_reputation_amount`

Methodes impactees :

- `ListAvailableQuests`
- `GetQuestByKey`
- `ListCharacterQuests`
- `StartQuest`
- `CompleteQuest`

### Service

Le flux `CompleteQuestForActiveCharacter(...)` conserve l'ordre :

1. completion de quete
2. XP generale
3. objet
4. XP competence
5. reputation

Le gain reputation utilise :

```lua
GRReputationBridge.AddReputation(character_id, reputation_key, amount, "quest:" .. quest_key, callback)
```

Le service ne reimplemente pas la logique reputation.

## 9. Integration avec GRReputationBridge

Comportement :

- si aucune recompense reputation : log et fin normale
- si `GRReputationBridge` est indisponible : log et fin normale
- si le gain echoue : log et fin normale
- si le gain reussit : le `result` de quete expose
  - `reward_reputation_key`
  - `reward_reputation_amount`

Logs ajoutes :

- `[gr_quests][service] Quest has no reputation reward quest_key=%s.`
- `[gr_quests][service] Quest reputation reward skipped reason=reputation-bridge-unavailable quest_key=%s.`
- `[gr_quests][service] Quest reputation reward failed character_id=%s quest_key=%s reputation_key=%s reason=%s.`
- `[gr_quests][service] Quest reputation reward granted character_id=%s quest_key=%s reputation_key=%s amount=%s.`

## 10. Messages joueur

Pour une quete avec reputation :

```txt
Quete terminee : medic_training
XP gagnee : 75
Objet gagne : medkit_basic x1
XP competence gagnee : medicine x50
Reputation gagnee : government +10
```

Pour une quete sans recompense reputation :

- aucune ligne reputation n'est affichee

## 11. Tests effectues

Tests locaux realises :

1. verification prerequis branche et fichiers
2. lecture docs projet, docs nanos world et report #95
3. lecture de `QuestRepository.lua`, `QuestService.lua`, `Quest Index.lua`, `quests_mvp_seed.sql`
4. application migration PostgreSQL :
   - `database/migrations/013_quest_reputation_rewards.sql`
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

## 12. Tests a faire manuellement en runtime nanos world

Ne pas modifier le vrai `Config.toml` du depot.

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
/startquest medic_training
/giveitem medkit_basic 1
/useitem medkit_basic
/completequest medic_training
/reputations
/skills
/xpinfo
/inv
/profile
```

Puis :

```txt
/reputations
/startquest explorer_report
/explorereport J'ai trouve une zone interessante au nord du camp.
/completequest explorer_report
/reputations
/skills
/inv
/xpinfo
```

## 13. Requetes PostgreSQL de verification

Migration :

```powershell
Get-Content -Raw ".\database\migrations\013_quest_reputation_rewards.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
```

Seed :

```powershell
Get-Content -Raw ".\database\seeds\quests_mvp_seed.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
```

Quetes :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, title, reward_xp, reward_item_key, reward_item_quantity, reward_skill_key, reward_skill_xp, reward_reputation_key, reward_reputation_amount FROM quests ORDER BY key;"
```

Definitions reputation :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, name, min_value, max_value, default_value, is_active FROM reputation_definitions ORDER BY key;"
```

Valeurs personnage :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, reputation_key, value, rank, updated_at FROM character_reputations ORDER BY character_id, reputation_key;"
```

## 14. Resultat git status -sb

Le resultat final a ete releve apres modifications et tests git.

## 15. Risques restants

- le runtime nanos world n'a pas ete lance ici, donc la validation finale en jeu reste manuelle
- `character_reputations` restera vide tant qu'aucune quete runtime n'a effectivement attribue de reputation
- le flux reste volontairement best-effort : une panne du bridge reputation ne bloque pas la quete
- `git diff --check` peut ne remonter que des warnings CRLF Windows selon le poste

## 16. Message de commit recommande

```text
feat(quests): add reputation rewards
```
