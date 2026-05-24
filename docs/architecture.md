# Architecture Galactic RP

## Objectif

Ce document decrit le bootstrap MVP Tech de Galactic RP. Son perimetre couvre l'architecture du monorepo, l'infrastructure locale, la base de donnees minimale, la documentation et la CI. Il ne couvre pas encore l'implementation du gameplay, de la progression, du craft, de l'inventaire, des quetes ou d'un HUD complet.

## Principes

- Monorepo unique pour versionner ensemble serveur, UI, SQL, Docker, CI et documentation.
- Modular monolith cote nanos world avec separation stricte des responsabilites `Server/`, `Client/` et `Shared/` par package.
- Logique sensible et ecritures persistantes cote serveur uniquement.
- MVP-first : poser un socle simple, testable et maintenable avant d'ajouter les systemes RPG.
- Documentation versionnee et alignee avec l'etat reel du depot.

## Lecture du perimetre MVP

Deux niveaux doivent etre distingues :

- l'architecture cible du produit, qui prevoit plusieurs packages nanos world specialises
- l'etat actuel du bootstrap MVP Tech, qui pose uniquement les fondations repo, Docker, PostgreSQL, SQL et CI

Concretement, ce lot documente la direction technique et l'ossature du projet. Les packages Lua `gr_core`, `gr_database` et `gr_characters` sont initialises comme socles techniques minimaux, tandis que les applications React finales et les autres packages gameplay restent a creer.

## Arborescence cible

```txt
galactic-rp/
  docs/
  server/
    Packages/
  ui/
    hud/
    datapad/
  database/
    migrations/
    seeds/
  docker/
  tools/
  .github/
    ISSUE_TEMPLATE/
    workflows/
```

## Domaines techniques

### Serveur nanos world

Le dossier `server/Packages/` hebergera progressivement les packages Lua du modular monolith. Les packages principaux cibles sont :

- `gr_core`
- `gr_database`
- `gr_characters`
- `gr_progression`
- `gr_skills`
- `gr_inventory`
- `gr_crafting`
- `gr_quests`
- `gr_factions`
- `gr_reputation`
- `gr_contracts`
- `gr_chat`
- `gr_voip`
- `gr_admin`
- `gr_hud`
- `gr_datapad`

Chaque package doit respecter la meme frontiere technique :

- `Server/` : logique autoritative, validation, permissions, persistance, orchestration.
- `Client/` : presentation, interactions locales, affichage et montage des WebUI.
- `Shared/` : constantes, structures simples et evenements partages.

Un package strictement serveur peut omettre `Client/` si cela renforce la securite et evite toute ambiguite de responsabilite. `gr_database` suit explicitement cette approche.

Regles de responsabilite :

- `gr_core` porte les conventions communes et les contrats transverses.
- `gr_database` encapsule l'acces PostgreSQL cote serveur.
- `gr_characters` portera le cycle de vie personnage cote serveur : chargement, creation, selection active et persistance de position.
- les packages gameplay consomment des services serveur internes plutot que des mutations directes depuis le client.
- `gr_hud` et `gr_datapad` sont des points d'integration UI et ne doivent pas contenir de logique metier autoritative.

Etat initial de `gr_core` :

- `Package.toml` declare un package nanos world de type script avec configuration minimale.
- `Shared/Index.lua` centralise des constantes non sensibles communes : nom du projet, version MVP et prefixe d'evenements.
- `Server/Index.lua` se limite a un log de chargement explicite cote serveur.
- `Client/Index.lua` se limite a un log de chargement explicite cote client.
- aucun systeme gameplay, personnage, progression, inventaire, craft, quete ou HUD n'est initialise dans `gr_core`.

Etat initial de `gr_database` :

- `Package.toml` declare un package nanos world de type script avec configuration minimale.
- `Server/DatabaseConfig.lua` normalise une configuration PostgreSQL de bootstrap sans mot de passe embarque.
- `Server/DatabaseService.lua` prepare un service de connexion minimal strictement cote serveur.
- `Server/Index.lua` charge le package, journalise l'etat et n'ouvre aucune connexion automatiquement.
- `Shared/Index.lua` ne contient que des constantes de package, sans logique sensible ni dependance client.
- `Client/` est volontairement absent pour eviter toute ambiguite sur la frontiere server-only du package.
- aucune requete metier, repository gameplay ou acces base cote client n'est initialise dans `gr_database`.

Etat initial de `gr_characters` :

- `Package.toml` declare un package nanos world de type script avec configuration minimale.
- `Package.toml` declare maintenant `gr_database` comme dependance de package pour le chargement serveur des lignes `players`.
- `Server/CharacterPlayerRepository.lua` prepare la lecture server-only de la table `players` via `players.platform_id`.
- `Server/CharacterPlayerService.lua` prepare la resolution de l'identifiant stable nanos world, le chargement asynchrone d'une ligne `players` existante et l'etat memoire si la ligne manque encore.
- `Server/CharacterRepository.lua` prepare les points d'entree futurs pour charger les personnages d'un joueur, creer un personnage, selectionner le personnage actif et sauvegarder la position, sans executer encore de requete metier.
- `Server/CharacterService.lua` prepare l'orchestration serveur de ces flux avec validations minimales de forme et memoire transitoire de personnage actif.
- `Server/Index.lua` charge le package, instancie les services serveur, s'abonne au cycle `Player.Subscribe("Spawn")` et prepare le chargement de session joueur depuis `players`.
- `Shared/Index.lua` limite le partage a des constantes et noms d'evenements non sensibles.
- `Client/Index.lua` se limite a un log de chargement et rappelle qu'aucune logique autoritative personnage n'est exposee cote client.
- aucune creation complete de personnage, selection finale, spawn de personnage actif, sauvegarde de position persistante ou UI de datapad n'est encore implementee dans ce lot.

### WebUI

Les interfaces `ui/hud/` et `ui/datapad/` sont separees des maintenant pour eviter de coupler les futures applications React. Elles partageront plus tard une convention commune de build et de synchronisation vers les packages nanos world, mais restent independantes fonctionnellement.

Le client a un role d'affichage et d'interaction, pas un role d'autorite. Les WebUI et scripts client ne doivent jamais attribuer directement :

- XP, niveaux ou progression
- argent, recompenses, items ou recettes
- reputation, permissions, grades ou sanctions
- validation de quetes, contrats ou actions admin

Toute demande du client doit passer par une validation cote serveur, avec controles de regles, permissions et persistance. Cela garantit une architecture server-authoritative et evite tout gameplay sensible cote client.

### Base de donnees

Le dossier `database/migrations/` contient les migrations SQL versionnees. Le bootstrap pose trois tables minimales :

- `players`
- `characters`
- `character_skills`

Le schema initial couvre la persistance de base sans encore modeliser l'inventaire, le craft, les quetes, les factions, la reputation ou les contrats.

`gr_characters` est prepare pour consommer ulterieurement ces tables via `gr_database`, mais aucun acces metier a la base n'est encore active dans son scaffold initial.

Le package `gr_database` est le point d'entree technique prevu pour la future integration PostgreSQL dans nanos world. Sa responsabilite est de centraliser :

- la lecture et la normalisation de configuration
- la creation controlee de la connexion via la classe `Database` cote serveur
- les futurs services transverses de persistance consommes par les autres packages

Par conception, `gr_database` ne doit pas exposer de credentials, de handle de connexion ou de logique de requetage sensible au client.

### Infrastructure locale

Le dossier `docker/` contient un `docker-compose.yml` pour lancer l'infrastructure locale MVP :

- PostgreSQL pour la persistance locale
- pgAdmin pour l'inspection manuelle
- des volumes persistants pour les donnees

Le choix PostgreSQL est acte des le MVP Tech pour eviter une migration prematuree depuis SQLite. Le fichier `docker/.env.example` sert uniquement au developpement local et aucun secret reel ne doit etre versionne.

### CI/CD

La CI minimale GitHub Actions, definie dans `.github/workflows/ci.yml`, verifie :

- la presence de l'arborescence attendue
- la presence d'au moins une migration SQL
- l'absence de secrets evidents
- l'empaquetage de `server/`, `database/` et `docs/` en artefact

Cette CI est coherente avec une approche MVP-first : elle valide l'hygiene du socle sans pretendre faire un pipeline produit complet tant que les packages nanos world et les applications UI ne sont pas initialises.

## Flux de travail technique

1. Creer une branche `feature/*` ou `fix/*`.
2. Documenter la tache via issue GitHub.
3. Ajouter ou modifier code, SQL et docs dans le monorepo.
4. Laisser la CI valider structure, migrations et hygiene de depot.
5. Relire via Pull Request avant integration vers `develop`.

## Decisions du bootstrap

- Pas de `.env` reel versionne.
- Pas de gameplay implemente dans ce lot.
- Initialisation minimale de `gr_core` autorisee pour poser les conventions communes sans ajouter de logique metier.
- Initialisation minimale de `gr_database` autorisee pour preparer la couche PostgreSQL sans connexion automatique ni requete metier.
- Pas de dependance Node ajoutee tant que les applications UI n'ont pas leur cahier d'initialisation detaille.
- Base PostgreSQL retenue des le depart pour eviter une migration de persistance precoce.

## Garanties d'architecture

Le bootstrap MVP Tech est considere coherent si les regles suivantes restent vraies :

- l'architecture nanos world reste modulaire et separee par domaine
- chaque package preserve une separation explicite entre code serveur, client et partage, avec possibilite d'omettre `Client/` pour un package strictement serveur
- PostgreSQL est execute localement via Docker Compose
- GitHub Actions controle au moins la structure, les migrations et l'hygiene de depot
- la logique sensible reste server-authoritative
- `gr_database` concentre toute logique de connexion et de persistance sensible cote serveur
- le client n'accorde jamais directement d'avantage gameplay ou de pouvoir d'administration

Toute evolution future devra preserver ces contraintes avant d'ajouter des systemes RPG plus riches.

## Prochaines etapes recommandees

- Implementer le chargement metier des personnages via `gr_database`.
- Implementer la creation et la selection de personnage avec validations serveur.
- Scaffold des applications React `ui/hud` et `ui/datapad`.
- Ajouter une strategie de seeds de developpement.
- Etendre la CI avec build UI et validation SQL plus poussee une fois les applications creees.
