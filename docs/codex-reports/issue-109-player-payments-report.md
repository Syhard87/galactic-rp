# Issue #109  Player payments

## 1. Resume de l'implementation

Ajout de la commande serveur `/pay <target_character_id> <wallet> <amount> [reason]` dans `gr-economy`.
Le flux passe par `GREconomyBridge.TransferMoney(...)`, reste server-authoritative, reutilise la validation de `EconomyService`, et s'appuie sur `bank_transactions` pour la journalisation.

## 2. Agents consultes

- `software-architect`
- `backend-lua`
- `security-reviewer`
- `qa-tester`
- `nanos-world-lua-agent`

Documentation nanos world consultee avant modification Lua :
- `external/nanos-world-docs/docs/core-concepts/packages/packages-guide.md`
- `external/nanos-world-docs/docs/core-concepts/scripting/communicating-between-packages.md`

## 3. Fichiers crees

- `docs/codex-reports/issue-109-player-payments-report.md`

## 4. Fichiers modifies

- `server/Packages/gr-economy/Server/Index.lua`
- `server/Packages/gr-economy/Server/EconomyService.lua`
- `server/Packages/gr-chat/Server/Index.lua`

## 5. Fichiers explicitement non modifies

- `server/Packages/gr-contracts/`
- `server/Packages/gr-economy/Server/EconomyRepository.lua`
- `server/Packages/gr-characters/`
- `database/migrations/`
- `database/seeds/`
- vrai `Config.toml`

## 6. Commande /pay

Commande ajoutee :

```txt
/pay <target_character_id> <wallet> <amount> [reason]
```

Comportement :
- recupere le personnage actif du joueur emetteur
- valide la cible
- interdit l'auto-paiement
- valide `wallet` (`cash` ou `bank`)
- valide `amount` (`> 0` et `<= 100000`)
- appelle `GREconomyBridge.TransferMoney(...)`

Messages geres :
- `Paiement effectue : 50 cash vers personnage #4.`
- `Paiement impossible : personnage actif introuvable.`
- `Paiement impossible : cible invalide.`
- `Paiement impossible : vous ne pouvez pas vous payer vous-meme.`
- `Paiement impossible : wallet invalide.`
- `Paiement impossible : montant invalide.`
- `Paiement impossible : solde insuffisant.`
- `Paiement impossible : economie indisponible.`

## 7. Integration GREconomyBridge

Le point d'entree joueur `/pay` ne touche pas directement aux soldes.
Il delegue a :

```lua
GREconomyBridge.TransferMoney(from_character_id, to_character_id, wallet, amount, reason, callback)
```

Le service economie reste le point central pour :
- le debit
- le credit
- les verifications de solde
- les transactions `transfer_out` / `transfer_in`

## 8. Securite serveur

- le client ne choisit jamais son solde final
- la source est toujours le personnage actif resolve cote serveur
- la cible doit etre un `character_id` positif
- l'auto-paiement est refuse
- `wallet` est borne a `cash` ou `bank`
- `amount` doit etre entier, strictement positif, et borne a `100000` au niveau commande
- `EconomyService.TransferMoney(...)` garde aussi ses propres validations
- prevalidation ajoutee sur l'existence de la cible avant debit pour eviter un debit source si la cible n'existe pas

## 9. Tests PostgreSQL effectues

Commandes executees :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, first_name, last_name, money_cash, money_bank FROM characters ORDER BY id;"
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, character_id, target_character_id, amount, currency, wallet, type, reason, created_at FROM bank_transactions ORDER BY id DESC LIMIT 20;"
```

Constat :
- les soldes personnages sont lisibles
- `bank_transactions` est accessible
- aucune nouvelle migration n'etait necessaire pour ce lot

## 10. Tests runtime effectues ou restants

Non executes dans ce lot.

Retest runtime a faire :

```txt
/money
/givemoney cash 200 test_pay_setup
/money
/pay 4 cash 50 test_pay
/money
/transactions
/profile
```

Cas d'erreur a rejouer :

```txt
/pay 3 cash 50 self_test
/pay 4 cash -10 bad_amount
/pay 4 fake 10 bad_wallet
/pay 999 cash 10 bad_target
```

## 11. Risques restants

- `TransferMoney` n'est pas transactionnel SQL de bout en bout
- si le debit source reussit puis que le credit ou l'ecriture transaction echoue, il n'y a pas encore de rollback applicatif
- la compatibilite runtime nanos world de `/pay` reste a confirmer en jeu

## 12. Resultat git status -sb

```txt
## feature/issue-109-player-payments
 M server/Packages/gr-chat/Server/Index.lua
 M server/Packages/gr-economy/Server/EconomyService.lua
 M server/Packages/gr-economy/Server/Index.lua
?? docs/codex-reports/issue-109-player-payments-report.md
```

## 13. Message de commit recommande

```txt
feat(economy): add player payments
```
