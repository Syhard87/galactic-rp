# CI/CD

## Portee actuelle

La CI du bootstrap MVP Tech est volontairement minimale. Elle protege la structure du depot, la presence des migrations SQL et l'hygiene de base avant d'introduire des builds applicatifs plus lourds.

## Workflow `ci.yml`

Declencheurs :

- `push`
- `pull_request`

Controles executes :

1. checkout du depot
2. verification des dossiers attendus
3. verification de la presence d'au moins une migration SQL
4. scan de secrets evidents et refus des `.env` reels
5. archivage de `server/`, `database/` et `docs/`

Nom du job CI a utiliser dans les protections de branches :

- `validate-and-package`

Ce nom doit rester unique parmi les workflows si la branche protegee exige un status check precis.

## Workflow Git attendu

Strategie de branches cible :

- `main` = branche stable de production
- `develop` = branche d'integration et de staging
- `feature/*` = branches de travail pour les nouvelles fonctionnalites
- `fix/*` = branches de correction
- `hotfix/*` = branches de correction urgente

Workflow recommande :

1. creer une branche `feature/*` ou `fix/*`
2. ouvrir une Pull Request vers `develop`
3. laisser la CI valider la branche
4. integrer vers `main` seulement depuis une branche relue et stable

## Protections recommandees

### Branche `main`

Regle recommandee : protection stricte de la branche `main`.

Parametres recommandes :

- `Require a pull request before merging` : active
- `Require approvals` : 1 approbation minimum recommandee
- `Require status checks to pass before merging` : active
- `Require branches to be up to date before merging` : active
- status check requis : `validate-and-package`
- `Require conversation resolution before merging` : active
- `Do not allow bypassing the above settings` : active
- `Enforce for administrators` : actif
- `Allow force pushes` : desactive
- `Allow deletions` : desactive

Effet recherche :

- aucun push direct de travail sur `main`
- merge uniquement via Pull Request
- CI obligatoire avant merge
- pas de force push
- pas de suppression accidentelle de la branche stable

### Branche `develop`

Regle recommandee : protection intermediaire sur la branche `develop`.

Parametres recommandes :

- `Require status checks to pass before merging` : active
- `Require branches to be up to date before merging` : active
- status check requis : `validate-and-package`
- `Allow force pushes` : desactive
- `Allow deletions` : desactive

Politique de revue :

- Pull Request recommandee vers `develop`
- si l'equipe veut une gouvernance stricte de staging, activer aussi `Require a pull request before merging`

Limite importante :

GitHub sait rendre une Pull Request obligatoire, mais ne sait pas rendre une Pull Request seulement "recommandee" comme regle technique. Si vous laissez la PR non obligatoire sur `develop`, cela reste une regle d'equipe, pas une contrainte technique.

## Configuration manuelle dans l'interface GitHub

Les protections de branches se reglent manuellement dans GitHub :

1. ouvrir le repository `Syhard87/galactic-rp`
2. aller dans `Settings`
3. ouvrir `Branches`
4. dans `Branch protection rules`, cliquer sur `Add rule`
5. creer une regle pour `main`
6. activer les options recommandees pour `main`
7. creer une deuxieme regle pour `develop`
8. activer les options recommandees pour `develop`

Reglage cle pour les checks obligatoires :

- dans la liste des status checks, selectionner `validate-and-package`

Reglages a verifier manuellement :

- le job CI reference existe toujours sous ce nom
- aucun autre workflow ne reutilise le meme nom de job
- les admins ne sont pas autorises a contourner la protection de `main`

## Option `gh` / API GitHub

La GitHub CLI ne fournit pas un assistant simple de haut niveau pour tous les cas de protection de branches. La voie la plus fiable en ligne de commande reste `gh api`, qui appelle l'API REST officielle de GitHub.

Prerequis :

- `gh` installe
- `gh auth login` valide
- droits admin sur le repository

Exemple PowerShell pour proteger `main` :

```powershell
@'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["validate-and-package"]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 1,
    "require_last_push_approval": false
  },
  "restrictions": null,
  "required_linear_history": false,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": true,
  "lock_branch": false,
  "allow_fork_syncing": false
}
'@ | gh api `
  --method PUT `
  -H "Accept: application/vnd.github+json" `
  /repos/Syhard87/galactic-rp/branches/main/protection `
  --input -
```

Exemple PowerShell pour proteger `develop` avec CI obligatoire, sans force push et sans suppression :

```powershell
@'
{
  "required_status_checks": {
    "strict": true,
    "contexts": ["validate-and-package"]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "required_linear_history": false,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_conversation_resolution": false,
  "lock_branch": false,
  "allow_fork_syncing": false
}
'@ | gh api `
  --method PUT `
  -H "Accept: application/vnd.github+json" `
  /repos/Syhard87/galactic-rp/branches/develop/protection `
  --input -
```

Si vous decidez plus tard de rendre la PR obligatoire aussi sur `develop`, remplacez `required_pull_request_reviews: null` par un objet de revue comparable a celui de `main`, ou activez l'option directement dans l'interface GitHub.

## Ce que la CI ne fait pas encore

- build React du HUD
- build React du Datapad
- lint Lua
- validation syntaxique SQL avancee
- deploiement staging
- release automatisee

## Regles d'evolution recommandees

- Ajouter le build UI seulement apres le scaffold Node des applications.
- Ajouter les validations de packages nanos world quand les premiers packages seront crees.
- Garder la release et le deploiement separes de la CI de Pull Request.
- Mettre a jour la protection de branche si le nom du job CI change.
- Documenter toute nouvelle etape dans ce fichier.

## Politique de securite minimale

- aucun `.env` reel ne doit etre versionne
- aucun token, mot de passe ou cle privee ne doit apparaitre dans le depot
- les secrets GitHub futurs seront stockes exclusivement dans les variables chiffrees GitHub Actions
