# Security Baseline

## Objectif

Ce document decrit la baseline securite du bootstrap MVP Tech de Galactic RP. Il couvre la gestion des secrets, les regles server-authoritative, les frontieres client/server, les risques connus et une checklist a executer avant toute Pull Request.

## Gestion Des Secrets

Principes obligatoires :

- ne jamais versionner de secret reel
- ne jamais creer de fichier `.env` dans le repository
- utiliser uniquement des fichiers d'exemple comme `docker/.env.example`
- ne jamais committer de cle privee, certificat exportable ou token d'acces
- ne jamais versionner de `Config.toml` de production ou de staging
- ne jamais journaliser un mot de passe reel, un token ou une connection string complete

Formats consideres sensibles :

- `.env`
- `.pem`
- `.key`
- `.p12`
- `.pfx`
- tokens GitHub, AWS, SSH ou equivalents
- mots de passe reels de base de donnees, staging ou production

Etat actuel verifie :

- `docker/.env.example` contient uniquement des valeurs locales fictives :
  - `change-me-local-only`
  - `admin@local.dev`
  - `galactic_rp`
  - `galactic`
- aucun fichier secret reel n'est present dans le depot controle
- `.gitignore` bloque les `.env`, `.pem`, `.key`, `.p12`, `.pfx` et `server/Config.toml`
- `.github/workflows/ci.yml` refuse les `.env`, `.pem`, `.key` et plusieurs motifs de tokens evidents

## Regles Server-Authoritative

Le serveur doit rester la seule autorite pour toutes les mutations sensibles.

Le client ne doit jamais accorder directement :

- XP
- argent
- inventaire ou items
- reputation
- recompenses de quetes
- permissions admin
- grades, sanctions ou privileges

Le serveur doit valider avant toute mutation :

- l'identite du joueur
- les permissions et roles
- les preconditions gameplay
- la coherence des donnees persistees
- l'effet final ecrit en base

## Regles Client/Server

Responsabilites client :

- afficher les donnees
- collecter l'intention utilisateur
- envoyer des demandes au serveur
- gerer les interactions locales non autoritatives

Responsabilites serveur :

- valider chaque action sensible
- calculer les gains et pertes
- attribuer les recompenses
- modifier l'etat persistant
- journaliser les actions critiques si necessaire

Regles pratiques :

- aucune WebUI ne doit contenir la source de verite de progression ou d'economie
- aucun event client ne doit etre considere fiable sans verification serveur
- les requetes client doivent etre traitees comme non fiables par defaut
- les scripts client peuvent demander, jamais accorder
- `gr_database` doit rester un package de logique sensible cote serveur, sans credentials ni acces SQL dans `Client/` ou `Shared/`
- les logs de configuration ou de connexion doivent utiliser un etat redacte comme `has_password=true|false`, jamais la valeur du secret

## Risques Connus

Risques deja reduits :

- commit accidentel de `.env` reels : reduit par `.gitignore` et CI
- commit accidentel de cles privees evidentes : reduit par `.gitignore` et CI
- autorite client sur la progression ou l'economie : interdite dans `AGENTS.md` et `docs/architecture.md`

Risques restants :

- la CI ne detecte pas tous les formats de secrets possibles ni tous les tokens proprietaires
- la CI ne detecte pas les secrets binaires si leur extension n'est pas couverte
- il n'existe pas encore de code serveur/client a auditer pour verifier l'application concrete du modele server-authoritative
- il n'existe pas encore de rotation, coffre de secrets ou politique de staging/production operationnelle
- les faux positifs et faux negatifs de scans regex restent possibles

Mesures recommandees pour les prochains lots :

- ajouter un scan de secrets plus robuste quand la stack CI evoluera
- documenter la gestion des secrets GitHub Actions avant tout deploiement staging
- imposer une revue securite pour chaque package gameplay qui touche progression, inventaire, economie, admin ou quetes
- ajouter des logs serveur pour les actions a fort impact des que les premiers packages seront crees

## Checklist Securite Avant PR

- [ ] aucun fichier `.env`, `.pem`, `.key`, `.p12` ou `.pfx` n'est ajoute au diff
- [ ] aucun mot de passe reel, token ou cle privee n'apparait dans les fichiers modifies
- [ ] aucun mot de passe reel, token ou connection string complete n'apparait dans les logs ajoutes ou modifies
- [ ] si un fichier d'exemple change, ses valeurs restent fictives et locales
- [ ] aucune logique sensible n'est deplacee cote client
- [ ] toute mutation d'XP, argent, inventaire, reputation, recompense ou permission reste server-authoritative
- [ ] la documentation securite est mise a jour si une regle change
- [ ] le workflow CI passe sans alerte secret evidente
- [ ] la Pull Request documente clairement les impacts securite si elle touche auth, persistance ou permissions

## Commandes Utiles

Verifier les fichiers sensibles versionnes :

```powershell
rg --files -g ".env" -g "*.pem" -g "*.key" -g "*.p12" -g "*.pfx"
```

Verifier les motifs de secrets evidents hors documentation :

```powershell
rg -n "(AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]+|-----BEGIN (RSA|DSA|EC|OPENSSH) PRIVATE KEY-----)" . -g "!*.md" -g "!.env.example"
```

Verifier la baseline de documentation securite :

```powershell
Get-Content AGENTS.md
Get-Content docs/architecture.md
Get-Content .github/workflows/ci.yml
```
