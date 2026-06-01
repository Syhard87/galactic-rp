# RPG Progression MVP

## Objectif

Documenter l'etat actuel du MVP RPG serveur autour de la progression generale, des classes, des competences et des commandes temporaires exposees en runtime nanos world.

Cette documentation couvre uniquement le socle MVP actuellement implemente. Elle ne couvre pas un Datapad complet, une UI Web ou un systeme de talents exploitable.

## Packages concernes

Packages impliques dans le MVP RPG :

- `gr-characters`
- `gr-progression`
- `gr-skills`
- `gr-chat`

Responsabilites :

- `gr-characters` fournit le personnage actif via `GRCharactersBridge.GetActiveCharacter(...)`
- `gr-progression` gere le niveau general, l'XP generale, la classe et les points de talent non depenses
- `gr-skills` gere les competences, leur XP, leur niveau et leurs liens avec l'XP generale
- `gr-chat` laisse passer les commandes temporaires via son allowlist externe sans casser `/me`, `/do`, `/f` ni le chat local

## Progression generale

La progression generale est stockee dans la table `character_progression`.

Champs principaux :

- `character_progression.character_id`
- `character_progression.level`
- `character_progression.current_xp`
- `character_progression.total_xp`
- `character_progression.class_key`
- `character_progression.specialization_key`
- `character_progression.unspent_talent_points`

Regle MVP :

```txt
XP requise pour niveau suivant = level * 100
```

Exemples :

- niveau 1 -> 2 : `100`
- niveau 2 -> 3 : `200`
- niveau 3 -> 4 : `300`

Les gains d'XP generale peuvent venir :

- de `/givexp <amount>` en debug staff/dev
- des gains d'XP competence depuis l'integration `gr-skills -> gr-progression`

## Classes RPG

Classes MVP actuellement definies :

- `civilian`
- `military_recruit`
- `medic`
- `engineer`
- `merchant`
- `smuggler`
- `explorer`

Commandes associees :

- `/classes`
- `/setclass <class_key>`

Description courte :

- `civilian` : profil neutre sans specialisation
- `military_recruit` : combat, discipline et operations
- `medic` : soin, diagnostic et soutien medical
- `engineer` : reparation, mecanique et fabrication
- `merchant` : commerce, logistique et contrats
- `smuggler` : discretion, marche noir et falsification
- `explorer` : exploration, recolte et survie

## Competences RPG

Competences MVP actuellement definies :

- `light_weapons`
- `medicine`
- `mechanics`
- `commerce`
- `smuggling`
- `exploration`
- `survival`
- `crafting`

Regle MVP :

```txt
XP competence requise pour niveau suivant = level * 75
```

Exemples :

- niveau 1 -> 2 : `75`
- niveau 2 -> 3 : `150`
- niveau 3 -> 4 : `225`

Commandes associees :

- `/skills`
- `/giveskillxp <skill_key> <amount>`

## Bonus de classe

Les bonus de classe s'appliquent aux gains d'XP competence avant sauvegarde de la competence et avant conversion vers l'XP generale.

Correspondances MVP :

- `military_recruit -> light_weapons`
- `medic -> medicine`
- `engineer -> mechanics`, `crafting`
- `merchant -> commerce`
- `smuggler -> smuggling`
- `explorer -> exploration`, `survival`
- `civilian -> aucun bonus`

Regle :

```txt
+10% XP competence
```

Calcul :

```txt
final_skill_xp = floor(base_skill_xp * 1.10)
```

Garantie :

- si le bonus s'applique mais que l'arrondi ne change pas la valeur, le systeme ajoute au moins `+1`

Exemples :

- `Classe medic + /giveskillxp medicine 100 = 110 XP medicine`
- `Classe medic + /useitem medkit_basic = medicine +11 XP`
- `Classe engineer + /giveskillxp medicine 100 = 100 XP medicine`

## Lien XP competence -> XP generale

Tout gain d'XP competence peut aussi donner un gain d'XP generale.

Regle MVP :

```txt
general_xp = floor(skill_xp_amount * 0.25)
minimum = 1 si skill_xp_amount > 0
```

Important :

- depuis l'ajout des bonus de classe, l'XP generale est calculee a partir de l'XP competence finale, bonus inclus

Exemples :

- `medicine +100 XP sans bonus = +25 XP generale`
- `medicine +110 XP avec bonus = +27 XP generale`
- `medicine +11 XP avec bonus medic = +2 XP generale`

## Commandes joueur

Commandes accessibles au joueur pour le MVP RPG :

- `/xpinfo`
- `/classes`
- `/setclass <class_key>`
- `/skills`
- `/profile`

Resume :

- `/xpinfo` affiche niveau, XP generale, total XP et classe
- `/classes` liste les classes disponibles
- `/setclass <class_key>` change la classe RPG du personnage actif
- `/skills` affiche les competences deja creees pour le personnage actif
- `/profile` affiche une fiche synthese : identite, classe, niveau, XP, points de talent, faction et competences

Lien avec l'inventaire :

- `/useitem medkit_basic`

Comportement actuel de `/useitem medkit_basic` :

- consomme un medikit
- donne de l'XP `medicine`
- donne indirectement de l'XP generale
- beneficie du bonus de classe `medic` si la classe active correspond

## Commandes debug staff/dev

Commandes debug actuellement exposees :

- `/givexp <amount>`
- `/giveskillxp <skill_key> <amount>`

Regles :

- refusees par defaut
- activables uniquement en local via `[custom_settings]`
- ne jamais commiter de vrai identifiant personnel
- ne jamais laisser ces commandes ouvertes en production

## Configuration locale de debug

Exemples generiques a placer dans le vrai `Config.toml` local du serveur nanos world, sous `[custom_settings]` :

```toml
gr_progression_debug_commands_enabled = true
gr_progression_debug_allowed_platform_ids = "platform_id_1"

gr_skills_debug_commands_enabled = true
gr_skills_debug_allowed_platform_ids = "platform_id_1"

gr_inventory_debug_commands_enabled = true
gr_inventory_debug_allowed_platform_ids = "platform_id_1"
```

Notes importantes :

- remplacer `platform_id_1` par le `platform_id` visible dans les logs runtime locaux
- ne jamais commiter le vrai `Config.toml`
- garder ces valeurs uniquement pour le developpement local
- `/givexp`, `/giveskillxp` et `/giveitem` doivent rester fermes hors environnement de dev

## Tests runtime nanos world

Scenario complet recommande :

```txt
/profile
/xpinfo
/classes
/setclass medic
/xpinfo
/skills
/giveskillxp medicine 100
/skills
/xpinfo
/giveitem medkit_basic 1
/useitem medkit_basic
/inv
/skills
/profile
/whoami
/f test
/me test
/do test
test local
```

Resultats attendus :

- `/profile` affiche la fiche RPG du personnage actif
- `/setclass medic` change la classe
- `/giveskillxp medicine 100` donne de l'XP competence
- le bonus `medic -> medicine` s'applique
- l'XP generale augmente aussi
- `/useitem medkit_basic` donne egalement de l'XP `medicine`
- les commandes RP existantes continuent de fonctionner
- aucun `chat-command-not-supported` n'apparait pour les commandes RPG et inventory

## Verifications PostgreSQL

Verifier la progression generale :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, level, current_xp, total_xp, class_key, unspent_talent_points FROM character_progression ORDER BY character_id;"
```

Verifier les competences :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, skill_key, level, current_xp, total_xp, last_gain_at FROM character_skills ORDER BY character_id, skill_key;"
```

Lecture attendue :

- `character_progression` doit montrer la classe et l'XP generale mises a jour
- `character_skills` doit montrer les competences creees ou mises a jour
- apres un bonus de classe, la colonne `current_xp` ou `total_xp` de la competence doit refleter l'XP finale bonifiee

## Limites actuelles

Limites connues du MVP RPG :

- pas de WebUI progression
- pas de Datapad complet
- pas de specialisation exploitable
- pas de talents attribuables par le joueur
- pas de quetes dynamiques ou de journal de quetes integre dans cette documentation
- pas d'anti-farm avance
- pas de bonus passifs gameplay complets relies aux competences
- `/givexp` et `/giveskillxp` restent des commandes debug, pas des outils admin de production
- `/profile` reste un affichage texte dans le chat, sans interface riche

## Prochaines evolutions

Evolutions recommandees apres ce MVP :

- Datapad ou WebUI progression/skills
- affichage des labels de classes et de competences au lieu des seules keys quand utile
- systeme de talents actif avec depense de points
- bonus gameplay reels relies au niveau de competence
- quetes et activites qui alimentent naturellement l'XP
- anti-farm plus fin sur les gains repetitifs
- integration plus riche entre factions, progression, inventaire et reputation
- articulation documentaire avec le MVP quetes dans `docs/quests-mvp.md`
