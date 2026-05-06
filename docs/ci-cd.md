# CI/CD

## Portée actuelle

La CI du bootstrap MVP Tech est volontairement minimale. Elle protège la structure du dépôt, la présence des migrations SQL et l'hygiène de base avant d'introduire des builds applicatifs plus lourds.

## Workflow `ci.yml`

Déclencheurs :

- `push`
- `pull_request`

Contrôles exécutés :

1. checkout du dépôt
2. vérification des dossiers attendus
3. vérification de la présence d'au moins une migration SQL
4. scan de secrets évidents et refus des `.env` réels
5. archivage de `server/`, `database/` et `docs/`

## Ce que la CI ne fait pas encore

- build React du HUD
- build React du Datapad
- lint Lua
- validation syntaxique SQL avancée
- déploiement staging
- release automatisée

## Règles d'évolution recommandées

- Ajouter le build UI seulement après le scaffold Node des applications.
- Ajouter les validations de packages nanos world quand les premiers packages seront créés.
- Garder la release et le déploiement séparés de la CI de Pull Request.
- Documenter toute nouvelle étape dans ce fichier.

## Politique de sécurité minimale

- aucun `.env` réel ne doit être versionné
- aucun token, mot de passe ou clé privée ne doit apparaître dans le dépôt
- les secrets GitHub futurs seront stockés exclusivement dans les variables chiffrées GitHub Actions
