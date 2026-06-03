# Runtime RPG DB validation

## 1. Objectif

Valider localement la partie PostgreSQL du socle RPG ajoute sur les tickets `#90` a `#99`.

Le but est de verifier :

- que Docker et PostgreSQL repondent
- que les migrations RPG recentes repassent proprement
- que les seeds MVP repassent proprement
- que les requetes de verification lisent un etat coherent
- qu'aucun probleme SQL bloquant ne reste cache avant la validation runtime nanos world

## 2. Etat Docker/PostgreSQL

Verification executee :

```powershell
docker ps
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT 1;"
```

Resultat observe :

- `galactic-rp-postgres` est demarre et `healthy`
- `galactic-rp-pgadmin` est demarre
- `SELECT 1` retourne correctement `1`

## 3. Migrations appliquees

Migrations RPG reappliquees dans l'ordre :

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

Resultat observe :

- toutes les migrations passent sans erreur bloquante
- les objets deja presents remontent des `NOTICE ... already exists` attendus
- l'idempotence est acceptable pour cette validation locale

## 4. Seeds appliques

Seeds reappliques dans l'ordre :

```text
factions_mvp_seed.sql
inventory_mvp_seed.sql
reputation_mvp_seed.sql
quests_mvp_seed.sql
quest_objectives_mvp_seed.sql
crafting_stations_mvp_seed.sql
crafting_mvp_seed.sql
```

Commande retenue pour les seeds :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1 -f /workspace/database/seeds/<seed>.sql
```

Justification :

- l'application via `Get-Content -Raw ... | docker exec ... psql` a corrompu les accents du seed factions dans cette chaine Windows/PowerShell
- l'execution via `psql -f` preserve correctement les octets UTF-8 depuis le volume monte dans le conteneur

## 5. Requetes de verification executees

Requetes executees :

```sql
SELECT id, first_name, last_name, money_cash, money_bank
FROM characters
ORDER BY id;
```

```sql
SELECT id, name, description, type, is_whitelisted
FROM factions
ORDER BY id;
```

```sql
SELECT character_id, item_key, quantity, metadata_json
FROM inventory_items
ORDER BY character_id, item_key;
```

```sql
SELECT character_id, skill_key, level, current_xp, total_xp
FROM character_skills
ORDER BY character_id, skill_key;
```

```sql
SELECT key, title, reward_xp, reward_item_key, reward_skill_key, reward_reputation_key, required_reputation_key
FROM quests
ORDER BY key;
```

```sql
SELECT key, name, min_value, max_value, default_value, is_active
FROM reputation_definitions
ORDER BY key;
```

```sql
SELECT character_id, reputation_key, value, rank
FROM character_reputations
ORDER BY character_id, reputation_key;
```

```sql
SELECT id, creator_character_id, assignee_character_id, type, reward_money, status, payment_status, paid_at
FROM contracts
ORDER BY id;
```

```sql
SELECT key, result_item_key, station_key, is_active
FROM crafting_recipes
ORDER BY key;
```

```sql
SELECT key, name, station_type, position_x, position_y, position_z, radius, is_active
FROM crafting_stations
ORDER BY key;
```

Verification complementaire UTF-8 :

```sql
SELECT name, encode(convert_to(name, 'UTF8'), 'hex') AS utf8_hex
FROM factions
WHERE type = 'government';
```

## 6. Resultats observes

Etat observe apres validation :

- `characters` contient 2 lignes locales
- `factions` contient 5 lignes coherentes
- `inventory_items` contient un inventaire de test minimal
- `character_skills` contient des competences locales de test
- `quests` contient 6 quetes MVP et reputation gates
- `reputation_definitions` contient 5 definitions
- `character_reputations` est vide avant test runtime, ce qui est acceptable
- `contracts` est vide avant test runtime, ce qui est acceptable
- `crafting_recipes` contient `comlink`, `medkit_basic`, `ration_pack`
- `crafting_stations` contient `engineering_bench`, `field_camp`, `medical_workbench`

## 7. Corrections effectuees

Correction necessaire dans ce lot :

- mise a jour de `docs/runtime-rpg-validation.md` pour recommander `docker exec ... psql -f /workspace/database/seeds/...` au lieu du pipe `Get-Content -Raw ... | docker exec ... psql` pour les seeds UTF-8

Cause :

- le pipe PowerShell local degrade les accents du seed factions en `?` dans PostgreSQL

Aucune correction de migration SQL n'a ete necessaire.

## 8. Problemes restants

- la validation runtime nanos world n'est pas executee dans ce lot
- `character_reputations` et `contracts` restent vides tant que les commandes runtime correspondantes ne sont pas jouees
- la table `character_skills` conserve une colonne legacy `xp` en plus de `current_xp` et `total_xp`
- l'affichage console Windows peut encore montrer des `??` selon la code page, meme si la verification hex UTF-8 est correcte

## 9. Prochaine etape runtime nanos world

Prochaine etape recommande :

1. utiliser `docs/runtime-rpg-validation.md`
2. recopier les packages sur le serveur nanos world local
3. preparer le vrai `Config.toml` local hors depot
4. lancer `NanosWorldServer.exe --playtest`
5. executer la checklist runtime complete en jeu
