# Issue #100  Runtime RPG validation

## 1. Resume de limplementation

Ajout d'un guide runtime unifie pour valider localement les systemes RPG recents `#90` a `#99`, sans modifier le gameplay serveur.

Livrables :

- `docs/runtime-rpg-validation.md`
- `tools/validate-runtime-rpg.ps1`

Le guide couvre :

- prerequisites Docker / PostgreSQL
- ordre des migrations
- ordre des seeds
- custom settings locaux
- ordre de chargement des packages
- checklist runtime en jeu
- requetes PostgreSQL avant et apres tests
- rollback local simple

Le script PowerShell automatise :

- verification Docker
- verification du conteneur `galactic-rp-postgres`
- application des migrations
- application des seeds RPG
- requetes de verification
- copie des packages vers le serveur nanos world local

## 2. Agents consultes

- software-architect
- database-engineer
- backend-lua
- nanos-world-lua-agent
- security-reviewer
- qa-tester

## 3. Fichiers crees

- `docs/runtime-rpg-validation.md`
- `tools/validate-runtime-rpg.ps1`
- `docs/codex-reports/issue-100-runtime-rpg-validation-report.md`

## 4. Fichiers modifies

- aucun

## 5. Fichiers explicitement non modifies

- `server/Packages/`
- `database/migrations/`
- `database/seeds/`
- vrai `Config.toml`

## 6. Documentation ajoutee

Documentation ajoutee :

- `docs/runtime-rpg-validation.md`

Contenu principal :

- objectif et perimetre QA
- prerequis locaux
- verification du conteneur PostgreSQL
- ordre recommande d'application des migrations et seeds
- custom settings locaux de debug
- ordre recommande des packages nanos world
- checklist runtime en jeu
- requetes PostgreSQL de verification
- problemes connus
- criteres de validation
- rollback local simple

## 7. Script ajoute

Script ajoute :

- `tools/validate-runtime-rpg.ps1`

Comportement :

- variables de chemin en tete de script
- verification de Docker
- verification du conteneur PostgreSQL
- application des migrations `001` a `016`
- application des seeds RPG recommandes
- option `-IncludeDevSeed` pour `dev_seed.sql`
- requetes PostgreSQL de verification
- copie des packages via `robocopy`
- affichage de la commande manuelle de lancement nanos world

## 8. Migrations a appliquer

Ordre complet documente :

```text
001_init.sql
002_factions_foundation.sql
003_inventory_foundation.sql
004_character_progression_foundation.sql
005_character_skills_foundation.sql
006_quests_foundation.sql
007_quest_item_rewards.sql
008_quest_objectives_foundation.sql
009_quest_skill_rewards.sql
010_crafting_foundation.sql
011_crafting_stations.sql
012_reputation_foundation.sql
013_quest_reputation_rewards.sql
014_quest_reputation_requirements.sql
015_contracts_foundation.sql
016_contracts_payment.sql
```

Le guide isole aussi les migrations recentes `#90` a `#99` pour les validations ciblees.

## 9. Seeds a appliquer

Ordre recommande documente :

```text
factions_mvp_seed.sql
inventory_mvp_seed.sql
reputation_mvp_seed.sql
quests_mvp_seed.sql
quest_objectives_mvp_seed.sql
crafting_stations_mvp_seed.sql
crafting_mvp_seed.sql
```

Seed optionnel :

```text
dev_seed.sql
```

Justification :

- `dev_seed.sql` reste utile pour un bootstrap DB local, mais n'est pas requis pour tous les tests runtime RPG

## 10. Checklist runtime

La checklist runtime documentee couvre :

- baseline personnage / profil / progression
- quetes de base
- recompenses XP / items / skill XP / reputation
- craft de base
- stations de craft
- qualite des objets craftes
- diagnostics `/craftrecipes`, `/craftinfo`, `/craftstations`
- reputation et gates de reputation sur quetes
- contrats joueurs et paiement MVP
- non-regression chat `/me`, `/do`, `/f`

## 11. Requetes PostgreSQL

Le guide regroupe des requetes de verification pour :

- `characters`
- `inventory_items`
- `character_progression`
- `character_skills`
- `quests`
- `character_quests`
- `character_reputations`
- `contracts`
- `crafting_recipes`
- `crafting_stations`

## 12. Tests effectues

Tests realises dans ce lot :

1. verification de la branche et des prerequis du ticket `#100`
2. lecture de la documentation existante :
   - `docs/architecture.md`
   - `docs/backlog.md`
   - `docs/mvp-tech-validation-checklist.md`
   - `docs/qa-character-mvp.md`
   - `docs/inventory-mvp.md`
   - `docs/quests-mvp.md`
   - `docs/rpg-progression-mvp.md`
3. lecture des seeds et migrations RPG recentes
4. verification des dependances `Package.toml`
5. verification Docker locale :
   - `docker ps --format "table {{.Names}}`t{{.Status}}"`
6. verification PostgreSQL locale :
   - recettes craft
   - quetes
   - reputations
   - colonnes `character_skills`
   - colonnes `contracts`
7. creation du guide et du script

## 13. Tests runtime restants

Restent a faire manuellement :

- copier les packages vers le vrai serveur nanos world local
- preparer le vrai `Config.toml` local
- lancer `NanosWorldServer.exe --playtest`
- executer la checklist complete en jeu
- verifier les mutations DB apres test

## 14. Risques restants

- runtime nanos world non lance ici, donc la checklist reste documentee mais pas executee de bout en bout
- `dev_seed.sql` est pratique pour le bootstrap local, mais ne doit pas etre pris pour un seed gameplay complet des systems RPG recents
- la table `character_skills` conserve une colonne legacy `xp` en plus de `current_xp` / `total_xp`
- `factions_mvp_seed.sql` contient des caracteres accentues mal encodes dans l'etat actuel du depot
- le paiement de contrats reste un MVP direct sur `characters.money_bank`, sans package economie dedie

## 15. Resultat git status -sb

Le resultat final a ete releve apres creation des fichiers de documentation et du script.

## 16. Message de commit recommande

```text
docs(qa): add runtime rpg validation guide
```
