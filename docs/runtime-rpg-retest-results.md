# Runtime RPG retest results

## 1. Objectif

Valider en runtime nanos world les correctifs appliques dans l'issue `#104` apres le smoke test `#103`.

Points a confirmer :

- `/profile` ne declenche plus `SkillXpRules` nil
- `/quests` ne declenche plus `normalize_integer` nil
- `/mycontracts` ne declenche plus l'erreur de binding SQL
- `/craft ration_pack` fonctionne ou renvoie une erreur metier propre
- les commandes RPG prevues ne sont pas rejetees par `gr-chat`

Etat actuel de ce document :

```txt
Runtime retest manuel encore a executer.
```

## 2. Branche testee

```txt
feature/issue-105-runtime-rpg-retest
```

## 3. Preparation locale

Copie packages :

```powershell
$Repo = "C:\Users\Syhar\OneDrive - educ-valadon-limoges.fr\Bureau\galactic-rp\galactic-rp"
$ServerRoot = "C:\Program Files (x86)\Steam\steamapps\common\nanos-world-playtest\Server"

robocopy "$Repo\server\Packages" "$ServerRoot\Packages" /E /FFT /R:2 /W:2 /NP /XF ".gitkeep"
```

Relance serveur :

```powershell
cd "C:\Program Files (x86)\Steam\steamapps\common\nanos-world-playtest\Server"

.\NanosWorldServer.exe --playtest --name "Galactic RP Dev" --map "default-blank-map" --port 7777 --query_port 7778 --announce 0 --dedicated_server 1 --max_players 8 --log_level 2
```

Prerequis locaux :

- PostgreSQL local demarre
- packages nanos world recopies apres `#104`
- vrai `Config.toml` local configure hors depot
- commandes debug activees localement dans `[custom_settings]`

## 4. Packages charges

Packages a verifier au demarrage :

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

Attendu :

- aucun echec `Package.Require`
- aucune erreur DB bloquante
- bridges `gr-crafting` et `gr-contracts` exportes

## 5. Corrections #104 a valider

1. `gr-progression`
   - fallback local / usage runtime correct de `SkillXpRules`
2. `gr-quests`
   - `normalize_integer` resolu dans `QuestRepository.lua`
3. `gr-contracts`
   - placeholders SQL distincts pour `/mycontracts`
4. `gr-crafting`
   - normalisation booleenne de `is_active`
5. `gr-chat`
   - allowlist RPG recente toujours compatible

## 6. Checklist runtime

### 6.1 Baseline progression

Commande : `/whoami`  
Resultat attendu : personnage actif resolu.  
Resultat observe : a renseigner.  
OK / KO : a renseigner.  
Log serveur associe : a renseigner.

Commande : `/profile`  
Resultat attendu : profil affiche sans erreur `SkillXpRules`.  
Resultat observe : a renseigner.  
OK / KO : a renseigner.  
Log serveur associe : a renseigner.

Commande : `/skills`  
Resultat attendu : competences affichees sans erreur serveur.  
Resultat observe : a renseigner.  
OK / KO : a renseigner.  
Log serveur associe : a renseigner.

Commande : `/xpinfo`  
Resultat attendu : progression et XP visibles sans erreur.  
Resultat observe : a renseigner.  
OK / KO : a renseigner.  
Log serveur associe : a renseigner.

Commande : `/classes`  
Resultat attendu : classes listees proprement.  
Resultat observe : a renseigner.  
OK / KO : a renseigner.  
Log serveur associe : a renseigner.

### 6.2 Quetes

Commande : `/quests`  
Resultat attendu : liste des quetes sans erreur `normalize_integer`.  
Resultat observe : a renseigner.  
OK / KO : a renseigner.  
Log serveur associe : a renseigner.

Commande : `/startquest first_steps`  
Resultat attendu : quete demarree.  
Resultat observe : a renseigner.  
OK / KO : a renseigner.  
Log serveur associe : a renseigner.

Commande : `/questprogress`  
Resultat attendu : progression de quete visible.  
Resultat observe : a renseigner.  
OK / KO : a renseigner.  
Log serveur associe : a renseigner.

Commande : `/completequest first_steps`  
Resultat attendu : quete completee sans erreur repository.  
Resultat observe : a renseigner.  
OK / KO : a renseigner.  
Log serveur associe : a renseigner.

Commande : `/quests`  
Resultat attendu : etat mis a jour apres completion.  
Resultat observe : a renseigner.  
OK / KO : a renseigner.  
Log serveur associe : a renseigner.

### 6.3 Craft

Commande : `/craftrecipes`  
Resultat attendu : recettes visibles, dont `ration_pack`.  
Resultat observe : a renseigner.  
OK / KO : a renseigner.  
Log serveur associe : a renseigner.

Commande : `/craftinfo ration_pack`  
Resultat attendu : details recette sans erreur.  
Resultat observe : a renseigner.  
OK / KO : a renseigner.  
Log serveur associe : a renseigner.

Commande : `/craftstations`  
Resultat attendu : stations listees sans erreur.  
Resultat observe : a renseigner.  
OK / KO : a renseigner.  
Log serveur associe : a renseigner.

Commande : `/giveitem scrap 5`  
Resultat attendu : items ajoutes si la commande debug est activee.  
Resultat observe : a renseigner.  
OK / KO : a renseigner.  
Log serveur associe : a renseigner.

Commande : `/giveitem electronic_component 5`  
Resultat attendu : items ajoutes si la commande debug est activee.  
Resultat observe : a renseigner.  
OK / KO : a renseigner.  
Log serveur associe : a renseigner.

Commande : `/craft ration_pack`  
Resultat attendu : craft reussi ou erreur metier propre, sans lecture `active=false` incorrecte.  
Resultat observe : a renseigner.  
OK / KO : a renseigner.  
Log serveur associe : a renseigner.

Commande : `/inv`  
Resultat attendu : inventaire mis a jour sans erreur.  
Resultat observe : a renseigner.  
OK / KO : a renseigner.  
Log serveur associe : a renseigner.

### 6.4 Reputation

Commande : `/reputations`  
Resultat attendu : reputations listees.  
Resultat observe : a renseigner.  
OK / KO : a renseigner.  
Log serveur associe : a renseigner.

Commande : `/givereputation government 10 test`  
Resultat attendu : reputation `government` augmentee si debug autorise.  
Resultat observe : a renseigner.  
OK / KO : a renseigner.  
Log serveur associe : a renseigner.

Commande : `/reputations`  
Resultat attendu : valeur mise a jour visible.  
Resultat observe : a renseigner.  
OK / KO : a renseigner.  
Log serveur associe : a renseigner.

### 6.5 Contracts

Commande : `/contracts`  
Resultat attendu : liste des contrats ouverts sans erreur.  
Resultat observe : a renseigner.  
OK / KO : a renseigner.  
Log serveur associe : a renseigner.

Commande : `/createcontract delivery 100 Livrer une caisse au spatioport`  
Resultat attendu : contrat cree.  
Resultat observe : a renseigner.  
OK / KO : a renseigner.  
Log serveur associe : a renseigner.

Commande : `/contracts`  
Resultat attendu : contrat visible dans la liste.  
Resultat observe : a renseigner.  
OK / KO : a renseigner.  
Log serveur associe : a renseigner.

Commande : `/acceptcontract 1`  
Resultat attendu : contrat accepte.  
Resultat observe : a renseigner.  
OK / KO : a renseigner.  
Log serveur associe : a renseigner.

Commande : `/mycontracts`  
Resultat attendu : plus d'erreur SQL binding ; contrat visible.  
Resultat observe : a renseigner.  
OK / KO : a renseigner.  
Log serveur associe : a renseigner.

Commande : `/completecontract 1`  
Resultat attendu : contrat complete sans erreur serveur.  
Resultat observe : a renseigner.  
OK / KO : a renseigner.  
Log serveur associe : a renseigner.

Commande : `/mycontracts`  
Resultat attendu : contrat complete visible, sans erreur SQL.  
Resultat observe : a renseigner.  
OK / KO : a renseigner.  
Log serveur associe : a renseigner.

Commande : `/profile`  
Resultat attendu : profil toujours stable apres flux contrats.  
Resultat observe : a renseigner.  
OK / KO : a renseigner.  
Log serveur associe : a renseigner.

### 6.6 Chat RP

Commande : `/me test`  
Resultat attendu : message RP accepte, pas de `chat-command-not-supported`.  
Resultat observe : a renseigner.  
OK / KO : a renseigner.  
Log serveur associe : a renseigner.

Commande : `/do test`  
Resultat attendu : message RP accepte, pas de `chat-command-not-supported`.  
Resultat observe : a renseigner.  
OK / KO : a renseigner.  
Log serveur associe : a renseigner.

Commande : `/f test`  
Resultat attendu : commande faction acceptee si package pret, sinon erreur metier propre, sans rejet `chat-command-not-supported`.  
Resultat observe : a renseigner.  
OK / KO : a renseigner.  
Log serveur associe : a renseigner.

## 7. Resultats observes

Etat actuel :

```txt
Aucun resultat de retest post-#104 n'a ete fourni dans ce lot.
Ce document reste donc une checklist runtime prete a completer.
```

## 8. Bugs corriges confirmes

Etat actuel :

```txt
A confirmer apres execution manuelle du retest.
```

Points a confirmer explicitement :

- disparition de `SkillXpRules nil`
- disparition de `normalize_integer nil`
- disparition du bind SQL invalide de `/mycontracts`
- disparition du faux `ration_pack active=false`
- absence de `chat-command-not-supported` sur les commandes RPG ciblees

## 9. Bugs encore presents

Etat actuel :

```txt
Aucun bug restant ne peut etre confirme dans ce lot sans nouveaux logs runtime.
```

Si un bug persiste pendant le retest, consigner :

- commande declenchante
- resultat observe
- extrait de log serveur exact
- impact joueur
- package probablement implique

## 10. Requetes PostgreSQL post-runtime

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, first_name, last_name, money_cash, money_bank FROM characters ORDER BY id;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, item_key, quantity, metadata_json FROM inventory_items ORDER BY character_id, item_key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, skill_key, level, current_xp, total_xp FROM character_skills ORDER BY character_id, skill_key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, title, reward_skill_key, reward_skill_xp, reward_reputation_key, reward_reputation_amount, required_reputation_key, required_reputation_min_value FROM quests ORDER BY key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, result_item_key, station_key, is_active FROM crafting_recipes ORDER BY key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, reputation_key, value, rank FROM character_reputations ORDER BY character_id, reputation_key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, creator_character_id, assignee_character_id, type, reward_money, status, payment_status, paid_at FROM contracts ORDER BY id;"
```

## 11. Decision finale

Decision actuelle :

```txt
Validation finale en attente du retest runtime manuel.
```

Le code corrige en `#104` est present sur la branche, mais cette issue `#105` ne peut pas confirmer le niveau de stabilite runtime sans execution reelle de la checklist.

## 12. Issues suivantes recommandees

- aucune nouvelle issue gameplay avant retest effectif
- si le retest est OK : reprise du backlog RPG normal
- si un bug persiste : ouvrir un ticket correctif cible avec logs, commande declenchante et package concerne
