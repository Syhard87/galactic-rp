# Issue #103  Runtime RPG smoke test

## 1. Resume de limplementation

Documentation du smoke test runtime nanos world deja execute manuellement.

Ce lot :

- ne corrige aucun bug
- ne modifie aucun package Lua
- ne modifie aucune migration
- ne modifie aucun seed
- consolide les points valides et les bugs bloquants detectes

## 2. Agents consultes

- software-architect
- backend-lua
- database-engineer
- qa-tester
- security-reviewer
- nanos-world-lua-agent

## 3. Fichiers crees

- `docs/runtime-rpg-smoke-test-results.md`
- `docs/codex-reports/issue-103-runtime-rpg-smoke-test-report.md`

## 4. Fichiers modifies

- aucun

## 5. Fichiers explicitement non modifies

- `server/Packages/`
- `database/migrations/`
- `database/seeds/`
- vrai `Config.toml`

## 6. Resultats runtime valides

Points valides documentes :

- serveur lance avec succes
- PostgreSQL connecte
- smoke test PostgreSQL `SELECT 1` OK
- joueur `Syhard` connecte
- player DB charge
- character selection affichee
- `character_id=3` selectionne
- spawn depuis position persistante OK
- sauvegarde automatique position OK
- packages charges correctement :
  - `gr-core`
  - `gr-database`
  - `gr-characters`
  - `gr-factions`
  - `gr-inventory`
  - `gr-progression`
  - `gr-skills`
  - `gr-reputation`
  - `gr-quests`
  - `gr-chat`
  - `gr-crafting`
  - `gr-contracts`
- `gr-crafting` exporte bien son bridge
- `gr-contracts` exporte bien son bridge
- creation de contrat OK :
  - `Contract created id=1 creator_character_id=3 type=delivery reward_money=100`

## 7. Bugs runtime detectes

### Bug 1 - Profile / progression

```text
Lua Error on SQL Select Callback:
[gr-progression/Server/Index.lua]:227: attempt to index a nil value (global 'SkillXpRules')
```

### Bug 2 - Quests repository

```text
Lua Error on SQL Select Callback:
[gr-quests/Server/QuestRepository.lua]:450: attempt to call a nil value (global 'normalize_integer')
```

### Bug 3 - Contracts / mycontracts SQL binding

```text
Failed to execute Select query:
WHERE creator_character_id = :0 OR assignee_character_id = :0

PostgreSQL Error: bind message supplies 1 parameters, but prepared statement requires 2
```

### Bug 4 - Craft a verifier

```text
Recipe loaded key=ration_pack active=false
```

### Bug 5 - Commande chat non supportee

```text
[gr-chat][server] Local RP message rejected reason=chat-command-not-supported.
```

## 8. Corrections a prevoir en #104

Corrections recommandees pour l'issue suivante :

1. `gr-progression`
   - garantir la disponibilite runtime de `SkillXpRules`
   - verifier le chemin exact qui casse `/profile`

2. `gr-quests`
   - declarer / exposer correctement `normalize_integer`
   - verifier les callbacks SQL lies aux quetes

3. `gr-contracts`
   - remplacer `creator_character_id = :0 OR assignee_character_id = :0`
   - par une requete avec deux placeholders distincts

4. `gr-crafting`
   - verifier pourquoi `ration_pack` est lue `active=false`
   - comparer runtime, seed et lecture repository

5. `gr-chat`
   - identifier la ou les commandes exactes rejetees
   - corriger l'allowlist ou la resolution de commande

## 9. Tests effectues

Tests documentes dans ce lot :

- lecture des docs de validation precedentes
- transcription des resultats du smoke test runtime manuel
- classement des points OK
- classement des bugs KO
- recommandations de suite pour `#104`

## 10. Tests runtime restants

Restent a faire apres `#104` :

- relancer le smoke test complet nanos world
- retester `/profile`
- retester `/quests`
- retester `/mycontracts`
- retester `/craft ration_pack`
- retester la commande chat rejetee

## 11. Risques restants

- le socle serveur charge, mais plusieurs flux RPG restent bloques runtime
- tant que `#104` n'est pas traitee, le smoke test ne peut pas etre considere comme acceptable globalement
- le point chat non supporte reste incompletement isole

## 12. Resultat git status -sb

Le resultat final a ete releve apres creation des documents de resultat runtime.

## 13. Message de commit recommande

```text
docs(qa): document runtime rpg smoke test results
```
