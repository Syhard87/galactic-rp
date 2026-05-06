# Backlog MVP Tech

## Cadre

Ce backlog couvre uniquement le bootstrap technique du projet. Chaque item respecte la logique du cahier des charges et prépare le terrain pour les futures features gameplay sans les implémenter.

## Epique Infra

### US-INFRA-001 - Structure monorepo initiale

- Statut : Done
- Priorité : P0
- Complexité : S
- Packages impactés : monorepo
- Impact DB/UI : structure créée pour DB et UI, sans code métier
- Critères d'acceptation :
  - dossiers serveur, UI, database, docker, tools et `.github/` présents
  - structure versionnée dans Git

### US-INFRA-002 - Documentation technique initiale

- Statut : Done
- Priorité : P0
- Complexité : M
- Packages impactés : docs
- Impact DB/UI : documentation des impacts techniques et des limites du MVP
- Critères d'acceptation :
  - `docs/architecture.md` créé
  - `docs/local-dev.md` créé
  - `docs/ci-cd.md` créé
  - `docs/backlog.md` créé

### US-INFRA-003 - Templates GitHub de contribution

- Statut : Done
- Priorité : P0
- Complexité : M
- Packages impactés : `.github/`
- Impact DB/UI : aucun
- Critères d'acceptation :
  - template Pull Request présent
  - templates User Story, Bug Report et Technical Task présents

### US-INFRA-004 - Docker Compose PostgreSQL local

- Statut : Done
- Priorité : P0
- Complexité : M
- Packages impactés : `docker/`
- Impact DB/UI : DB locale disponible, aucun code UI
- Critères d'acceptation :
  - PostgreSQL défini dans Compose
  - pgAdmin défini dans Compose
  - volumes persistants configurés
  - `docker/.env.example` présent

### US-INFRA-005 - Migration SQL initiale

- Statut : Done
- Priorité : P0
- Complexité : M
- Packages impactés : `database/`
- Impact DB/UI : schéma minimal pour joueurs, personnages et compétences
- Critères d'acceptation :
  - `database/migrations/001_init.sql` créé
  - tables `players`, `characters`, `character_skills` présentes

### US-INFRA-006 - CI minimale GitHub Actions

- Statut : Done
- Priorité : P0
- Complexité : M
- Packages impactés : `.github/workflows/`
- Impact DB/UI : contrôle qualité du dépôt
- Critères d'acceptation :
  - workflow déclenché sur push et pull request
  - vérification de structure
  - vérification des migrations SQL
  - scan de secrets évidents
  - artefact serveur/database/docs publié

## Prochain backlog recommandé

### TECH-001 - Initialiser `gr_core`

- Statut : Ready
- Priorité : P0
- Complexité : M
- Packages impactés : `server/Packages/gr_core`
- Impact DB/UI : aucun impact DB direct, contrat d'événements communs à prévoir

### TECH-002 - Initialiser `gr_database`

- Statut : Ready
- Priorité : P0
- Complexité : M
- Packages impactés : `server/Packages/gr_database`
- Impact DB/UI : connexion PostgreSQL, configuration serveur, aucun écran UI

### TECH-003 - Scaffold `ui/hud`

- Statut : Ready
- Priorité : P1
- Complexité : M
- Packages impactés : `ui/hud`
- Impact DB/UI : base React/Vite/Tailwind, sans HUD métier

### TECH-004 - Scaffold `ui/datapad`

- Statut : Ready
- Priorité : P1
- Complexité : M
- Packages impactés : `ui/datapad`
- Impact DB/UI : base React/Vite/Tailwind, sans logique métier
