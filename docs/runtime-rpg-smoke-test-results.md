# Runtime RPG smoke test results

## 1. Objectif

Documenter les resultats observes pendant le smoke test runtime nanos world du socle RPG recent, sans corriger le code dans ce lot.

Le but est de :

- confirmer les points runtime deja valides
- lister les bugs bloquants observes
- preparer une passe de correction dediee en issue `#104`

## 2. Branche testee

Branche testee :

```text
feature/issue-103-runtime-rpg-smoke-test
```

## 3. Preparation locale

Le serveur nanos world a ete lance manuellement avec :

```powershell
.\NanosWorldServer.exe --playtest --name "Galactic RP Dev" --map "default-blank-map" --port 7777 --query_port 7778 --announce 0 --dedicated_server 1 --max_players 8 --log_level 2
```

Contexte runtime retenu :

- PostgreSQL local disponible
- `default-blank-map`
- smoke test manuel deja effectue
- aucun changement de code applique dans cette issue

## 4. Packages charges

Packages observes comme correctement charges :

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

Bridges confirms par les logs :

- `gr-crafting` exporte bien son bridge
- `gr-contracts` exporte bien son bridge

## 5. PostgreSQL

Points valides :

- connexion PostgreSQL OK
- smoke test PostgreSQL `SELECT 1` OK
- acces DB suffisant pour le chargement runtime des packages

## 6. Connexion joueur et selection personnage

Points valides :

- joueur `Syhard` connecte
- player DB charge
- ecran de selection personnage affiche
- `character_id=3` selectionne
- spawn depuis position persistante OK
- sauvegarde automatique de position OK

## 7. Commandes / systemes valides

Systemes valides pendant le smoke test :

- lancement serveur OK
- connexion PostgreSQL OK
- chargement packages OK
- selection personnage OK
- spawn position persistante OK
- sauvegarde position OK
- bridge `gr-crafting` exporte
- bridge `gr-contracts` exporte

Contrats :

- creation de contrat OK
- log observe :

```text
Contract created id=1 creator_character_id=3 type=delivery reward_money=100
```

## 8. Bugs runtime observes

### Bug 1 - Profile / progression

Erreur observee :

```text
Lua Error on SQL Select Callback:
[gr-progression/Server/Index.lua]:227: attempt to index a nil value (global 'SkillXpRules')
```

Contexte :

- erreur apres chargement progression
- probablement pendant `/profile` ou un affichage profil associe
- `SkillXpRules` n'est pas resolu dans ce contexte runtime

### Bug 2 - Quests repository

Erreur observee :

```text
Lua Error on SQL Select Callback:
[gr-quests/Server/QuestRepository.lua]:450: attempt to call a nil value (global 'normalize_integer')
```

Contexte :

- le repository quetes appelle `normalize_integer`
- la fonction est absente ou non visible dans ce fichier
- l'erreur se reproduit pendant les flux lies aux quetes

### Bug 3 - Contracts / mycontracts SQL binding

Erreur observee :

```text
Failed to execute Select query:
WHERE creator_character_id = :0 OR assignee_character_id = :0

PostgreSQL Error: bind message supplies 1 parameters, but prepared statement requires 2
```

Contexte :

- bug observe sur les requetes de type `/mycontracts`
- le runtime PostgreSQL / nanos world ne tolere pas la reutilisation du meme placeholder `:0` deux fois dans cette requete

### Bug 4 - Craft a verifier

Log observe :

```text
Recipe loaded key=ration_pack active=false
```

Contexte :

- `ration_pack` est attendue comme recette MVP de test
- si la recette est inactive, `/craft ration_pack` ne valide pas correctement le parcours craft
- point a verifier cote seed ou lecture repository

### Bug 5 - Commande chat non supportee

Log observe :

```text
[gr-chat][server] Local RP message rejected reason=chat-command-not-supported.
```

Contexte :

- une ou plusieurs commandes tapees en jeu ne sont pas reconnues ou pas autorisees
- les commandes exactes ne sont pas encore isolees dans ce lot

## 9. Analyse des bugs

### Analyse bug 1

Cause probable :

- reference runtime invalide a `SkillXpRules`
- table / module non charge ou non visible dans `gr-progression/Server/Index.lua`

Impact :

- blocage partiel de `/profile` ou des lectures progression associees

### Analyse bug 2

Cause probable :

- `normalize_integer` n'est pas declaree dans `QuestRepository.lua`
- ou la fonction existe dans un autre fichier mais n'est pas importee / scopee correctement

Impact :

- blocage des requetes quetes cote repository

### Analyse bug 3

Cause probable :

- le moteur SQL du runtime n'accepte pas `:0` reutilise deux fois dans la meme requete preparee

Correction probable future :

```sql
WHERE creator_character_id = :0 OR assignee_character_id = :1
```

avec deux bindings :

- `character_id`
- `character_id`

Impact :

- `/mycontracts` ou une requete equivalente ne fonctionne pas correctement

### Analyse bug 4

Cause probable :

- desynchronisation entre le seed craft attendu et l'etat effectivement lu au runtime
- ou lecture repository / normalisation booleenne incorrecte

Impact :

- impossible de valider proprement le chemin craft MVP sur `ration_pack`

### Analyse bug 5

Cause probable :

- allowlist `gr-chat` incomplete
- ou commande tapee inexistante / mal routee

Impact :

- rejet d'au moins une commande locale RP ou debug pendant le smoke test

## 10. Requetes PostgreSQL recommandees apres runtime

Verifier les quetes :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, title, reward_xp, reward_item_key, reward_skill_key, reward_reputation_key, required_reputation_key, is_active FROM quests ORDER BY key;"
```

Verifier la progression :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, level, current_xp, total_xp, class_key, unspent_talent_points FROM character_progression ORDER BY character_id;"
```

Verifier les competences :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, skill_key, level, current_xp, total_xp FROM character_skills ORDER BY character_id, skill_key;"
```

Verifier les reputations :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, reputation_key, value, rank FROM character_reputations ORDER BY character_id, reputation_key;"
```

Verifier les contrats :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, creator_character_id, assignee_character_id, type, reward_money, status, payment_status, paid_at FROM contracts ORDER BY id;"
```

Verifier les recettes craft :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, result_item_key, station_key, is_active FROM crafting_recipes ORDER BY key;"
```

## 11. Decision finale

Decision :

- smoke test runtime partiellement valide
- socle serveur, connexion DB, selection personnage, spawn et chargement packages : OK
- smoke test gameplay RPG global : KO pour acceptation finale

Raison :

- plusieurs bugs runtime bloquants existent encore sur progression, quetes, contrats et parcours craft de test

## 12. Issues suivantes recommandees

Issue recommandeee immediate :

- `#104` pour corriger les bugs runtime bloques par ce smoke test

Sous-sujets a couvrir dans `#104` :

1. corriger `SkillXpRules` dans `gr-progression`
2. corriger `normalize_integer` dans `gr-quests`
3. corriger le binding SQL `/mycontracts`
4. verifier pourquoi `ration_pack` est lue inactive
5. identifier la commande rejetee par `gr-chat` et corriger l'allowlist ou le routage
