# MVP Character

## Objectif

Ce document definit l'architecture actuelle du cycle MVP Character : `joueur nanos world -> player persiste -> personnage actif`.

Il documente ce qui est deja present ou prepare dans le depot, sans pretendre que le systeme Character est termine.

Il ne couvre toujours pas :

- creation de personnage fonctionnelle
- selection de personnage fonctionnelle
- spawn final complet
- UI finale complete

## Perimetre

Le perimetre couvre uniquement :

- l'identification du `Player` nanos world a la connexion
- l'association avec une ligne `players`
- le chargement des lignes `characters` liees
- le passage dans un etat `selection` ou `creation`
- l'activation serveur d'un personnage
- le spawn du personnage actif
- les regles server-authoritative et les fallbacks

Le perimetre ne couvre pas encore :

- l'UI finale de creation
- l'UI finale de selection
- la personnalisation visuelle du personnage
- les validations RP detaillees des noms, factions ou backgrounds
- les requetes SQL definitives

## Sources de verite

Sources depot :

- `AGENTS.md`
- `docs/nanos-world-reference.md`
- `docs/cahier-des-charges.md`
- `docs/architecture.md`
- `database/migrations/001_init.sql`
- `server/Packages/gr-core`
- `server/Packages/gr-database`
- `server/Packages/gr-characters`

Sources nanos world consultees :

- `external/nanos-world-docs/versioned_docs/version-latest/scripting-reference/classes/player.mdx`
- `external/nanos-world-docs/versioned_docs/version-latest/scripting-reference/classes/character.mdx`
- `external/nanos-world-docs/versioned_docs/version-latest/scripting-reference/classes/base-classes/actor.mdx`
- `external/nanos-world-docs/versioned_docs/version-latest/scripting-reference/classes/base-classes/entity.mdx`
- `external/nanos-world-docs/versioned_docs/version-latest/scripting-reference/static-classes/server.mdx`
- `external/nanos-world-docs/versioned_docs/version-latest/scripting-reference/static-classes/timer.mdx`
- `external/nanos-world-docs/versioned_docs/version-latest/scripting-reference/static-classes/package.mdx`
- `external/nanos-world-docs/versioned_docs/version-latest/core-concepts/server-and-client-lifecycle.md`
- `external/nanos-world-docs/versioned_docs/version-latest/core-concepts/packages/packages-guide.md`
- `external/nanos-world-docs/versioned_docs/version-latest/core-concepts/scripting/events-guide.md`
- `external/nanos-world-docs/versioned_docs/version-latest/core-concepts/scripting/user-interface.mdx`
- `external/nanos-world-docs/versioned_docs/version-latest/scripting-reference/classes/web-ui.mdx`
- `external/nanos-world-docs/versioned_docs/version-latest/getting-started/essential-concepts.mdx`
- `external/nanos-world-docs/versioned_docs/version-latest/getting-started/quick-start.mdx`
- `external/nanos-world-docs/versioned_docs/version-latest/getting-started/tutorials-and-examples/basic-hud-html.md`
- `external/nanos-world-docs/src/api/Classes/Player.json`
- `external/nanos-world-docs/src/api/Stable/Classes/BaseActor.json`
- `external/nanos-world-docs/src/api/Stable/Classes/BaseEntity.json`
- `external/nanos-world-docs/src/api/StaticClasses/Server.json`
- `external/nanos-world-docs/src/api/StaticClasses/Timer.json`
- `external/nanos-world-docs/src/api/StaticClasses/Package.json`
- `external/nanos-world-docs/src/api/Classes/Database.json`

## Vocabulaire

- `Player` : entite nanos world creee automatiquement quand un joueur rejoint le serveur. La doc officielle rappelle qu'un `Player` ne doit pas etre cree ou detruit manuellement.
- `player row` : ligne de la table `players`, identifiee par `players.id` et `players.platform_id`.
- `character row` : ligne de la table `characters`, rattachee a `players.id` via `characters.player_id`.
- `personnage actif` : personnage selectionne, valide cote serveur, possede par le `Player` et considere comme reference autoritative de session.
- `session character state` : etat memoire cote serveur qui relie un `Player` nanos world, un `players.id` et, si disponible, un `characters.id` actif.

## Schema actuel pris en compte

Le schema actuel suffit pour documenter le cycle MVP :

- `players` contient `id`, `platform_id`, `username`, `first_join_at`, `last_join_at`, `is_banned`, `ban_reason`
- `characters` contient `id`, `player_id`, identite RP de base et `position_x`, `position_y`, `position_z`

Le schema actuel ne contient pas :

- de colonne `last_active_character_id`
- de colonne `selected_spawn_id`
- de colonne de verrouillage de session

Consequence MVP :

- le serveur doit considerer la selection du personnage comme un choix de session, pas comme une preference persistante deja stockee en base
- un personnage existant ne devient jamais actif automatiquement sur la seule base du schema actuel

## Repartition des responsabilites par package

- `gr-core` porte les conventions communes et les noms d'evenements partages.
- `gr-database` encapsule la connexion et l'acces PostgreSQL cote serveur.
- `gr-characters` orchestre le cycle de vie `player -> character` cote serveur.
- le client et la WebUI ne servent qu'a afficher l'etat et envoyer une intention utilisateur.

## Architecture actuelle du MVP Character

Le MVP Character repose actuellement sur trois packages reels du depot :

- `gr-core` : conventions communes minimales, constantes partagees et point d'ancrage pour les futures conventions transverses.
- `gr-database` : lecture de configuration PostgreSQL et creation controlee d'une connexion nanos world `Database` cote serveur.
- `gr-characters` : chargement de session joueur, listing de personnages, creation preparee, selection preparee, resolution de spawn preparee et sauvegarde preparee de position.

### Responsabilites `Server / Client / Shared`

#### `gr-core`

- `Server/Index.lua` : journalise le chargement du package cote serveur.
- `Client/Index.lua` : journalise le chargement du package cote client.
- `Shared/Index.lua` : expose `PROJECT_NAME`, `MVP_VERSION` et `EVENT_PREFIX`.

#### `gr-database`

- `Server/DatabaseConfig.lua` : normalise une configuration PostgreSQL sans secret versionne.
- `Server/DatabaseService.lua` : cree ou reutilise la connexion nanos world `Database` a la demande.
- `Server/Index.lua` : instancie la configuration et le service sans auto-connexion.
- `Shared/Index.lua` : expose uniquement des constantes de package non sensibles.
- `Client/` : absent volontairement, car aucune logique base de donnees ne doit etre exposee au client.

#### `gr-characters`

- `Server/` : contient toute la logique autoritative du MVP Character.
- `Client/Index.lua` : journalise le chargement et rappelle qu'aucune logique autoritative personnage n'est exposee cote client.
- `Shared/Index.lua` : limite le partage aux constantes de package et au nommage des evenements.

Regle cle :

- tout ce qui touche a `players`, `characters`, au `active_character_id`, au futur spawn et a la sauvegarde de position reste cote serveur
- le client n'est documente ici que comme point d'entree UI futur, jamais comme source de verite

## Fichiers serveur `gr-characters`

Les fichiers reels presents dans `server/Packages/gr-characters/Server/` sont :

- `CharacterPlayerRepository.lua`
- `CharacterPlayerService.lua`
- `CharacterCreationService.lua`
- `CharacterDevTool.lua`
- `CharacterFlowService.lua`
- `CharacterSelectionService.lua`
- `CharacterPositionService.lua`
- `CharacterRepository.lua`
- `CharacterService.lua`
- `Index.lua`

### Catalogue des services et repositories

#### `CharacterPlayerRepository.lua`

- lit la table `players` par `players.platform_id`
- normalise la ligne retournee
- peut inserer une ligne `players` minimale cote serveur a partir de `platform_id` et `username`

#### `CharacterPlayerService.lua`

- resout l'identifiant stable nanos world avec `Player:GetAccountID()`
- resout le nom observe avec `Player:GetName()`
- maintient l'etat memoire `resolving_player`, `player-row-loaded`, `player-row-missing` ou `blocked`
- conserve en memoire la `player row` chargee par `platform_id`
- expose aussi un chargement et une creation controles par `platform_id` pour le flux joueur serveur et l'outil dev/local/test

#### `CharacterDevTool.lua`

- reserve la creation d'un personnage minimal au dev/local/test explicite
- ne s'active qu'avec `gr_characters_dev_tools_enabled = "true"`
- peut creer un personnage de test minimal puis recharger la liste et selectionner un personnage actif en memoire

#### `CharacterFlowService.lua`

- orchestre le premier flux observable `Player.Ready -> players -> characters -> active_character`
- cree la ligne `players` si elle n'existe pas encore
- charge la liste des personnages pour `players.id`
- selectionne automatiquement le premier personnage retourne par la DB selon l'ordre stable du repository
- journalise proprement le cas "aucun personnage" sans spawn ni possession
- peut deleguer au dev tool la creation d'un personnage de test uniquement si le mode dev/local/test est explicitement actif

#### `CharacterRepository.lua`

- charge la liste `characters` d'un `player_id`
- relit un personnage unique par `character_id` pour la validation serveur
- prepare l'insertion d'un personnage avec des valeurs serveur par defaut
- met a jour `position_x`, `position_y`, `position_z` pour la sauvegarde de position
- ne persiste pas encore un "personnage actif" durable en base ; `SetActiveCharacter()` reste non implemente

#### `CharacterCreationService.lua`

- valide strictement le payload de creation
- n'autorise que `first_name`, `last_name`, `age`, `species`, `biography`
- refuse tout champ sensible ou inattendu
- delegue ensuite l'insertion a `CharacterRepository`

#### `CharacterSelectionService.lua`

- charge la liste des personnages autorises pour le joueur courant
- filtre les lignes invalides
- valide qu'un `character_id` selectionne existe et appartient bien au `players.id` serveur
- memorise `active_character_id` et la ligne active uniquement en memoire de session
- ne cree pas encore l'entite `Character` gameplay et ne fait pas encore `player:Possess(...)`

#### `CharacterPositionService.lua`

- prepare la sauvegarde cote serveur de la position du personnage actif
- lit la position depuis `player:GetControlledCharacter()` puis `character:GetLocation()`
- refuse la sauvegarde si le joueur n'est pas charge, s'il n'a pas de personnage actif valide, si le `Character` controle est invalide ou si la position n'est pas lisible
- applique une cadence lente, un anti-spam DB et un cache de derniere position sauvegardee
- prepare la resolution de spawn future selon l'ordre `position persistante -> spawn point de map`
- ne realise pas encore le spawn final complet

#### `CharacterService.lua`

- sert de facade serveur unique pour `gr-characters`
- orchestre le chargement player, le chargement de liste, la creation, la selection et la sauvegarde de position
- expose les helpers de consultation d'etat de session et de politique de sauvegarde

#### `Index.lua`

- charge les fichiers serveur via `Package.Require(...)`
- recupere `GRDatabase.Server.Service` si `gr-database` est charge
- instancie repositories et services
- s'abonne a `Player.Subscribe("Ready")` pour lancer le premier flux serveur joueur -> personnage actif observable
- s'abonne a `Player.Subscribe("Destroy")` pour nettoyer la session et tenter une sauvegarde finale de position
- s'abonne a `Package.Subscribe("Load")` et `Package.Subscribe("Unload")` pour demarrer et arreter l'auto-save, puis reconciler les joueurs deja connectes

## Dependances de package

Dependances declarees dans les `Package.toml` actuels :

- `gr-core` : aucune dependance de package declaree
- `gr-database` : aucune dependance de package declaree
- `gr-characters` : depend de `gr-database`

Dependances logiques du MVP Character :

- `gr-characters` depend fonctionnellement de `gr-database` pour tout acces PostgreSQL
- `gr-core` sert aujourd'hui de socle de conventions partagees, mais n'est pas encore reference comme dependance runtime par `gr-characters`

Consequence documentaire :

- il ne faut pas presenter `gr-core` comme une dependance technique deja branchee dans `gr-characters`
- il faut le presenter comme un socle de conventions commun deja present dans le depot

## Etat de session recommande

Chaque joueur connecte doit etre suivi cote serveur avec un etat simple :

1. `connecting`
2. `resolving_player`
3. `loading_characters`
4. `waiting_character_creation`
5. `waiting_character_selection`
6. `activating_character`
7. `active`
8. `blocked`

Ce suivi reste memoire et ne modifie pas le schema SQL.

## Flux cible de connexion

### 1. Apparition du Player nanos world

Selon la documentation nanos world :

- le `Player` est cree automatiquement a la connexion
- le cycle client charge d'abord packages et entites
- le serveur recoit ensuite le `Player` et le client finit son initialisation avant l'evenement `Ready`

Conception MVP :

1. `gr-characters` doit reagir a l'evenement serveur `Player.Ready` pour un joueur reellement connecte et charge.
2. Tant qu'aucun personnage actif n'est valide, le joueur ne doit pas recevoir de personnage gameplay.
3. Le joueur peut voir une UI de chargement, de creation ou de selection, mais il ne doit pas pouvoir jouer.

Note de robustesse :

- au chargement ou rechargement du package, il faudra aussi reconcilier les `Player` deja connectes, comme le recommande l'exemple officiel qui parcourt `Player.GetAll()` sur `Package.Subscribe("Load")`

### 2. Resolution de l'identite persistee du joueur

Des l'arrivee du `Player`, le serveur doit produire un identifiant stable pour `players.platform_id`.

Contrat de conception :

1. Le serveur extrait un identifiant de plateforme stable depuis l'API `Player`.
2. Le serveur lit aussi le nom courant du joueur pour alimenter `players.username`.
3. Le client ne fournit jamais lui-meme `platform_id`.

Decision de scaffold pour l'issue #23 :

- la resolution de `players.platform_id` est isolee dans une fonction serveur dediee
- le scaffold courant utilise `Player:GetAccountID()` comme cle canonique pour `players.platform_id`
- ce choix s'appuie sur la metadata d'API locale `external/nanos-world-docs/src/api/Classes/Player.json`
- si la politique produit change plus tard vers un autre identifiant documente, la modification doit rester localisee a cette fonction
- la creation de personnage elle-meme ne doit jamais deduire un `players.id` depuis le client ; elle exige un `players.id` deja resolu cote serveur

### 3. Association avec la table `players`

Le serveur utilise `players.platform_id` comme cle de rapprochement logique.

#### Cas A : le player existe deja en base

Si une ligne `players` existe deja pour ce `platform_id` :

1. le serveur recupere `players.id`
2. le serveur recharge le profil persiste du joueur
3. le serveur mettra a jour plus tard les metadonnees de session comme `last_join_at` et `username`
4. le flux continue vers le chargement des personnages

#### Cas B : le player n'existe pas encore

Si aucune ligne `players` n'existe pour ce `platform_id` :

1. le scaffold serveur considere l'etat comme `player-row-missing`
2. le premier flux joueur serveur peut maintenant creer la ligne `players` minimale a partir de `platform_id` et `username`
3. cette creation ne doit pas accorder de gameplay ni supposer qu'un personnage existe deja
4. une fois la ligne creee, le flux peut poursuivre le chargement de la liste `characters`

Regle cle :

- il ne doit jamais exister plus d'une ligne `players` pour un meme `platform_id`

### 4. Chargement des personnages du joueur

Une fois `players.id` connu, le serveur charge toutes les lignes `characters` ou `characters.player_id = players.id`.

#### Cas C : le joueur a deja un ou plusieurs personnages

Si la liste de personnages n'est pas vide :

1. le serveur reste autoritatif sur la liste retournee
2. le client ne voit que les personnages appartenant a ce `players.id`
3. le joueur entre dans l'etat `waiting_character_selection`
4. aucun personnage n'est encore actif
5. aucun spawn gameplay n'a encore lieu

Politique MVP retenue :

- si un ou plusieurs personnages existent deja, le serveur selectionne automatiquement le premier personnage selon l'ordre stable `ORDER BY created_at ASC, id ASC`
- cette decision evite d'inventer un mecanisme de "dernier personnage actif" absent du schema actuel

#### Cas D : le joueur n'a encore aucun personnage

Si la liste est vide :

1. le joueur entre dans l'etat `waiting_character_creation`
2. le client peut afficher un ecran de creation
3. aucun personnage n'est encore actif
4. aucun spawn gameplay n'a encore lieu
5. si le mode dev/local/test est explicitement actif, le dev tool peut creer un personnage minimal de test comme fallback local

Regle cle :

- un joueur nanos world peut etre connecte sans personnage actif
- un joueur nanos world ne doit pas pouvoir jouer sans personnage actif

## Choix ou creation du personnage

### Creation de personnage

La creation est preparee cote serveur, mais elle n'est pas encore branchee a une UI complete ni a un flux gameplay final. Le contrat vise est le suivant :

1. le client envoie une intention de creation et des champs non sensibles
2. le serveur valide les champs autorises
3. le serveur cree la ligne `characters` rattachee a `players.id`
4. le serveur decide ensuite si ce nouveau personnage peut etre active dans la meme session

Regles MVP :

- seuls les champs `first_name`, `last_name`, `age`, `species` et `biography` sont autorises
- `first_name` est obligatoire
- `last_name` est obligatoire dans le schema actuel car `characters.last_name` est `NOT NULL`
- `age` est valide cote serveur dans une plage raisonnable
- `species` est obligatoire meme si la colonne SQL n'est pas `NOT NULL`, afin de garder une identite minimale coherente
- `biography` est courte, optionnelle et plafonnee cote serveur
- tout champ non autorise est rejete explicitement
- aucune coordonnee de spawn fournie par le client n'est acceptee comme source de verite
- aucune valeur sensible comme argent, permissions, reputations ou rangs ne vient du client
- `money_cash`, `money_bank`, `position_x`, `position_y` et `position_z` restent sur des valeurs serveur par defaut sures
- si la creation echoue, le joueur reste dans `waiting_character_creation`

Validation et valeurs sures du scaffold issue #24 :

- `first_name` : obligatoire, nettoye, longueur maximale 64
- `last_name` : obligatoire, nettoye, longueur maximale 64
- `age` : obligatoire, entier, plage 16 a 120
- `species` : obligatoire, nettoyee, longueur maximale 64
- `biography` : optionnelle, nettoyee, longueur maximale 280, valeur serveur par defaut `""`
- les champs sensibles comme `money_cash`, `money_bank`, `faction_id`, `rank_id`, `permissions`, `position_*`, `level`, `xp`, `skills` ou flags admin ne sont jamais acceptes depuis le payload
- si le `player` n'est pas deja charge cote serveur avec un `players.id` exploitable, la creation est refusee avec un etat `player-not-loaded`
- si l'insertion PostgreSQL echoue, la creation est refusee sans spawn ni selection implicite

### Selection de personnage

La selection est preparee cote serveur, mais elle n'est pas encore branchee au spawn final complet. Le contrat vise est le suivant :

1. le client envoie l'identifiant du personnage souhaite
2. le serveur verifie que ce personnage existe
3. le serveur verifie que ce personnage appartient bien a `players.id`
4. le serveur charge les donnees necessaires au spawn
5. seulement apres ces verifications, le personnage peut entrer dans `activating_character`

Regles MVP :

- le client ne choisit jamais seul le personnage actif
- un identifiant de personnage recu du client sans verification de propriete doit etre rejete
- la selection ne persiste pas encore en base dans le schema actuel ; elle reste un etat memoire de session cote serveur

Scaffold serveur retenu pour l'issue #25 :

- le chargement ou la creation du `player row` reussi declenche ensuite le chargement asynchrone de la liste `characters` associee a `players.id`
- si aucun personnage valide n'est liste, la session passe a `waiting_character_creation`
- si un ou plusieurs personnages valides sont listes, la session passe a `waiting_character_selection` puis peut etre auto-selectionnee en memoire dans le premier flux serveur observable
- la liste preparee cote serveur ne contient que les champs utiles a l'identite de selection : `id`, `player_id`, `first_name`, `last_name`, `age`, `species`, `biography`, `created_at`, `updated_at`
- la selection d'un `character_id` repasse par une lecture serveur de la ligne cible avant de memoriser la session
- si la ligne a disparu entre le listing et la selection, le resultat doit etre `character-unavailable`
- si la ligne existe mais appartient a un autre `players.id`, le resultat doit etre `character-not-owned`
- si la ligne existe mais ne satisfait pas les preconditions minimales de selection, le resultat doit etre `character-invalid`
- si la selection reussit, le serveur memorise un `active_character_id` transitoire de session avec un etat `character-selected`
- ce `active_character_id` ne vaut pas encore activation gameplay : le spawn et `player:Possess(...)` restent une etape ulterieure

## Moment exact ou un personnage devient actif

Un personnage devient actif seulement quand toutes les conditions suivantes sont vraies cote serveur :

1. le `Player` nanos world est toujours connecte
2. la ligne `players` a ete resolue
3. la ligne `characters` a ete resolue et appartient bien a ce `players.id`
4. l'entite `Character` nanos world a ete creee avec succes
5. le serveur a appele `player:Possess(character_entity)`
6. `player:GetControlledCharacter()` renvoie bien le personnage possede attendu

Avant ce point :

- le personnage est seulement "selectionne" ou "cree", pas encore actif
- le joueur n'a pas encore le droit d'entrer dans le gameplay

Apres ce point :

- la session passe a l'etat `active`
- `gr-characters` peut memoriser la relation `player -> active_character_id` en memoire
- les autres packages serveur peuvent consommer ce contexte actif

## Spawn du personnage actif

Le spawn doit rester entierement pilote par le serveur.

### Resolution du point de spawn

Priorite MVP recommandee :

1. utiliser la position persistante du personnage si elle est valide pour la map et la session courante
2. sinon utiliser un spawn point de map connu par le serveur via la configuration de map
3. sinon bloquer l'activation avec journalisation explicite

Justification :

- le schema actuel contient `position_x`, `position_y`, `position_z`
- la documentation nanos world recommande de definir les spawn points joueur dans le `Package.toml` de map et de les recuperer via `Server.GetMapSpawnPoints()`
- le scaffold issue `#26` prepare une resolution serveur qui traite la position persistante `0,0,0` comme "non initialisee" tant qu'aucune sauvegarde reelle n'a ete ecrite

### Sauvegarde preparatoire de position active

L'issue `#26` ne code pas encore le spawn final complet, mais fige la preparation serveur de la sauvegarde de position du personnage actif.

Regles retenues :

- seule la session serveur peut demander la sauvegarde de position du personnage actif
- aucun `character_id` libre provenant du client n'est accepte comme source d'autorite
- si un appel fournit un `character_id`, il doit correspondre exactement au `active_character_id` memoire de session cote serveur
- la position sauvegardee est lue cote serveur depuis le `Character` actuellement possede via `player:GetControlledCharacter()` puis `character:GetLocation()`
- si le `Player` n'est pas charge, s'il n'a pas de personnage actif, si la ligne active est incoherente, si le `Character` gameplay n'est pas valide ou si la position est illisible, la sauvegarde est refusee
- la cadence retenue est une sauvegarde periodique lente toutes les `60` secondes
- une tentative finale de sauvegarde peut etre lancee a la destruction du `Player`, sans introduire de boucle supplementaire

Strategie anti-spam DB :

- aucune sauvegarde par frame
- aucune sauvegarde sur `Server.Tick`
- une seule sauvegarde automatique periodique par joueur actif et par intervalle
- delai minimal de `45` secondes entre deux ecritures reussies pour un meme joueur hors cas force
- si la position a bouge de moins de `100` unites depuis la derniere sauvegarde reussie, l'ecriture est sautee
- si une sauvegarde est deja en cours pour le meme joueur, une nouvelle ecriture n'est pas lancee

Fallback spawn prepare :

- si la position persistante est absente, invalide ou encore sur le zero par defaut `0,0,0`, le serveur devra basculer vers `Server.GetMapSpawnPoints()`
- si aucun spawn point de map valide n'est disponible, l'activation future devra etre refusee et journalisee
- cette resolution est preparee dans un service dedie ; elle ne cree pas encore le `Character` gameplay et n'appelle pas encore `player:Possess(...)`

### Regles de spawn

- le serveur cree l'entite `Character`
- le serveur choisit la position et la rotation du spawn
- le serveur possess le `Character` pour le `Player`
- le client ne cree jamais lui-meme le personnage gameplay
- le client apprend l'etat actif via la synchronisation normale et les evenements de possession

### Nouveau personnage et spawn initial

Pour un personnage nouvellement cree :

- le spawn initial reste une decision serveur
- un choix de spawn eventuel venant du client doit etre interprete comme une preference, jamais comme une autorite
- si aucun spawn initial valide n'est resolvable, la creation peut etre consideree comme reussie mais l'activation doit etre refusee tant qu'un spawn serveur valide n'est pas disponible

## Regles server-authoritative

Ces regles s'appliquent a tout le cycle MVP Character :

- seul le serveur associe un `Player` nanos world a une ligne `players`
- seul le serveur charge la liste des personnages appartenant au joueur
- seul le serveur cree ou selectionne le personnage actif
- seul le serveur choisit les coordonnees finales de spawn
- seul le serveur appelle `player:Possess(...)`
- seul le serveur memorise le `active_character_id` de session
- le client n'accorde jamais argent, items, XP, reputations, permissions, rewards ou droits d'administration
- la WebUI ne fait qu'afficher l'etat et soumettre une intention utilisateur

## Flux technique actuel

Le flux technique actuellement documente et prepare dans le depot est le suivant :

1. `Player.Subscribe("Ready")` dans `gr-characters/Server/Index.lua` declenche le premier flux serveur observable pour un joueur reellement charge.
2. `CharacterFlowService` resout `platform_id` et un `observed_username` serveur, puis demande a `CharacterPlayerRepository` de lire `players.platform_id`.
3. Si aucune ligne `players` n'existe encore, `CharacterPlayerService` peut la creer cote serveur avant de poursuivre.
4. Une fois la ligne `players` disponible, `CharacterSelectionService:LoadCharactersForPlayer(...)` charge la liste `characters` du `players.id`.
5. Sans personnage valide, l'etat memoire passe a `waiting_character_creation` et le serveur journalise qu'une future UI de creation sera necessaire.
6. En dev/local/test uniquement, le dev tool peut alors creer un personnage minimal, recharger la liste et selectionner un personnage actif en memoire comme fallback explicite.
7. Avec un ou plusieurs personnages valides, la liste reste ordonnee cote DB et le serveur selectionne automatiquement le premier personnage en memoire.
8. Une future intention client de creation devra toujours passer par `CharacterCreationService`, qui valide le payload puis delegue l'insertion a `CharacterRepository`.
9. Une future intention client de selection devra toujours repasser par `CharacterSelectionService`, qui relit la ligne serveur, verifie l'ownership et memorise un `active_character_id` de session.
10. Le spawn final n'est pas encore active, mais `CharacterPositionService` prepare deja la resolution `position persistante -> spawn point de map`.
11. Une fois le personnage gameplay reellement actif dans une future issue, `CharacterPositionService` est deja prepare pour sauvegarder sa position cote serveur avec une cadence lente et des garde-fous anti-spam DB.

Lecture correcte de l'etat actuel :

- le flux `player -> player row -> character list -> creation ou selection -> active character -> position saving` est documente de bout en bout
- dans le depot actuel, les etapes jusqu'a la selection et a la preparation de la sauvegarde sont scaffolded
- l'activation gameplay finale, la possession effective et l'UI complete restent des etapes ulterieures

## Ce qui n'est pas encore implemente

Les points suivants ne doivent pas etre presentes comme termines :

- UI complete de creation et de selection de personnage
- spawn final complet du personnage gameplay
- Datapad complet
- gameplay RP complet
- creation automatique de la ligne `players` quand elle est absente
- persistance d'un "dernier personnage actif" en base
- activation gameplay complete apres la selection

Ce que le depot prepare deja sans le terminer :

- validation serveur de creation de personnage
- validation serveur de selection de personnage
- memorisation memoire du personnage actif de session
- resolution de fallback de spawn
- sauvegarde lente de position du personnage actif cote serveur

## Erreurs possibles et fallbacks

### Identifiant joueur introuvable

Probleme :

- le serveur ne parvient pas a extraire un identifiant stable pour `players.platform_id`

Fallback :

- ne pas activer de personnage
- passer la session en `blocked`
- journaliser l'erreur
- refuser le gameplay tant que la cause n'est pas resolue

### Base indisponible

Probleme :

- `gr-database` ne peut pas ouvrir ou reutiliser une connexion exploitable

Fallback :

- ne pas spawner de personnage gameplay
- rester dans un etat de blocage ou d'attente
- afficher un etat de maintenance cote client si une UI existe
- journaliser l'erreur cote serveur

### Ligne `players` introuvable ou creation echouee

Probleme :

- la lecture ou la creation de la ligne `players` echoue

Fallback :

- aucun chargement de personnage
- session en `blocked`
- journalisation serveur

### Chargement des personnages echoue

Probleme :

- la lecture des lignes `characters` echoue

Fallback :

- ne pas supposer que le joueur n'a aucun personnage
- ne pas basculer automatiquement vers la creation
- garder la session bloquee avec message d'erreur

### Personnage demande non trouve ou non possede

Probleme :

- l'identifiant choisi ne correspond a aucun personnage du joueur

Fallback :

- refuser l'activation
- reafficher la liste autorisee
- journaliser une tentative invalide

### Personnage indisponible ou invalide au moment de la selection

Probleme :

- un personnage liste precedemment a ete supprime entre temps, ou bien sa ligne ne remplit plus les preconditions minimales de selection

Fallback :

- refuser la selection
- vider tout `active_character_id` transitoire deja memorise pour cette session
- relancer ou reafficher la liste serveur autorisee
- journaliser le code `character-unavailable` ou `character-invalid`

### Position persistante invalide

Probleme :

- la position sauvegardee est absente, corrompue ou inutilisable pour la map courante
- le zero par defaut `0,0,0` est interprete comme une position non initialisee dans le scaffold `#26`

Fallback :

- basculer vers un spawn point de map valide
- si aucun spawn point n'existe, ne pas activer le personnage

### Spawn ou possession echoue

Probleme :

- l'entite `Character` n'est pas creee correctement ou la possession n'aboutit pas

Fallback :

- ne pas marquer le personnage comme actif
- nettoyer l'entite intermediaire si necessaire
- renvoyer la session vers l'etat de selection
- journaliser l'echec

### Deconnexion pendant le flux

Probleme :

- le joueur quitte le serveur pendant `resolving_player`, `loading_characters` ou `activating_character`

Fallback :

- abandonner proprement le flux
- nettoyer l'etat memoire de session
- ne pas poursuivre d'activation retardee

### UI client non prete ou rechargee

Probleme :

- la WebUI n'est pas encore chargee, ou le package client vient d'etre recharge

Fallback :

- conserver la source de verite cote serveur
- renvoyer l'etat de session vers le client quand l'UI redevient disponible
- ne jamais deduire un personnage actif uniquement depuis l'etat local du client

## Implications pour l'implementation future

Cette issue fige les decisions suivantes :

- le cycle passe d'abord par la resolution `players`, puis par `characters`
- aucun gameplay n'est autorise sans personnage actif
- la selection reste explicite a chaque session dans le schema actuel
- l'activation est un acte serveur, pas un simple choix UI
- le spawn prefere la position persistante du personnage puis les spawn points de map
- tout echec critique bloque l'activation au lieu de laisser jouer avec un etat incomplet

## Resume du flux nominal

1. Le `Player` nanos world apparait.
2. Le serveur ouvre un etat de session `resolving_player`.
3. Le serveur resout ou cree la ligne `players`.
4. Le serveur charge les lignes `characters`.
5. Sans personnage : etat `waiting_character_creation`.
6. Avec personnage : etat `waiting_character_selection`.
7. Le client envoie une intention de creation ou de selection.
8. Le serveur valide la propriete du `character_id` et memorise un `active_character_id` transitoire.
9. Le serveur resout ensuite le spawn, cree le `Character` et appelle `player:Possess(...)`.
10. Le personnage devient actif seulement apres validation serveur de la possession.
