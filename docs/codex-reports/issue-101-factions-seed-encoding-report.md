# Issue #101  Factions seed encoding

## 1. Resume de la correction

Correction ciblee du seed `database/seeds/factions_mvp_seed.sql` pour remplacer les libelles mal encodes par des chaines UTF-8 lisibles.

Le scope est reste strict :

- aucune nouvelle table
- aucune migration
- aucune modification Lua
- aucune modification de logique metier

Le seed corrige aussi les variantes historiques corrompues deja presentes en base afin de rester relancable.

## 2. Agents consultes

- database-engineer
- qa-tester
- security-reviewer
- software-architect

## 3. Fichiers modifies

- `database/seeds/factions_mvp_seed.sql`
- `docs/codex-reports/issue-101-factions-seed-encoding-report.md`

## 4. Fichiers explicitement non modifies

- `server/Packages/`
- `database/migrations/`
- vrai `Config.toml`

## 5. Problemes dencodage corriges

Chaines corrigees dans le seed :

- `AutoritÃ© Galactique` -> `Autorité Galactique`
- `NÃ©gociant` -> `Négociant`
- `MaÃ®tre de Guilde` -> `Maître de Guilde`

Les types techniques et la structure SQL ont ete conserves :

- `government`
- `military`
- `merchant`
- `criminal`

Ajout minimal pour garder le seed relancable :

- normalisation des noms existants par `type`
- normalisation des rangs existants par `type` et `level`
- suppression des doublons de factions deja corrompus pour un meme `type`, en conservant la ligne canonique

## 6. Seed PostgreSQL applique ou non

Seed applique localement sur PostgreSQL :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -v ON_ERROR_STOP=1 -f /workspace/database/seeds/factions_mvp_seed.sql
```

## 7. Requetes PostgreSQL de verification

Verification des factions :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT id, name, type, description, is_whitelisted FROM factions ORDER BY id;"
```

Verification des rangs :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT fr.id, f.name AS faction_name, fr.name AS rank_name, fr.level FROM faction_ranks fr INNER JOIN factions f ON f.id = fr.faction_id ORDER BY f.name, fr.level;"
```

Verification UTF-8 brute :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT name, encode(convert_to(name, 'UTF8'), 'hex') AS utf8_hex FROM factions WHERE type = 'government';"
```

## 8. Tests effectues

Tests realises :

1. verification branche et prerequis du ticket `#101`
2. lecture de :
   - `docs/runtime-rpg-validation.md`
   - `docs/codex-reports/issue-100-runtime-rpg-validation-report.md`
   - `database/seeds/factions_mvp_seed.sql`
   - `database/migrations/002_factions_foundation.sql`
3. correction des chaines mal encodees
4. reapplication du seed PostgreSQL local
5. verification SQL sur `factions` et `faction_ranks`
6. verification hex UTF-8 sur la valeur `Autorité Galactique`
7. controles git :
   - `git status -sb`
   - `git status --short --untracked-files=all`
   - `git diff --name-only`
   - `git diff --check`

## 9. Tests runtime restants

Restent a faire manuellement si necessaire :

- relancer la checklist runtime locale pour revalider l'affichage des labels factions en jeu
- verifier les affichages texte relies aux factions si une commande ou un profil les expose

## 10. Resultat git status -sb

Le resultat final a ete releve apres correction du seed et redaction du rapport.

## 11. Risques restants

- seules les chaines corrompues visibles dans le seed factions ont ete corrigees
- si d'autres fichiers du depot ont ete saisis avec le meme mauvais encodage, ils devront etre traites dans des tickets distincts
- la validation runtime nanos world complete n'est pas relancee dans ce lot

## 12. Message de commit recommande

```text
fix(seeds): normalize factions seed encoding
```
