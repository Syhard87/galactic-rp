# Runtime RPG Validation

## 1. Objectif de la validation

Ce guide sert a valider localement, en runtime nanos world, le socle RPG ajoute sur les tickets `#90` a `#99` sans ajouter de nouveau gameplay.

Perimetre couvert :

- personnages et personnage actif
- inventaire et items debug
- progression generale
- competences
- quetes
- craft
- stations de craft
- qualite des objets craftes
- reputation
- contrats joueurs
- commandes chat associees
- base PostgreSQL, migrations et seeds

Ce document part d'un principe simple :

- la logique serveur est la source de verite
- le vrai `Config.toml` local du serveur nanos world ne doit jamais etre committe
- les commandes debug doivent rester reservees au local/dev via `[custom_settings]`

## 2. Prerequis Docker / PostgreSQL

Prerequis minimaux :

- Docker Desktop ou moteur Docker compatible Compose
- PowerShell
- depot `galactic-rp` a jour sur la branche de validation locale
- installation locale nanos world serveur hors depot

Fichiers utilises :

- `docker/docker-compose.yml`
- `docker/.env.example`
- `tools/start-dev.ps1`

Demarrage recommande de la stack locale :

```powershell
.\tools\start-dev.ps1
```

Commandes manuelles equivalentes :

```powershell
docker compose --env-file docker/.env.example -f docker/docker-compose.yml up -d
docker compose --env-file docker/.env.example -f docker/docker-compose.yml ps
```

Services exposes par defaut :

- PostgreSQL : `localhost:5432`
- pgAdmin : `http://localhost:5050`

## 3. Verification du conteneur PostgreSQL

Verifier que Docker repond :

```powershell
docker ps --format "table {{.Names}}`t{{.Status}}"
```

Etat attendu :

- `galactic-rp-postgres` doit etre `Up ... (healthy)`
- `galactic-rp-pgadmin` doit etre demarre

Si le conteneur PostgreSQL n'apparait pas :

```powershell
.\tools\start-dev.ps1
```

Si le conteneur existe mais n'est pas `healthy` :

```powershell
docker compose --env-file docker/.env.example -f docker/docker-compose.yml logs -f postgres
```

## 4. Ordre recommande d'application des migrations

Pour un bootstrap complet local, appliquer les migrations dans l'ordre numerique reel du depot :

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

Les ajouts RPG recents a verifier en priorite sont :

```text
009_quest_skill_rewards.sql
010_crafting_foundation.sql
011_crafting_stations.sql
012_reputation_foundation.sql
013_quest_reputation_rewards.sql
014_quest_reputation_requirements.sql
015_contracts_foundation.sql
016_contracts_payment.sql
```

Exemple d'application manuelle d'une migration :

```powershell
Get-Content -Raw ".\database\migrations\010_crafting_foundation.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
```

## 5. Ordre recommande d'application des seeds

Ordre recommande pour une validation RPG locale coherente :

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

`dev_seed.sql` est utile seulement si vous voulez injecter un joueur / personnage de dev dans PostgreSQL. Il n'est pas obligatoire pour valider les systemes RPG si vous utilisez un vrai personnage runtime.

Exemples d'application manuelle :

```powershell
Get-Content -Raw ".\database\seeds\inventory_mvp_seed.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
Get-Content -Raw ".\database\seeds\quests_mvp_seed.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
Get-Content -Raw ".\database\seeds\quest_objectives_mvp_seed.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
Get-Content -Raw ".\database\seeds\crafting_stations_mvp_seed.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
Get-Content -Raw ".\database\seeds\crafting_mvp_seed.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
Get-Content -Raw ".\database\seeds\reputation_mvp_seed.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
```

## 6. Verification DB initiale

Avant de lancer nanos world, verifier au minimum :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, first_name, last_name, money_cash, money_bank FROM characters ORDER BY id;"
```

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, result_item_key, station_key, is_active FROM crafting_recipes ORDER BY key;"
```

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, title, reward_xp, reward_item_key, reward_skill_key, reward_reputation_key, required_reputation_key FROM quests ORDER BY key;"
```

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, name, min_value, max_value, default_value, is_active FROM reputation_definitions ORDER BY key;"
```

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, creator_character_id, assignee_character_id, type, reward_money, status, payment_status, paid_at FROM contracts ORDER BY id;"
```

Lecture attendue :

- les recettes `medkit_basic`, `ration_pack`, `comlink` existent
- les quetes `first_steps`, `medic_training`, `explorer_report`, `government_contract`, `underworld_delivery`, `explorer_sensitive_task` existent
- les reputations `government`, `military`, `merchant_guild`, `underworld`, `explorers` existent
- la table `contracts` existe meme si elle est vide

## 7. Copier les packages vers le serveur nanos world

Commande recommandee :

```powershell
$Repo = "C:\Users\Syhar\OneDrive - educ-valadon-limoges.fr\Bureau\galactic-rp\galactic-rp"
$ServerRoot = "C:\Program Files (x86)\Steam\steamapps\common\nanos-world-playtest\Server"

robocopy "$Repo\server\Packages" "$ServerRoot\Packages" /E /FFT /R:2 /W:2 /NP /XF ".gitkeep"
```

Attendu :

- le dossier local du serveur contient `gr-core`, `gr-database`, `gr-characters`, `gr-factions`, `gr-inventory`, `gr-progression`, `gr-skills`, `gr-chat`, `gr-crafting`, `gr-reputation`, `gr-quests`, `gr-contracts`
- aucun package n'est manquant au chargement

## 8. Custom settings locaux necessaires

Ne pas modifier le vrai `Config.toml` dans le depot.

Exemple local minimal a placer uniquement dans le vrai `Config.toml` du serveur nanos world local :

```toml
[custom_settings]
gr_database_host = "127.0.0.1"
gr_database_port = "5432"
gr_database_name = "galactic_rp"
gr_database_user = "galactic"
gr_database_password = "change-me-local-only"
gr_database_auto_connect = "true"

gr_inventory_debug_commands_enabled = true
gr_inventory_debug_allowed_platform_ids = "ID_LOCAL_NON_VERSIONNE"

gr_progression_debug_commands_enabled = true
gr_progression_debug_allowed_platform_ids = "ID_LOCAL_NON_VERSIONNE"

gr_skills_debug_commands_enabled = true
gr_skills_debug_allowed_platform_ids = "ID_LOCAL_NON_VERSIONNE"

gr_quests_debug_commands_enabled = true
gr_quests_debug_allowed_platform_ids = "ID_LOCAL_NON_VERSIONNE"

gr_crafting_debug_commands_enabled = true
gr_crafting_debug_allowed_platform_ids = "ID_LOCAL_NON_VERSIONNE"

gr_reputation_debug_commands_enabled = true
gr_reputation_debug_allowed_platform_ids = "ID_LOCAL_NON_VERSIONNE"

gr_contracts_debug_commands_enabled = true
gr_contracts_debug_allowed_platform_ids = "ID_LOCAL_NON_VERSIONNE"
```

Notes :

- remplacer `ID_LOCAL_NON_VERSIONNE` par le `platform_id` observe localement
- ne jamais committer ce fichier
- si aucun personnage n'existe encore localement, `gr_characters_dev_tools_enabled = "true"` peut etre utile temporairement, puis doit etre remis a `false`

## 9. Ordre de packages a charger

Ordre recommande pour la validation runtime actuelle :

```toml
packages = [
    "gr-core",
    "gr-database",
    "gr-characters",
    "gr-factions",
    "gr-inventory",
    "gr-progression",
    "gr-skills",
    "gr-chat",
    "gr-crafting",
    "gr-reputation",
    "gr-quests",
    "gr-contracts",
]
```

Point important :

- `gr-reputation` doit etre charge avant `gr-quests`, car `gr-quests` depend maintenant de `gr-reputation`

## 10. Lancement du serveur nanos world

Depuis le dossier du vrai serveur nanos world local :

```powershell
cd "C:\Program Files (x86)\Steam\steamapps\common\nanos-world-playtest\Server"
.\NanosWorldServer.exe --playtest
```

Points a verifier au demarrage :

- pas d'erreur `Package.Require`
- pas d'erreur de dependances package
- pas d'erreur de connexion PostgreSQL
- pas de `chat-command-not-supported` pour les commandes listees plus bas

## 11. Checklist de tests en jeu

### 11.1 Baseline personnage / profil / progression

Executer :

```txt
/whoami
/profile
/inv
/skills
/xpinfo
/classes
```

Verifier :

- le personnage actif est resolu
- `/profile` affiche identite, progression, faction et economie
- `/inv` s'exécute sans erreur
- `/skills` et `/xpinfo` s'executent sans erreur

Smoke test inventaire debug :

```txt
/giveitem credit_chip 1
/inv
/dropitem credit_chip 1
/inv
```

Verifier :

- `/giveitem` ajoute bien l'objet
- `/dropitem` retire / depose proprement l'objet sans casser l'inventaire

### 11.2 Quetes de base et recompenses

Executer :

```txt
/quests
/startquest first_steps
/questprogress command profile 1
/completequest first_steps
/quests
/inv
/xpinfo
```

Verifier :

- `first_steps` demarre
- `first_steps` se complete
- `credit_chip x1` est donne
- `reward_xp = 50` est visible via `/xpinfo`

Executer ensuite :

```txt
/startquest medic_training
/giveitem medkit_basic 1
/useitem medkit_basic
/completequest medic_training
/skills
/xpinfo
/inv
/reputations
```

Verifier :

- `medic_training` se complete
- `medkit_basic x1` est donne
- `medicine +50 XP` de quete est donne
- `government +10` est donne

Executer ensuite :

```txt
/startquest explorer_report
/explorereport J'ai trouve une zone interessante au nord du camp.
/completequest explorer_report
/skills
/xpinfo
/inv
/reputations
```

Verifier :

- `explorer_report` se complete
- `ration_pack x1` est donne
- `exploration +50 XP` est donne
- `explorers +15` est donne

Smoke test abandon :

```txt
/startquest government_contract
/abandonquest government_contract
/quests
```

Verifier :

- une quete demarree peut etre abandonnee proprement
- l'etat retourne a `abandoned` ou a l'etat attendu sans erreur serveur

### 11.3 Reputation et conditions de quetes

Executer :

```txt
/reputations
/startquest government_contract
/givereputation government 100 test
/reputations
/startquest government_contract
/questprogress
```

Verifier :

- `government_contract` est refusee avant le seuil si la reputation est insuffisante
- le message de refus mentionne `Requis=` et `actuel=`
- apres `government +100`, la quete devient demarrable

### 11.4 Craft de base, stations et diagnostics

Executer :

```txt
/giveitem credit_chip 10
/craftrecipes
/craftinfo ration_pack
/craftinfo medkit_basic
/craftstations
/craft ration_pack
/inv
```

Verifier :

- `/craftrecipes` liste `ration_pack`, `medkit_basic`, `comlink`
- `/craftinfo` affiche ingredients, station, XP craft et regle de qualite
- `/craftstations` liste les stations seedees
- `ration_pack` peut etre craft sans station

Puis tester une recette avec station :

```txt
/craft medkit_basic
```

Verifier :

- hors rayon, le message indique que la station requise est trop loin
- dans le rayon de `medical_workbench`, le craft reussit
- l'objet craft recu contient une metadata `quality` visible soit via `/inv`, soit en base

### 11.5 Contrats joueurs

Executer :

```txt
/contracts
/createcontract delivery 100 Livrer une caisse au spatioport
/contracts
/acceptcontract 1
/mycontracts
/completecontract 1
/mycontracts
/profile
```

Verifier :

- le contrat est cree
- le contrat passe a `accepted`
- le contrat passe a `completed`
- le paiement apparait comme `effectue`, `non-disponible` ou `echoue`
- si le paiement est `effectue`, `money_bank` augmente

Verifier les garde-fous :

```txt
/completecontract 1
/acceptcontract 1
/cancelcontract 1
```

Attendu :

- pas de double paiement
- pas de double completion
- messages d'erreur propres

### 11.6 Non-regression chat

Executer :

```txt
/me test
/do test
/f test
```

Verifier :

- les commandes RP historiques fonctionnent toujours
- aucune commande utile n'est bloquee par `gr-chat`

## 12. Requetes PostgreSQL apres tests

Verifier l'etat des personnages et de l'argent :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, first_name, last_name, money_cash, money_bank FROM characters ORDER BY id;"
```

Verifier l'inventaire et les metadata craft :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, item_key, quantity, metadata_json FROM inventory_items ORDER BY character_id, item_key;"
```

Verifier la progression generale :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, level, current_xp, total_xp, class_key, unspent_talent_points FROM character_progression ORDER BY character_id;"
```

Verifier les competences :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, skill_key, level, current_xp, total_xp FROM character_skills ORDER BY character_id, skill_key;"
```

Verifier les definitions et etats de quetes :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, title, reward_xp, reward_item_key, reward_skill_key, reward_reputation_key, required_reputation_key FROM quests ORDER BY key;"
```

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, quest_key, status, started_at, completed_at, updated_at FROM character_quests ORDER BY character_id, quest_key;"
```

Verifier les reputations personnage :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, reputation_key, value, rank FROM character_reputations ORDER BY character_id, reputation_key;"
```

Verifier les contrats et le paiement :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, creator_character_id, assignee_character_id, type, reward_money, status, payment_status, paid_at FROM contracts ORDER BY id;"
```

Verifier les recettes et stations :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, result_item_key, station_key, is_active FROM crafting_recipes ORDER BY key;"
```

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, name, station_type, position_x, position_y, position_z, radius, is_active FROM crafting_stations ORDER BY key;"
```

## 13. Problemes connus

- le binaire nanos world et le vrai `Config.toml` restent hors depot
- `dev_seed.sql` est optionnel et predatent une partie des conventions RPG actuelles ; il ne doit pas etre lu comme seed fonctionnel complet du gameplay recent
- la table `character_skills` conserve encore une colonne historique `xp` en plus de `current_xp` et `total_xp` ; pour la validation actuelle, lire `current_xp` et `total_xp`
- le paiement de contrat MVP credite `characters.money_bank` directement, sans package economie dedie
- le seed `factions_mvp_seed.sql` contient actuellement des caracteres accentues mal encodes dans ce depot ; cela n'empeche pas la validation fonctionnelle

## 14. Criteres de validation

La validation locale est consideree comme acceptable si :

- PostgreSQL demarre et repond
- les migrations `001` a `016` sont appliquees sans erreur fatale
- les seeds RPG recommandes sont appliques sans erreur fatale
- le serveur nanos world charge tous les packages sans erreur `Package.Require`
- les commandes baseline (`/whoami`, `/profile`, `/inv`, `/skills`, `/xpinfo`, `/classes`) fonctionnent
- les quetes MVP se demarrent et se completent
- les recompenses XP, objets, XP competence et reputation sont visibles
- les verrous de reputation sur les quetes fonctionnent
- le craft sans station et le craft avec station se comportent correctement
- la qualite des objets craftes est visible au moins en base
- les diagnostics craft (`/craftrecipes`, `/craftinfo`, `/craftstations`) fonctionnent
- les contrats peuvent etre crees, acceptes, completes et traces
- aucune commande utile n'affiche `chat-command-not-supported`

## 15. Procedure de rollback simple

Rollback local simple si les tests salissent trop la base ou si vous voulez repartir proprement :

1. arreter le serveur nanos world local
2. si vous acceptez de perdre les donnees locales de test :

```powershell
docker compose --env-file docker/.env.example -f docker/docker-compose.yml down -v
```

3. relancer l'infra :

```powershell
.\tools\start-dev.ps1
```

4. reappliquer les migrations et seeds dans l'ordre de ce document
5. recoller les packages avec `robocopy`

Attention :

- `down -v` supprime les volumes locaux Docker de test
- cette procedure est reservee au local
