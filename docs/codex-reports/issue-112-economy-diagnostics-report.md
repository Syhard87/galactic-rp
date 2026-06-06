# Issue #112  Economy diagnostics and audit tools

## 1. Résumé de limplémentation

Ajout de commandes de diagnostic économie côté serveur dans `gr-economy` :

- `/economybalance <character_id>`
- `/economytransactions <character_id> [limit]`
- `/economysalary <character_id>`
- `/economyhealth`

Le lot reste strictement en lecture. Aucune nouvelle mécanique économique majeure ni migration SQL n'a été ajoutée.

## 2. Agents consultés

- `software-architect`
- `backend-lua`
- `database-engineer`
- `security-reviewer`
- `qa-tester`
- `nanos-world-lua-agent`

Documentation nanos world relue avant modification Lua :

- `external/nanos-world-docs/docs/core-concepts/packages/packages-guide.md`
- `external/nanos-world-docs/docs/core-concepts/scripting/communicating-between-packages.md`

Référence projet relue :

- `docs/cahier-des-charges.md`

## 3. Fichiers créés

- `docs/codex-reports/issue-112-economy-diagnostics-report.md`

## 4. Fichiers modifiés

- `server/Packages/gr-economy/Server/EconomyRepository.lua`
- `server/Packages/gr-economy/Server/EconomyService.lua`
- `server/Packages/gr-economy/Server/Index.lua`
- `server/Packages/gr-chat/Server/Index.lua`

## 5. Fichiers explicitement non modifiés

- `server/Packages/gr-contracts/`
- `server/Packages/gr-crafting/`
- `server/Packages/gr-quests/`
- `server/Packages/gr-reputation/`
- `database/migrations/`
- `database/seeds/`
- `Config.toml` réel

## 6. Commandes diagnostic ajoutées

### `/economybalance <character_id>`

Affiche le snapshot `cash/bank` d'un personnage cible.

### `/economytransactions <character_id> [limit]`

Affiche les dernières transactions liées au personnage cible.

- limite par défaut : `10`
- limite maximale : `25`
- `reason` tronquée pour rester lisible en chat

### `/economysalary <character_id>`

Affiche :

- la règle de salaire applicable
- le wallet
- le montant
- le cooldown restant en secondes

### `/economyhealth`

Affiche un résumé lecture seule :

- nombre de personnages
- nombre de transactions
- nombre de règles de salaire

## 7. Sécurité debug

Toutes les commandes diagnostics réutilisent les protections debug économie existantes :

- `gr_economy_debug_commands_enabled`
- `gr_economy_debug_allowed_platform_ids`

Comportement ajouté :

- message dédié `Diagnostic economie desactive.` pour les commandes de diagnostic
- aucune écriture DB dans ces commandes
- aucune exposition hors allowlist `gr-chat`

## 8. Requêtes de lecture ajoutées

Ajouts principaux dans `EconomyRepository.lua` :

- `GetCharacterEconomySnapshot(character_id, callback)`
- `ListTransactionsForCharacter(character_id, limit, callback)`
- `GetSalaryStatusForCharacter(character_id, callback)`
- `GetEconomyHealth(callback)`

Ajouts principaux dans `EconomyService.lua` :

- `GetBalanceDiagnostic(character_id, callback)`
- `ListTransactionsDiagnostic(character_id, limit, callback)`
- `GetSalaryDiagnostic(character_id, callback)`
- `GetEconomyHealth(callback)`

## 9. Tests PostgreSQL effectués

Exécutés :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, first_name, last_name, money_cash, money_bank FROM characters ORDER BY id;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, character_id, target_character_id, amount, currency, wallet, type, reason, created_at FROM bank_transactions ORDER BY id DESC LIMIT 20;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, key, label, faction_id, faction_key, wallet, amount, cooldown_seconds, is_active FROM economy_salary_rules ORDER BY id;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, salary_rule_id, last_claimed_at, claim_count FROM character_salary_claims ORDER BY character_id, salary_rule_id;"
```

Résultats observés :

- `characters` lisible, `money_cash` et `money_bank` présents
- `bank_transactions` accessible, actuellement vide
- `economy_salary_rules` accessible, `5` règles présentes
- `character_salary_claims` accessible, actuellement vide

## 10. Tests runtime effectués ou restants

Runtime nanos world non exécuté dans ce lot.

Checklist restante :

```txt
/economyhealth
/economybalance 3
/economytransactions 3 10
/economysalary 3

/money
/transactions
/salaryrules
/claimsalary
/economysalary 3
```

Vérifications attendues :

- diagnostics lisibles
- aucune modification de solde via diagnostics
- commandes protégées par les settings debug
- pas de `chat-command-not-supported`

## 11. Risques restants

- `economytransactions` sur un `character_id` inexistant renverra actuellement une liste vide plutôt qu'un message explicite `Personnage introuvable.`
- la compatibilité runtime nanos world reste à confirmer en jeu
- `git diff --check` peut encore remonter des warnings CRLF Windows selon l'état local

## 12. Résultat git status -sb

Résultat attendu après ce lot :

```txt
## feature/issue-112-economy-diagnostics
 M server/Packages/gr-chat/Server/Index.lua
 M server/Packages/gr-economy/Server/EconomyRepository.lua
 M server/Packages/gr-economy/Server/EconomyService.lua
 M server/Packages/gr-economy/Server/Index.lua
?? docs/codex-reports/issue-112-economy-diagnostics-report.md
```

## 13. Message de commit recommandé

```txt
feat(economy): add economy diagnostics
```
