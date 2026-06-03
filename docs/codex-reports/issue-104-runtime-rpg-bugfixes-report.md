# Issue #104  Runtime RPG bugfixes

## 1. Resume des corrections

Correction ciblee de quatre bloqueurs issus du smoke test runtime #103 :

- fallback local pour le calcul XP skill dans `gr-progression` afin d'eviter `SkillXpRules` nil ;
- correction de portee Lua pour `normalize_integer` dans `gr-quests` ;
- correction du binding SQL de `/mycontracts` dans `gr-contracts` ;
- correction de normalisation booleenne dans `gr-crafting` pour `is_active`.

Aucune nouvelle feature gameplay n'a ete ajoutee.

## 2. Agents consultes

- `backend-lua`
- `database-engineer`
- `qa-tester`
- `security-reviewer`
- `nanos-world-lua-agent`
- `software-architect`

## 3. Bugs corriges

1. `SkillXpRules` nil dans `server/Packages/gr-progression/Server/Index.lua`
2. `normalize_integer` nil dans `server/Packages/gr-quests/Server/QuestRepository.lua`
3. placeholder SQL re-utilise dans `server/Packages/gr-contracts/Server/ContractRepository.lua`
4. normalisation incorrecte de `is_active` dans `server/Packages/gr-crafting/Server/CraftingRepository.lua`

## 4. Fichiers modifies

- `server/Packages/gr-progression/Server/Index.lua`
- `server/Packages/gr-quests/Server/QuestRepository.lua`
- `server/Packages/gr-contracts/Server/ContractRepository.lua`
- `server/Packages/gr-crafting/Server/CraftingRepository.lua`

## 5. Fichiers explicitement non modifies

- `server/Packages/gr-chat/Server/Index.lua`
- `database/seeds/crafting_mvp_seed.sql`
- `server/Packages/gr-skills/Server/Index.lua`
- `server/Packages/gr-skills/Server/SkillRepository.lua`
- `server/Packages/gr-quests/Server/QuestService.lua`
- `server/Packages/gr-contracts/Server/ContractService.lua`
- `Config.toml`

## 6. Correction SkillXpRules

Le bug venait de `gr-progression` qui appelait directement `SkillXpRules.GetRequiredXpForLevel(...)` sans garantir que la table soit disponible dans son contexte runtime.

Correction appliquee :

- ajout d'un helper local `get_required_skill_xp_for_level(level)` ;
- utilisation prioritaire de `GRSkills.Server.SkillXpRules.GetRequiredXpForLevel(...)` si disponible ;
- fallback minimal et coherent avec la regle existante : `level * 75`.

Effet attendu :

- plus de nil access dans `/profile` ;
- compatibilite conservee avec `/skills` et `/xpinfo`.

## 7. Correction normalize_integer

Le bug venait d'une portee Lua incorrecte :

- `normalize_quest_row(...)` et `normalize_character_quest_row(...)` utilisaient `normalize_integer(...)` ;
- la fonction etait declaree plus bas avec `local function`, donc les closures pointaient vers une globale absente.

Correction appliquee :

- ajout d'une forward declaration locale `local normalize_integer` ;
- conversion de la declaration en affectation `normalize_integer = function(...)`.

Effet attendu :

- plus d'erreur runtime dans les lectures de quetes ;
- colonnes `reward_reputation_amount` et `required_reputation_min_value` normalisees correctement.

## 8. Correction SQL binding contracts

Le bug venait de la requete de listing des contrats d'un personnage :

```sql
WHERE creator_character_id = :0 OR assignee_character_id = :0
```

Le runtime PostgreSQL/nanos world n'accepte pas ici la re-utilisation du meme placeholder.

Correction appliquee :

```sql
WHERE creator_character_id = :0 OR assignee_character_id = :1
```

et passage de `character_id` deux fois dans `SelectAsync(...)`.

Effet attendu :

- `/mycontracts` ne doit plus echouer sur un bind incomplet.

## 9. Correction ou analyse ration_pack

Analyse faite :

- `database/seeds/crafting_mvp_seed.sql` definit deja `ration_pack` avec `is_active = TRUE` ;
- verification PostgreSQL confirmee : `ration_pack | ration_pack | <station null> | t`.

Cause retenue :

- la lecture Lua de `row.is_active` etait trop stricte avec `row.is_active == true` ;
- si le driver retourne `t`, `1` ou texte equivalent, la recette est normalisee a `false`.

Correction appliquee :

- ajout d'un helper local `normalize_boolean(...)` dans `CraftingRepository.lua` ;
- utilisation pour les recettes et les stations.

Conclusion :

- pas de correction de seed necessaire ;
- correction appliquee cote Lua repository.

## 10. Correction chat-command-not-supported

Verification faite dans `server/Packages/gr-chat/Server/Index.lua` :

- `craftrecipes`
- `craftinfo`
- `craftstations`
- `reputations`
- `givereputation`
- `contracts`
- `mycontracts`
- `createcontract`
- `acceptcontract`
- `completecontract`
- `cancelcontract`

sont deja presentes dans l'allowlist des commandes externes.

Decision :

- aucune modification `gr-chat` dans ce lot ;
- le rejet runtime observe en #103 ne correspond pas, d'apres l'etat du code, a un manque sur cette liste minimale ;
- il faudra capturer la commande exacte lors du prochain retest runtime si le probleme persiste.

## 11. Tests PostgreSQL effectues

Commandes executees :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, result_item_key, station_key, is_active FROM crafting_recipes ORDER BY key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, creator_character_id, assignee_character_id, type, reward_money, status, payment_status, paid_at FROM contracts ORDER BY id;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, title, reward_skill_key, reward_skill_xp, reward_reputation_key, reward_reputation_amount, required_reputation_key, required_reputation_min_value FROM quests ORDER BY key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, skill_key, level, current_xp, total_xp FROM character_skills ORDER BY character_id, skill_key;"
```

Constats :

- `ration_pack` est active en base ;
- table `contracts` coherente pour le contrat `#1` en statut `open` ;
- colonnes de recompenses/prerequis quetes presentes ;
- lignes de skills presentes, dont `character_id=3 / medicine`.

## 12. Tests runtime effectues ou restants

Effectues dans ce lot :

- verification statique des fichiers cibles ;
- verification PostgreSQL des donnees impactees.

Restants :

- recopier `server/Packages` vers le serveur nanos world local ;
- relancer le serveur playtest ;
- retester :
  - `/profile`
  - `/skills`
  - `/xpinfo`
  - `/quests`
  - `/startquest first_steps`
  - `/questprogress`
  - `/completequest first_steps`
  - `/craftrecipes`
  - `/craftinfo ration_pack`
  - `/craft ration_pack`
  - `/contracts`
  - `/createcontract delivery 100 Livrer une caisse au spatioport`
  - `/acceptcontract 1`
  - `/mycontracts`
  - `/completecontract 1`

## 13. Risques restants

- le retest runtime nanos world n'a pas ete execute dans ce lot ;
- le point `chat-command-not-supported` reste seulement analyse, sans reproduction commande par commande ;
- le fallback local XP skill dans `gr-progression` repose sur la meme formule que `gr-skills` (`level * 75`) mais n'introduit pas de dependance forte supplementaire ;
- d'autres normalisations booleennes strictes peuvent encore exister dans d'autres packages non touches ici.

## 14. Resultat git status -sb

```txt
## feature/issue-104-runtime-rpg-bugfixes
 M server/Packages/gr-contracts/Server/ContractRepository.lua
 M server/Packages/gr-crafting/Server/CraftingRepository.lua
 M server/Packages/gr-progression/Server/Index.lua
 M server/Packages/gr-quests/Server/QuestRepository.lua
?? docs/codex-reports/issue-104-runtime-rpg-bugfixes-report.md
```

## 15. Message de commit recommande

```txt
fix(runtime): resolve rpg smoke test blockers
```
