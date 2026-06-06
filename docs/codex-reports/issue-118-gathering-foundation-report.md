# Issue #118  Gathering foundation MVP

## 1. Résumé de limplémentation

Ajout dun package serveur `gr-gathering` permettant de lister des nodes de récolte, consulter leurs informations et lancer une récolte via commandes debug serveur.

Le flux MVP est server-authoritative :

- résolution du personnage actif côté serveur ;
- lecture du node en base ;
- vérification optionnelle de proximité ;
- vérification du cooldown personnage/node ;
- calcul serveur de la quantité ;
- ajout item via `GRInventoryBridge.AddItem(...)` ;
- tentative dout XP via `GRSkillsBridge.AddSkillXp(...)` si configuré ;
- persistance du cooldown après ajout inventaire réussi.

Le système supporte déjà `requires_proximity=true`, mais le seed MVP laisse tous les nodes en `requires_proximity=false` pour ne pas casser les tests runtime sans coordonnées fiables.

## 2. Agents consultés

- `software-architect`
- `backend-lua`
- `database-engineer`
- `security-reviewer`
- `qa-tester`
- `nanos-world-lua-agent`

## 3. Fichiers créés

- `database/migrations/024_gathering_foundation.sql`
- `database/seeds/gathering_mvp_seed.sql`
- `server/Packages/gr-gathering/Package.toml`
- `server/Packages/gr-gathering/Shared/Index.lua`
- `server/Packages/gr-gathering/Server/Index.lua`
- `server/Packages/gr-gathering/Server/GatheringRepository.lua`
- `server/Packages/gr-gathering/Server/GatheringService.lua`
- `docs/codex-reports/issue-118-gathering-foundation-report.md`

## 4. Fichiers modifiés

- `server/Packages/gr-chat/Server/Index.lua`

## 5. Fichiers explicitement non modifiés

- `server/Packages/gr-economy/`
- `server/Packages/gr-inventory/`
- `server/Packages/gr-skills/`
- `server/Packages/gr-shops/`
- `server/Packages/gr-contracts/`
- `Config.toml` réel

## 6. Migration SQL ajoutée

Migration ajoutée :

- `database/migrations/024_gathering_foundation.sql`

Tables créées :

- `gathering_nodes`
- `character_gathering_cooldowns`

Points clés :

- `gathering_nodes.key` unique ;
- contraintes sur quantités, XP, cooldown et radius ;
- `character_gathering_cooldowns` avec clé primaire `(character_id, node_key)` ;
- FK vers `characters(id)` et `gathering_nodes(key)` ;
- aucun `DROP`.

## 7. Seed MVP ajouté

Seed ajouté :

- `database/seeds/gathering_mvp_seed.sql`

Le seed :

- ajoute les items manquants `scrap`, `electronic_component`, `water_bottle` dans `items` ;
- ajoute les nodes :
  - `scrap_field`
  - `electronic_wreck`
  - `water_source`
  - `medical_cache`
- garde `requires_proximity=false` par défaut ;
- reste relançable via `ON CONFLICT`.

Adaptation volontaire aux skills réellement supportées par le package :

- `scrap_field` -> `exploration`
- `electronic_wreck` -> `mechanics`
- `medical_cache` -> `medicine`

## 8. Package gr-gathering

Package créé :

- `server/Packages/gr-gathering`

Dépendances déclarées :

- `gr-core`
- `gr-database`
- `gr-characters`
- `gr-inventory`
- `gr-skills`

Bridge exporté :

- `GRGatheringBridge.GetService()`
- `GRGatheringBridge.ListNodes(callback)`
- `GRGatheringBridge.GetNodeInfo(node_key, callback)`
- `GRGatheringBridge.Gather(character_id, player, node_key, callback)`

## 9. Commandes /gathernodes /gatherinfo /gather

Commandes ajoutées :

- `/gathernodes`
- `/gatherinfo <node_key>`
- `/gather <node_key>`

Protection debug :

- `gr_gathering_debug_commands_enabled`
- `gr_gathering_debug_allowed_platform_ids`

`gr-chat` autorise maintenant uniquement :

- `gathernodes`
- `gatherinfo`
- `gather`

## 10. Intégration inventaire

La récolte ajoute litem via :

- `GRInventoryBridge.AddItem(character_id, result_item_key, quantity, metadata_json, callback)`

Metadata injectée :

```json
{"source":"gathering","node_key":"<node_key>"}
```

Si lécriture du cooldown échoue après ajout inventaire, le service tente une compensation via :

- `GRInventoryBridge.RemoveItem(...)`

## 11. Intégration XP compétences

Si `required_skill_key` est configuré et `skill_xp > 0`, le service tente :

- `GRSkillsBridge.AddSkillXp(character_id, skill_key, skill_xp, "gather:<node_key>", callback)`

Si le bridge skills est absent ou si lXP échoue :

- la récolte reste réussie ;
- un warning serveur est loggé ;
- le message joueur ne prétend pas que lXP a été accordée.

## 12. Cooldown récolte

Le cooldown est stocké dans :

- `character_gathering_cooldowns`

Règles appliquées :

- lecture du dernier `last_gathered_epoch` ;
- calcul serveur du `remaining_seconds` ;
- refus si cooldown encore actif ;
- `UpsertCooldown(...)` seulement après ajout inventaire réussi ;
- rollback inventaire tenté si la mise à jour du cooldown échoue.

## 13. Tests PostgreSQL effectués

Exécutés :

```powershell
Get-Content -Raw ".\database\migrations\024_gathering_foundation.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
Get-Content -Raw ".\database\seeds\gathering_mvp_seed.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, name, node_type, result_item_key, min_quantity, max_quantity, required_skill_key, skill_xp, cooldown_seconds, requires_proximity, is_active FROM gathering_nodes ORDER BY key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, node_key, last_gathered_at, gather_count FROM character_gathering_cooldowns ORDER BY character_id, node_key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, item_key, quantity, metadata_json FROM inventory_items ORDER BY character_id, item_key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, skill_key, level, current_xp, total_xp FROM character_skills ORDER BY character_id, skill_key;"
```

Constats :

- migration `024` appliquée ;
- seed gathering appliqué ;
- `gathering_nodes` contient `4` nodes ;
- `character_gathering_cooldowns` est vide avant runtime ;
- `inventory_items` reste lisible ;
- `character_skills` reste lisible.

## 14. Tests runtime effectués ou restants

Runtime non exécuté dans ce lot.

Restent à faire :

```txt
/gathernodes
/gatherinfo scrap_field
/gather scrap_field
/inv
/skills
/xpinfo
/gather scrap_field
```

Résultats attendus :

- liste des nodes OK ;
- info node OK ;
- première récolte ajoute item ;
- XP skill ajoutée si bridge disponible ;
- deuxième récolte immédiate refuse cooldown ;
- pas de `chat-command-not-supported`.

## 15. Risques restants

- pas de test runtime nanos world exécuté ici ;
- pas d’atomicité SQL complète entre ajout inventaire et écriture cooldown ;
- compensation inventaire prévue en cas d’échec cooldown, à confirmer en runtime ;
- les nodes `scrap_field` et `electronic_wreck` utilisent des skills existantes (`exploration`, `mechanics`) et non les clés d’exemple du prompt, car `scavenging` / `engineering` ne sont pas des clés valides dans `SkillsConfig.lua`.

## 16. Résultat git status -sb

```txt
## feature/issue-118-gathering-foundation
 M server/Packages/gr-chat/Server/Index.lua
?? database/migrations/024_gathering_foundation.sql
?? database/seeds/gathering_mvp_seed.sql
?? docs/codex-reports/issue-118-gathering-foundation-report.md
?? server/Packages/gr-gathering/
```

## 17. Message de commit recommandé

```txt
feat(gathering): add resource gathering foundation
```

## Documentation nanos world consultée

Avant modification Lua/package :

- `external/nanos-world-docs/docs/core-concepts/packages/packages-guide.md`
- `external/nanos-world-docs/docs/core-concepts/scripting/communicating-between-packages.md`
- `docs/nanos-world-reference.md`
