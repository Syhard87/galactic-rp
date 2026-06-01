# Quests MVP

## Objectif

Documenter l'etat actuel du MVP serveur du systeme de quetes RP pour nanos world.

Cette documentation couvre :

- les quetes disponibles
- les objectifs de quete
- le cycle de vie serveur des quetes
- les recompenses XP et objets
- les commandes temporaires exposees en runtime
- les verifications PostgreSQL et scenarios de test locaux

## Package concerne

Le package concerne est :

- `server/Packages/gr-quests/`

Responsabilites :

- `gr-quests` est serveur-only
- il utilise `GRCharactersBridge` pour recuperer le personnage actif
- il utilise `GRProgressionBridge` pour donner de l'XP generale
- il utilise `GRInventoryBridge` pour donner des objets
- il expose `GRQuestsBridge` pour le reste du serveur

## Tables PostgreSQL

Tables principales :

- `quests`
- `character_quests`
- `quest_objectives`
- `character_quest_objectives`

Role de chaque table :

- `quests` : definition des quetes, recompenses XP, recompenses objets et statut d'activation
- `character_quests` : etat d'une quete pour un personnage donne
- `quest_objectives` : definition des objectifs rattaches a une quete
- `character_quest_objectives` : progression runtime d'un objectif pour une quete demarree

## Quetes MVP

Quetes seedees actuellement :

- `first_steps`
- `medic_training`
- `explorer_report`

Recompenses MVP :

- `first_steps` -> `reward_xp = 50`, `credit_chip x1`
- `medic_training` -> `reward_xp = 75`, `medkit_basic x1`
- `explorer_report` -> `reward_xp = 75`, `ration_pack x1`

## Objectifs MVP

Objectifs actuellement seedes :

- `first_steps / open_profile`
  - `target_type = command`
  - `target_key = profile`
- `medic_training / use_medkit`
  - `target_type = item_use`
  - `target_key = medkit_basic`
- `explorer_report / write_report`
  - `target_type = rp_action`
  - `target_key = exploration_report`

## Cycle de vie des quetes

Statuts utilises :

- `started`
- `completed`
- `abandoned`

Regles serveur actuelles :

- une quete `started` ne peut pas etre redemarree
- une quete `completed` non repetable ne peut pas etre redemarree
- une quete `completed` repetable peut etre redemarree
- une quete `abandoned` peut etre redemarree
- une quete `completed` ne peut pas etre abandonnee
- une quete ne peut pas etre completee si ses objectifs sont incomplets

## Commandes joueur

Commandes joueur disponibles :

- `/quests`
- `/startquest <quest_key>`
- `/completequest <quest_key>`
- `/abandonquest <quest_key>`
- `/explorereport <texte>`

Exemples :

```txt
/startquest first_steps
/profile
/completequest first_steps
```

```txt
/startquest medic_training
/giveitem medkit_basic 1
/useitem medkit_basic
/completequest medic_training
```

```txt
/startquest explorer_report
/explorereport J'ai trouve une zone interessante au nord du camp.
/completequest explorer_report
```

## Commandes debug staff/dev

Commande debug actuelle :

- `/questprogress <target_type> <target_key> <amount>`

Exemple :

```txt
/questprogress item_use medkit_basic 1
```

Configuration locale type dans le vrai `Config.toml` du serveur nanos world :

```toml
gr_quests_debug_commands_enabled = true
gr_quests_debug_allowed_platform_ids = "platform_id_1"
```

Regles :

- ne jamais commiter le vrai `Config.toml`
- remplacer `platform_id_1` par le `platform_id` vu dans les logs runtime
- ne pas activer cette commande en production

## Progression automatique des objectifs

Hooks automatiques actuellement relies au systeme de quetes :

- `/profile -> command/profile`
- `/useitem medkit_basic -> item_use/medkit_basic`
- `/explorereport <texte> -> rp_action/exploration_report`

Important :

- l'action principale ne doit jamais etre bloquee si la progression de quete echoue
- les logs serveur servent au diagnostic des erreurs de hook
- `/questprogress` reste disponible comme outil debug local

## Recompenses XP

Une quete peut donner de l'XP generale via `GRProgressionBridge`.

MVP actuel :

- `first_steps` donne `50` XP generales
- `medic_training` donne `75` XP generales
- `explorer_report` donne `75` XP generales

La recompense XP est donnee au moment de la completion de quete si la quete arrive bien a l'etat `completed`.

## Recompenses objets

Une quete peut donner un objet via `GRInventoryBridge`.

MVP actuel :

- `first_steps` donne `credit_chip x1`
- `medic_training` donne `medkit_basic x1`
- `explorer_report` donne `ration_pack x1`

La recompense objet reste serveur-only. Le client ne decide jamais de la quantite ou de l'objet ajoute.

## Configuration serveur

Ordre de chargement recommande :

```txt
gr-core
gr-database
gr-characters
gr-factions
gr-inventory
gr-progression
gr-skills
gr-quests
gr-chat
```

Le vrai `Config.toml` local ne doit pas etre committe.

## Tests runtime nanos world

Scenario 1 : `first_steps`

```txt
/quests
/startquest first_steps
/quests
/profile
/quests
/completequest first_steps
/xpinfo
/inv
/profile
```

Scenario 2 : `medic_training`

```txt
/startquest medic_training
/quests
/giveitem medkit_basic 1
/useitem medkit_basic
/quests
/completequest medic_training
/inv
/xpinfo
/skills
/profile
```

Scenario 3 : `explorer_report`

```txt
/startquest explorer_report
/quests
/explorereport J'ai trouve une zone interessante au nord du camp.
/quests
/completequest explorer_report
/inv
/xpinfo
/skills
/profile
```

Non-regression :

```txt
/whoami
/f test
/me test
/do test
/inv
/xpinfo
/skills
/classes
/profile
test local
```

Resultats attendus :

- les quetes demarrent correctement
- les objectifs passent de `0/1` a `1/1`
- les quetes ne se completent pas si les objectifs sont incomplets
- les recompenses XP et objets sont donnees
- aucune commande chat existante n'est cassee
- pas de `chat-command-not-supported`

## Verifications PostgreSQL

Verifier les definitions de quetes :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, title, reward_xp, reward_item_key, reward_item_quantity, is_repeatable, is_active FROM quests ORDER BY key;"
```

Verifier les objectifs configures :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT quest_key, objective_key, target_type, target_key, required_count FROM quest_objectives ORDER BY quest_key, order_index;"
```

Verifier l'etat des quetes par personnage :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, character_id, quest_key, status, started_at, completed_at, updated_at FROM character_quests ORDER BY character_id, quest_key, id;"
```

Verifier la progression des objectifs :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_quest_id, objective_key, current_count, required_count, completed_at FROM character_quest_objectives ORDER BY character_quest_id, objective_key;"
```

## Limites actuelles

Limites connues du MVP :

- pas de WebUI quetes
- pas de Datapad quetes
- pas de PNJ ni de systeme de dialogue
- pas de marqueur carte ni de guidance monde
- pas de table dediee pour persister le texte des rapports d'exploration
- pas d'automatisation gameplay complexe au-dela des hooks deja relies
- la commande `/questprogress` reste un outil debug local
- l'affichage chat de `/quests` reste volontairement simple

## Prochaines evolutions

Evolutions recommandees apres ce MVP :

- journal de quetes dans un Datapad ou une WebUI
- persistance dediee pour les rapports RP et leur historique
- objectifs relies a davantage d'actions gameplay serveur
- outils admin pour reset, debloquer ou corriger une progression de quete
- types d'objectifs plus riches
- quetes repetables plus explicites et mieux equilibrees
