# Architecture Galactic RP

## Objectif

Ce document décrit le bootstrap MVP Tech de Galactic RP. Le périmètre couvre l'architecture du monorepo, l'infrastructure locale, la base de données minimale, la documentation et la CI. Il ne couvre pas encore le gameplay, la progression, le craft, l'inventaire, les quêtes ou un HUD complet.

## Principes

- Architecture monorepo pour versionner ensemble code serveur, UI, SQL, Docker et documentation.
- Modular monolith côté nanos world avec séparation stricte `Server/`, `Client/` et `Shared/` par package.
- Logique sensible serveur uniquement.
- MVP-first : poser les fondations sans implémenter les systèmes RPG.
- Documentation versionnée et alignée avec le dépôt.

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

Le dossier `server/Packages/` hébergera progressivement les packages Lua du modular monolith :

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

Chaque package devra respecter les responsabilités suivantes :

- `Server/` : logique autoritative, persistance, validation.
- `Client/` : présentation, interactions locales, WebUI mounting.
- `Shared/` : constantes, types simples, événements partagés.

### WebUI

Les interfaces `ui/hud/` et `ui/datapad/` sont séparées dès maintenant pour éviter de coupler les futures applications React. Le HUD et le Datapad partageront plus tard une convention commune de build et de synchronisation vers les packages nanos world, mais restent indépendants fonctionnellement.

### Base de données

Le dossier `database/migrations/` contient les migrations SQL versionnées. Le bootstrap pose trois tables minimales :

- `players`
- `characters`
- `character_skills`

Le schéma initial couvre la persistance de base sans encore modéliser inventaire, craft, quêtes ou réputation.

### Infrastructure locale

Le dossier `docker/` contient un `docker-compose.yml` pour lancer :

- PostgreSQL pour la persistance locale
- pgAdmin pour l'inspection manuelle
- des volumes persistants pour les données

### CI/CD

La CI minimale GitHub Actions vérifie :

- la présence de l'arborescence attendue
- la présence d'au moins une migration SQL
- l'absence de secrets évidents
- l'empaquetage de `server/`, `database/` et `docs/` en artefact

## Flux de travail technique

1. Créer une branche `feature/*` ou `fix/*`.
2. Documenter la tâche via issue GitHub.
3. Ajouter ou modifier code, SQL et docs dans le monorepo.
4. Laisser la CI valider structure, migrations et hygiène de dépôt.
5. Relire via Pull Request avant intégration vers `develop`.

## Décisions du bootstrap

- Pas de `.env` réel versionné.
- Pas de gameplay implémenté dans ce lot.
- Pas de dépendance Node ou Lua ajoutée tant que les applications UI et packages n'ont pas leur cahier d'initialisation détaillé.
- Base PostgreSQL retenue dès le départ pour éviter une migration de persistance précoce depuis SQLite.

## Prochaines étapes recommandées

- Initialiser `gr_core`, `gr_database` et `gr_characters`.
- Scaffold des apps React `ui/hud` et `ui/datapad`.
- Ajouter une stratégie de seeds de développement.
- Étendre la CI avec build UI et validation SQL plus poussée.
