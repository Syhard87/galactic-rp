# MVP Tech Validation Checklist

## Objectif

Cette checklist sert a valider le bootstrap MVP Tech de Galactic RP avant d'ouvrir des lots gameplay ou UI plus ambitieux. Chaque point doit etre coche avec un resultat observe, pas seulement suppose.

## Preparation

- [ ] Travailler depuis la racine du repository
  Commande :
  ```powershell
  git status --short --branch
  ```
  Resultat attendu :
  La branche de travail est correcte et l'etat du depot est compris avant la validation.

- [ ] Verifier que Docker Desktop ou un moteur Docker compatible Compose est demarre
  Commande :
  ```powershell
  docker version
  ```
  Resultat attendu :
  Le client et le serveur Docker repondent sans erreur de connexion.

## Git Et Branches

- [ ] La strategie de branches correspond au workflow documente
  Commande :
  ```powershell
  git branch --all
  ```
  Resultat attendu :
  Le projet utilise `main` pour le stable, `develop` pour l'integration, et des branches de travail de type `feature/*`, `fix/*` ou `hotfix/*`.

- [ ] La branche `main` est protegee sur GitHub
  Commande :
  Aucun binaire local obligatoire. Verifier dans GitHub `Settings > Branches`.
  Resultat attendu :
  Pull Request obligatoire, CI obligatoire avant merge, force push interdit, suppression interdite ou strictement controlee.

- [ ] La branche `develop` applique la politique de staging documentee
  Commande :
  Aucun binaire local obligatoire. Verifier dans GitHub `Settings > Branches`.
  Resultat attendu :
  La CI est obligatoire, le force push est interdit, et l'equipe applique une revue via Pull Request au minimum par convention.

## GitHub Issues Et Project

- [ ] Les templates GitHub Issues sont disponibles
  Commande :
  ```powershell
  Get-ChildItem .github/ISSUE_TEMPLATE
  ```
  Resultat attendu :
  Les templates `user-story.yml`, `technical-task.yml` et `bug-report.yml` sont presents.

- [ ] Une issue technique peut etre rattachee au lot en cours
  Commande :
  Aucun binaire local obligatoire. Verifier dans GitHub `Issues`.
  Resultat attendu :
  L'issue existe, possede une description claire, des criteres d'acceptation, une priorite et un scope compatible avec la Definition of Ready.

- [ ] Le GitHub Project Kanban du projet est configure
  Commande :
  Aucun binaire local obligatoire. Verifier dans GitHub `Projects`.
  Resultat attendu :
  Le Kanban expose au minimum backlog, en cours, review, test et done, avec des champs de priorite, type, epic et complexite.

## Infrastructure Locale

- [ ] Docker Compose est disponible
  Commande :
  ```powershell
  docker compose version
  ```
  Resultat attendu :
  Docker Compose retourne sa version sans erreur.

- [ ] Le fichier Compose attendu existe
  Commande :
  ```powershell
  Test-Path docker/docker-compose.yml
  ```
  Resultat attendu :
  La commande retourne `True`.

- [ ] Le fichier d'environnement d'exemple attendu existe
  Commande :
  ```powershell
  Test-Path docker/.env.example
  ```
  Resultat attendu :
  La commande retourne `True`.

- [ ] La stack locale demarre correctement
  Commande :
  ```powershell
  .\tools\start-dev.ps1
  ```
  Resultat attendu :
  Le script valide Docker, utilise `docker/.env.example`, lance `postgres` et `pgadmin`, puis affiche l'etat des services sans erreur.

- [ ] PostgreSQL est `healthy`
  Commande :
  ```powershell
  docker compose --env-file docker/.env.example -f docker/docker-compose.yml ps
  ```
  Resultat attendu :
  Le service `postgres` apparait en etat `healthy` ou `Up ... (healthy)`.

- [ ] pgAdmin est accessible localement
  Commande :
  Ouvrir `http://localhost:5050` dans un navigateur.
  Resultat attendu :
  La page de connexion pgAdmin s'affiche et accepte les identifiants locaux documentes.

## Base De Donnees

- [ ] La migration SQL initiale est executable
  Commande :
  ```powershell
  docker compose --env-file docker/.env.example -f docker/docker-compose.yml exec -T postgres psql -U galactic -d galactic_rp -f /workspace/database/migrations/001_init.sql
  ```
  Resultat attendu :
  Le script s'execute sans erreur SQL bloquante et les tables `players`, `characters` et `character_skills` existent.

- [ ] Le seed de developpement est executable
  Commande :
  ```powershell
  docker exec -it galactic-rp-postgres psql -U galactic -d galactic_rp -f /workspace/database/seeds/dev_seed.sql
  ```
  Resultat attendu :
  Le seed s'execute sans erreur et insere ou met a jour un joueur fictif, un personnage fictif et plusieurs competences de test.

- [ ] Le seed de developpement est relancable sans doublons majeurs
  Commande :
  ```powershell
  docker exec -i galactic-rp-postgres psql -U galactic -d galactic_rp -c "SELECT p.platform_id, COUNT(DISTINCT c.id) AS character_count, COUNT(cs.id) AS skill_count FROM players p JOIN characters c ON c.player_id = p.id LEFT JOIN character_skills cs ON cs.character_id = c.id WHERE p.platform_id = 'dev-player-001' GROUP BY p.platform_id;"
  ```
  Resultat attendu :
  La ligne de test reste unique pour `dev-player-001`, avec un seul personnage de test et le nombre attendu de competences apres plusieurs executions du seed.

## CI Et Hygiene Du Depot

- [ ] Le workflow GitHub Actions principal existe
  Commande :
  ```powershell
  Test-Path .github/workflows/ci.yml
  ```
  Resultat attendu :
  La commande retourne `True`.

- [ ] Le job CI attendu est documente et coherent
  Commande :
  ```powershell
  Select-String -Path .github/workflows/ci.yml -Pattern "validate-and-package"
  ```
  Resultat attendu :
  Le job `validate-and-package` est present et correspond a la documentation CI.

- [ ] La CI GitHub Actions est verte sur la branche ou la Pull Request
  Commande :
  Aucun binaire local obligatoire. Verifier dans GitHub `Actions` ou sur la Pull Request.
  Resultat attendu :
  Le workflow `CI` est en succes et aucun check obligatoire n'est en echec.

- [ ] Aucun secret reel n'est versionne
  Commande :
  ```powershell
  rg --files -g ".env" -g "*.pem" -g "*.key"
  ```
  Resultat attendu :
  Aucun fichier secret reel n'est trouve dans le repository.

- [ ] Aucun motif de secret evident n'apparait dans le depot
  Commande :
  ```powershell
  rg -n "(AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]+|-----BEGIN (RSA|DSA|EC|OPENSSH) PRIVATE KEY-----)" . -g "!*.md" -g "!.env.example"
  ```
  Resultat attendu :
  Aucune correspondance n'est retournee.

## Documentation Minimale

- [ ] La documentation minimale MVP Tech est presente
  Commande :
  ```powershell
  @(
    'README.md',
    'docs/cahier-des-charges.md',
    'docs/architecture.md',
    'docs/local-dev.md',
    'docs/ci-cd.md',
    'docs/backlog.md',
    'docs/mvp-tech-validation-checklist.md'
  ) | ForEach-Object { "{0}`t{1}" -f $_, (Test-Path $_) }
  ```
  Resultat attendu :
  Tous les fichiers listes existent et sont consultables dans le repository.

- [ ] La documentation locale de dev est coherent avec l'infrastructure reelle
  Commande :
  ```powershell
  Get-Content docs/local-dev.md
  ```
  Resultat attendu :
  Les commandes de demarrage, migration et seed correspondent bien a `docker/docker-compose.yml`, `database/migrations/001_init.sql` et `database/seeds/dev_seed.sql`.

## Validation Finale MVP Tech

- [ ] Le workflow Git et les protections de branches sont appliques
- [ ] L'infrastructure locale PostgreSQL + pgAdmin demarre sans intervention manuelle non documentee
- [ ] La migration initiale et le seed de developpement s'executent sans erreur
- [ ] La CI obligatoire est verte
- [ ] Aucun secret reel n'est versionne
- [ ] La documentation minimale est presente et a jour

Conclusion :

- [ ] MVP Tech valide
- [ ] MVP Tech a corriger avant passage au lot suivant
