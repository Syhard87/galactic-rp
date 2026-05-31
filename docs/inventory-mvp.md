# Inventory MVP

## Objectif

Documenter l'etat actuel du package `gr-inventory`, les commandes temporaires exposees en runtime nanos world et la facon de les tester sans ambiguite.

Cette doc couvre uniquement le MVP inventaire serveur :

- chargement de l'inventaire du personnage actif
- ajout d'objet via une commande temporaire staff/dev
- retrait d'objet
- consommation simple d'objet
- persistance PostgreSQL

Cette doc ne couvre pas :

- WebUI inventaire
- drag and drop
- poids maximal
- coffre
- commerce
- craft
- objets physiques au sol

## Package concerne

Package serveur principal :

- `server/Packages/gr-inventory/`

Dependances runtime :

- `gr-database`
- `gr-characters`

Interaction chat :

- `gr-inventory` intercepte ses commandes temporaires via `Chat.Subscribe("PlayerSubmit", ...)`
- `gr-chat` conserve le chat local RP, `/me` et `/do`
- l'allowlist externe de `gr-chat` doit laisser passer les commandes inventory temporaires pour eviter `chat-command-not-supported`

## Commandes temporaires

Commandes actuellement exposees :

- `/inv`
- `/dropitem <item_key> <quantity>`
- `/useitem <item_key>`
- `/giveitem <item_key> <quantity>`

## Commandes joueur

### `/inv`

Accessible joueur.

Role :

- liste l'inventaire du personnage actif

Si l'inventaire est vide :

```txt
Inventaire vide.
```

Si l'inventaire contient des objets :

```txt
Inventaire :
- Medikit basique x2
```

Si aucun personnage actif n'est resolu :

```txt
Aucun personnage actif.
```

### `/dropitem <item_key> <quantity>`

Accessible joueur.

Role :

- retire ou jette une quantite d'objet de l'inventaire
- ne cree pas encore d'objet physique au sol

Exemple :

```txt
/dropitem medkit_basic 1
```

Messages attendus :

- usage invalide :

```txt
Usage : /dropitem <item_key> <quantity>
```

- aucun personnage actif :

```txt
Aucun personnage actif.
```

- quantite insuffisante :

```txt
Quantite insuffisante.
```

- succes :

```txt
Objet retire : medkit_basic x1
```

### `/useitem <item_key>`

Accessible joueur.

Role :

- utilise un objet de l'inventaire
- pour le MVP, seul `medkit_basic` a un effet concret
- l'effet concret actuel est uniquement la consommation de l'objet
- aucun systeme medical avance n'est ajoute dans ce lot

Exemple :

```txt
/useitem medkit_basic
```

Messages attendus :

- usage invalide :

```txt
Usage : /useitem <item_key>
```

- objet non utilisable :

```txt
Objet non utilisable.
```

- objet absent ou quantite insuffisante :

```txt
Objet indisponible.
```

- succes :

```txt
Objet utilise : medkit_basic
```

## Commande staff/dev

### `/giveitem <item_key> <quantity>`

Reservee staff/dev.

Role :

- ajoute un objet a l'inventaire du personnage actif
- sert au smoke test runtime et au debug local

Exemple :

```txt
/giveitem medkit_basic 2
```

Messages attendus :

- joueur non autorise :

```txt
Commande reservee au staff/dev.
```

- usage invalide :

```txt
Usage : /giveitem <item_key> <quantity>
```

- objet inconnu :

```txt
Objet inconnu.
```

- succes :

```txt
Objet ajoute : medkit_basic x2
```

## Configuration locale pour /giveitem

`/giveitem` doit etre refuse par defaut.

Pour l'autoriser localement, ajouter dans le vrai `Config.toml` du serveur nanos world local, sous `[custom_settings]` :

```toml
[custom_settings]
gr_inventory_debug_commands_enabled = "true"
gr_inventory_debug_allowed_platform_ids = "platform_id_1,platform_id_2"
```

Regles importantes :

- ne jamais commiter un vrai `platform_id` personnel
- ne jamais commiter de secret dans le repo
- utiliser le `platform_id` observe dans les logs runtime locaux
- garder cette configuration uniquement pour le developpement local
- si la config est absente, invalide ou incomplete, `/giveitem` reste refuse proprement

## Tests runtime nanos world

Scenario recommande :

```txt
/inv
/giveitem medkit_basic 2
/inv
/useitem medkit_basic
/inv
/dropitem medkit_basic 1
/inv
/giveitem medkit_basic 1
/dropitem medkit_basic 5
/whoami
/f test
/me test
/do test
test local
```

Resultats attendus :

- `/inv` affiche l'inventaire du personnage actif
- `/giveitem` est refuse sans autorisation locale explicite
- `/giveitem` fonctionne si `gr_inventory_debug_commands_enabled = "true"` et que le `platform_id` est allowliste
- `/useitem medkit_basic` consomme un medikit
- `/dropitem` decremente ou supprime l'objet
- `/dropitem` refuse les quantites insuffisantes
- `/whoami` fonctionne toujours
- `/f` fonctionne toujours
- `/me` fonctionne toujours
- `/do` fonctionne toujours
- le chat local fonctionne toujours
- aucun `chat-command-not-supported` ne doit apparaitre pour les commandes inventory

Scenario detaille de verification quantites :

```txt
/giveitem medkit_basic 2
/inv
/useitem medkit_basic
/inv
/dropitem medkit_basic 1
/inv
```

Attendu :

1. apres `/giveitem medkit_basic 2` :

```txt
Inventaire :
- Medikit basique x2
```

2. apres `/useitem medkit_basic` :

```txt
Inventaire :
- Medikit basique x1
```

3. apres `/dropitem medkit_basic 1` :

```txt
Inventaire vide.
```

## Verifications PostgreSQL

Verifier le catalogue des items :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT key, name, is_stackable FROM items ORDER BY key;"
```

Verifier l'inventaire persiste :

```powershell
docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT character_id, item_key, quantity, metadata_json FROM inventory_items ORDER BY character_id, item_key;"
```

Lecture attendue :

- apres `/giveitem`, la ligne `inventory_items` du personnage actif doit etre creee ou incremente
- apres `/useitem`, la quantite doit diminuer
- apres `/dropitem`, la quantite doit diminuer puis la ligne doit disparaitre si elle tombe a `0`

## Non-regression chat

Verifier explicitement :

```txt
/whoami
/f test
/me test
/do test
test local
```

Attendu :

- `/whoami` repond sans message parasite
- `/f` diffuse toujours le chat de faction
- `/me` fonctionne toujours en local RP
- `/do` fonctionne toujours en local RP
- le message local standard fonctionne toujours

## Limites actuelles

Limites connues du MVP inventaire :

- aucune WebUI inventaire
- aucun drag and drop
- aucune notion de poids maximal
- aucun objet physique au sol pour `/dropitem`
- aucun systeme medical avance pour `/useitem`
- seul `medkit_basic` est actuellement utilisable
- `/giveitem` est une commande temporaire de debug et ne remplace pas un vrai outillage admin
- aucune gestion fine des permissions staff hors allowlist locale de dev

## Prochaines evolutions

Evolutions recommandees apres ce MVP :

- WebUI inventaire cote client avec validation serveur
- donne d'objet entre joueurs
- objets physiques au sol pour les drops
- usage metier reel des objets consommables
- outillage admin dedie au lieu des commandes debug
- controles de poids ou de slots
- metadata gameplay plus riche par objet
- journalisation serveur plus detaillee des usages sensibles

## Fichiers hors scope

Dans ce lot de documentation, ne pas modifier :

- `server/Packages/gr-database/`
- `server/Packages/gr-characters/`
- `server/Packages/gr-factions/`
- `database/migrations/`
- `database/seeds/`
- le vrai `Config.toml` local
