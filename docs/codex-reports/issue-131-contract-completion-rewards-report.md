# Issue #131  Contract completion rewards MVP

## 1. Résumé de limplémentation

Le lot ajoute des récompenses RPG de complétion côté serveur dans `gr-contracts`.

Les contrats peuvent désormais stocker :

- une récompense de skill ;
- une récompense de réputation ;
- un état d'attribution ;
- une trace d'erreur en cas d'échec ;
- une date d'attribution.

La logique reste server-authoritative. Le client ne choisit jamais les rewards.

Documentation lue avant modification :

- `docs/cahier-des-charges.md`
- `external/nanos-world-docs/docs/core-concepts/packages/packages-guide.md`
- `external/nanos-world-docs/docs/core-concepts/scripting/communicating-between-packages.md`

## 2. Agents consultés

- `software-architect`
- `backend-lua`
- `database-engineer`
- `security-reviewer`
- `qa-tester`
- `nanos-world-lua-agent`

## 3. Fichiers créés

- `database/migrations/036_contract_completion_rewards.sql`
- `docs/codex-reports/issue-131-contract-completion-rewards-report.md`

## 4. Fichiers modifiés

- `database/seeds/contract_route_templates_mvp_seed.sql`
- `server/Packages/gr-contracts/Server/ContractRepository.lua`
- `server/Packages/gr-contracts/Server/ContractService.lua`
- `server/Packages/gr-contracts/Server/Index.lua`
- `server/Packages/gr-chat/Server/Index.lua`

## 5. Fichiers explicitement non modifiés

- `server/Packages/gr-inventory/`
- `server/Packages/gr-economy/`
- `server/Packages/gr-gathering/`
- `server/Packages/gr-shops/`
- `Config.toml`

## 6. Migration SQL ajoutée

Migration ajoutée :

- `database/migrations/036_contract_completion_rewards.sql`

Ajouts côté `contracts` :

- `reward_skill_key`
- `reward_skill_xp`
- `reward_reputation_key`
- `reward_reputation_delta`
- `rewards_status`
- `rewards_granted_at`
- `rewards_error`

Ajouts côté `contract_route_templates` :

- `reward_skill_key`
- `reward_skill_xp`
- `reward_reputation_key`
- `reward_reputation_delta`

Index ajouté :

- `idx_contracts_rewards_status`

## 7. Seed route templates adapté

Fichier modifié :

- `database/seeds/contract_route_templates_mvp_seed.sql`

Choix effectué :

- la skill `transport` n'existe pas dans `gr-skills`
- le seed utilise donc `commerce`, déjà définie localement, pour représenter la logistique/les contrats
- la réputation reste volontairement non seedée dans ce MVP pour éviter une double attribution partielle au retry sans sous-état par type de reward

Routes seedées :

- `scrap_to_spatioport` => `commerce x50`
- `electronics_to_market` => `commerce x75`
- `medical_to_government` => `commerce x60`
- `water_to_industrial` => `commerce x40`

## 8. Récompenses de complétion

Statuts utilisés :

- `none`
- `pending`
- `granted`
- `failed`
- `not_required`

Règles appliquées :

- une route copie ses rewards dans le contrat à la création
- un contrat avec reward prévu démarre en `pending`
- un contrat sans reward démarre en `not_required`
- `GrantContractRewards(...)` refuse les contrats non `completed`
- pas de double attribution si `rewards_status = granted`
- si aucun reward n'est configuré : `rewards_status = not_required`
- si un bridge est indisponible ou qu'une attribution échoue : `rewards_status = failed` avec `rewards_error`
- si tout réussit : `rewards_status = granted` et `rewards_granted_at = NOW()`

## 9. Commandes /contractrewards et /grantcontractrewards

Commandes ajoutées :

- `/contractrewards <contract_id>`
- `/grantcontractrewards <contract_id>`

Protection MVP :

- commandes gardées derrière `gr_contracts_debug_commands_enabled`
- commandes gardées derrière `gr_contracts_debug_allowed_platform_ids`

Allowlist `gr-chat` étendue uniquement avec :

- `contractrewards`
- `grantcontractrewards`

## 10. Intégration skills/reputation

Bridges réutilisés :

- `GRSkillsBridge.AddSkillXp(character_id, skill_key, amount, reason, callback)`
- `GRReputationBridge.AddReputation(character_id, reputation_key, amount, reason, callback)`

Intégration réellement activée dans ce lot :

- skill XP : oui
- réputation : supportée côté code, mais non seedée par défaut sur les routes MVP

## 11. Impact /completecontract

`/completecontract` conserve le flux existant :

- validation pickup
- validation delivery
- retrait item
- complétion
- paiement

Après succès réel, le service tente désormais `GrantContractRewards(...)`.

Si l'attribution reward échoue :

- le contrat reste `completed`
- le paiement n'est pas rollback
- `rewards_status = failed`

## 12. Tests PostgreSQL effectués

Exécutés :

```powershell
Get-Content -Raw ".\database\migrations\036_contract_completion_rewards.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
Get-Content -Raw ".\database\seeds\contract_route_templates_mvp_seed.sql" | docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, item_key, item_quantity, reward_money, reward_skill_key, reward_skill_xp, reward_reputation_key, reward_reputation_delta, is_active FROM contract_route_templates ORDER BY key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, status, payment_status, assignee_character_id, reward_skill_key, reward_skill_xp, reward_reputation_key, reward_reputation_delta, rewards_status, rewards_granted_at, rewards_error FROM contracts ORDER BY id DESC LIMIT 20;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key FROM reputation_definitions ORDER BY key;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT column_name FROM information_schema.columns WHERE table_name = 'contracts' AND column_name IN ('reward_skill_key','reward_skill_xp','reward_reputation_key','reward_reputation_delta','rewards_status','rewards_granted_at','rewards_error') ORDER BY column_name;"
```

Constats :

- migration `036` appliquée
- les colonnes rewards existent sur `contracts`
- les routes seedées portent `reward_skill_key=commerce`
- `reward_reputation_key` est volontairement `NULL` dans le seed MVP
- les définitions réputation locales existent bien (`government`, `merchant_guild`, etc.)

## 13. Tests runtime effectués ou restants

Runtime non exécuté dans ce lot.

Restent à faire :

```txt
/jobboard
/takejob scrap_to_spatioport
/pickupcontract 1
/completecontract 1
/contractrewards 1

/grantcontractrewards 1
```

## 14. Risques restants

- pas de test runtime nanos world exécuté ici
- si une future route combine skill + réputation, un échec après attribution partielle reste un cas délicat sans sous-état séparé par type de reward
- aucun outillage local `luac`, `lua` ou `luajit` n'était disponible pour une validation syntaxique automatique
- `gr-skills` et `gr-reputation` sont intégrés via leurs bridges existants, sans refonte ni transaction croisée

## 15. Résultat git status -sb

```txt
## feature/issue-131-contract-completion-rewards
 M database/seeds/contract_route_templates_mvp_seed.sql
 M server/Packages/gr-chat/Server/Index.lua
 M server/Packages/gr-contracts/Server/ContractRepository.lua
 M server/Packages/gr-contracts/Server/ContractService.lua
 M server/Packages/gr-contracts/Server/Index.lua
?? database/migrations/036_contract_completion_rewards.sql
?? docs/codex-reports/issue-131-contract-completion-rewards-report.md
```

## 16. Message de commit recommandé

```txt
feat(contracts): add completion rewards
```
