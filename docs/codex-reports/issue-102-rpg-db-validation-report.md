# Issue #102  RPG DB validation

## 1. Resume de limplementation

Validation locale de la couche PostgreSQL pour les systemes RPG recents :

- verification Docker
- verification `SELECT 1`
- reapplication des migrations `009` a `016`
- reapplication des seeds RPG MVP
- execution des requetes de verification
- documentation des resultats

Cette validation a aussi mis en evidence un point important sur Windows/PowerShell :

- l'application d'un seed UTF-8 via `Get-Content -Raw ... | docker exec ... psql` peut casser les accents
- la procedure documentee a ete corrigee pour utiliser `psql -f /workspace/...` pour les seeds

## 2. Agents consultes

- database-engineer
- qa-tester
- security-reviewer
- software-architect

## 3. Fichiers crees

- `docs/runtime-rpg-db-validation.md`
- `docs/codex-reports/issue-102-rpg-db-validation-report.md`

## 4. Fichiers modifies

- `docs/runtime-rpg-validation.md`

## 5. Migrations testees

Migrations reappliquees :

- `009_quest_skill_rewards.sql`
- `010_crafting_foundation.sql`
- `011_crafting_stations.sql`
- `012_reputation_foundation.sql`
- `013_quest_reputation_rewards.sql`
- `014_quest_reputation_requirements.sql`
- `015_contracts_foundation.sql`
- `016_contracts_payment.sql`

## 6. Seeds testes

Seeds reappliques :

- `factions_mvp_seed.sql`
- `inventory_mvp_seed.sql`
- `reputation_mvp_seed.sql`
- `quests_mvp_seed.sql`
- `quest_objectives_mvp_seed.sql`
- `crafting_stations_mvp_seed.sql`
- `crafting_mvp_seed.sql`

## 7. Requetes PostgreSQL executees

Requetes executees :

- `SELECT 1;`
- `SELECT id, first_name, last_name, money_cash, money_bank FROM characters ORDER BY id;`
- `SELECT id, name, description, type, is_whitelisted FROM factions ORDER BY id;`
- `SELECT character_id, item_key, quantity, metadata_json FROM inventory_items ORDER BY character_id, item_key;`
- `SELECT character_id, skill_key, level, current_xp, total_xp FROM character_skills ORDER BY character_id, skill_key;`
- `SELECT key, title, reward_xp, reward_item_key, reward_skill_key, reward_reputation_key, required_reputation_key FROM quests ORDER BY key;`
- `SELECT key, name, min_value, max_value, default_value, is_active FROM reputation_definitions ORDER BY key;`
- `SELECT character_id, reputation_key, value, rank FROM character_reputations ORDER BY character_id, reputation_key;`
- `SELECT id, creator_character_id, assignee_character_id, type, reward_money, status, payment_status, paid_at FROM contracts ORDER BY id;`
- `SELECT key, result_item_key, station_key, is_active FROM crafting_recipes ORDER BY key;`
- `SELECT key, name, station_type, position_x, position_y, position_z, radius, is_active FROM crafting_stations ORDER BY key;`
- `SELECT name, encode(convert_to(name, 'UTF8'), 'hex') AS utf8_hex FROM factions WHERE type = 'government';`

## 8. Corrections effectuees

Correction effectuee :

- mise a jour de `docs/runtime-rpg-validation.md` pour recommander `docker exec ... psql -f /workspace/database/seeds/...` pour les seeds

Justification :

- l'execution des seeds via pipe PowerShell a degrade les accents du seed factions dans PostgreSQL

Aucune migration ni aucun seed metier n'ont ete modifies dans ce lot.

## 9. Tests effectues

Tests realises :

1. verification de la branche et des prerequis du ticket `#102`
2. lecture du guide #100, du rapport #100, du rapport #101 et du script `tools/validate-runtime-rpg.ps1`
3. verification Docker avec `docker ps`
4. verification PostgreSQL avec `SELECT 1`
5. reapplication des migrations `009` a `016`
6. reapplication des seeds RPG MVP
7. execution des requetes de verification
8. verification complementaire des octets UTF-8 pour `factions`
9. controles git finaux

## 10. Tests runtime nanos world restants

Restent a faire :

- copier les packages sur le vrai serveur nanos world local
- preparer le vrai `Config.toml` local hors depot
- lancer `NanosWorldServer.exe --playtest`
- executer la checklist runtime complete du guide #100

## 11. Risques restants

- la validation runtime nanos world complete reste a faire
- l'affichage de certains accents dans `psql` sous console Windows peut dependre de la code page
- `character_reputations` et `contracts` restent vides tant que les tests runtime ne sont pas joues
- la table `character_skills` conserve une colonne legacy `xp`

## 12. Resultat git status -sb

Le resultat final a ete releve apres creation des documents et correction de la procedure de seed.

## 13. Message de commit recommande

```text
docs(qa): add rpg database validation results
```
