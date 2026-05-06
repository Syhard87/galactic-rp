# Cahier des charges — Serveur RP Space Opera / Star Wars-like sur nanos world

Version : 0.1  
Statut : cadrage initial  
Objectif : créer un serveur RP ambitieux, stable, immersif et durable, inspiré de l’univers Star Wars, en limitant les risques légaux et techniques.

---

## 1. Vision du projet

Créer un serveur RP multijoueur de très haute qualité dans un univers de science-fiction galactique, avec factions, planètes, métiers, économie, politique, conflits militaires, criminalité, progression personnage, événements scénarisés et outils d’administration solides.

L’objectif n’est pas seulement de faire une map avec des sabres laser et des vaisseaux. L’objectif est de créer un monde RP cohérent où les joueurs ont envie de rester, de progresser, d’interagir, de créer des histoires et de respecter l’univers.

### Positionnement recommandé

Nom de travail interne : **Star Wars RP nanos world**  
Nom public recommandé : **Galactic RP**, **Outer Rim RP**, **Republic & Empire RP**, ou autre nom original.

Raison : utiliser publiquement le nom Star Wars, les logos, musiques, modèles officiels ou assets extraits de jeux/films expose le projet à un risque légal. Pour un projet sérieux et durable, il vaut mieux créer une expérience inspirée de Star Wars, mais avec assets originaux ou sous licence.

---

## 2. Objectifs principaux

### Objectifs produit

- Créer un serveur RP sérieux, immersif et accessible.
- Offrir plusieurs styles de jeu : civil, militaire, politique, criminel, marchand, explorateur, force-user.
- Éviter le RP brouillon grâce à des règles, métiers, interfaces et systèmes clairs.
- Construire une base technique modulaire pour ajouter des planètes, factions et systèmes sans tout casser.
- Avoir un MVP jouable rapidement, puis enrichir progressivement.

### Objectifs techniques

- Développer le serveur sous forme de packages nanos world bien séparés.
- Utiliser une base de données pour la persistance des personnages, inventaires, factions, propriétés et sanctions.
- Créer des interfaces propres : création de personnage, fiche personnage, inventaire, menu faction, menu admin, datapad.
- Structurer les assets pour éviter les performances catastrophiques.
- Mettre en place une méthode de déploiement et de sauvegarde propre.

### Objectifs communautaires

- Recruter une équipe staff fiable.
- Définir une charte RP claire.
- Prévoir des outils de modération dès le début.
- Créer une boucle d’événements réguliers.
- Éviter le pay-to-win.

---

## 3. Périmètre du projet

### MVP — Version jouable minimale

Le MVP doit être un serveur RP jouable avec une seule planète principale, quelques factions, une économie simple et une boucle RP claire.

Contenu MVP recommandé :

- 1 planète principale jouable.
- 1 zone civile.
- 1 zone militaire / gouvernementale.
- 1 zone criminelle.
- 3 à 5 factions.
- Création de personnage.
- Système de spawn par faction.
- Système d’identité.
- Chat RP local / global / faction / admin.
- Inventaire simple.
- Argent / banque.
- Métiers de base.
- Véhicules terrestres simples.
- Armes de base.
- Système de permissions.
- Menu admin.
- Logs serveur.
- Persistance en base de données.

### Hors MVP — À reporter

À ne pas faire au départ, sauf si l’équipe est déjà très solide :

- Plusieurs planètes complètes.
- Système spatial complet avec combats de vaisseaux.
- 50 métiers.
- 20 factions.
- Économie ultra-complexe.
- Système Jedi/Sith trop ouvert.
- Grandes quêtes cinématiques.
- Doublage audio.
- Crafting très avancé.
- Politique entièrement dynamique.

Ce sont des pièges classiques : trop d’ambition au départ = projet jamais terminé.

---

## 4. Contraintes légales et assets

### Règle forte

Ne pas utiliser d’assets extraits de jeux Star Wars, de films, de séries ou de sources non autorisées.

Cela inclut :

- Modèles 3D ripés.
- Musiques officielles.
- Logos officiels.
- Sons officiels.
- Textures issues de jeux existants.
- Noms de marque dans la communication commerciale.

### Stratégie recommandée

Créer un serveur **inspiré space opera** :

- Sabre énergétique au lieu de “lightsaber”.
- Ordre mystique au lieu de “Jedi”.
- Empire galactique original au lieu d’utiliser exactement l’Empire Star Wars.
- Planètes originales inspirées de biomes connus : désert, jungle, ville, glace, lune industrielle.
- Vaisseaux originaux.
- Armures originales.

### Si vous voulez absolument utiliser Star Wars publiquement

Il faudra accepter les risques ou chercher une autorisation/licence. Pour un projet sérieux, avec serveur public, éventuelle monétisation, boutique ou communication forte, le choix prudent est de ne pas baser l’identité officielle du serveur sur une marque protégée.

---

## 5. Public cible

### Joueurs principaux

- Joueurs RP sérieux.
- Fans d’univers galactiques.
- Joueurs aimant les factions, grades, métiers, histoire et progression.
- Joueurs qui veulent vivre un rôle, pas seulement faire du PvP.

### Profils à attirer

- Civils/commerçants.
- Militaires.
- Policiers/sécurité.
- Criminels.
- Médecins.
- Mécaniciens.
- Pilotes.
- Diplomates.
- Force-users rares et encadrés.

### Profils à filtrer

- Trolls.
- Joueurs full PvP sans RP.
- Joueurs qui veulent uniquement un sabre laser dès leur première connexion.
- Staffs immatures ou trop autoritaires.

---

## 6. Univers et direction créative

### Époque recommandée

Créer une époque originale inspirée des grands conflits galactiques :

- Un gouvernement central affaibli.
- Une faction impériale autoritaire.
- Des mondes de bordure extérieure.
- Des guildes commerciales.
- Des groupes criminels.
- Des ordres mystiques rares.

### Ton du serveur

- Sérieux, mais pas inaccessible.
- Immersif, mais pas trop élitiste.
- Politique et militaire, mais avec de la place pour les civils.
- Conflit possible, mais encadré par règles RP.

### Pilier narratif

La galaxie est instable. Une planète stratégique devient un point de tension entre gouvernement, armée, contrebande, factions locales et croyances anciennes.

---

## 7. Planètes et mondes

### Phase 1 — Une planète principale

Nom provisoire : **Varkos Prime**

Biome : ville semi-désertique / port spatial / zone industrielle.

Zones :

- Spatioport.
- Quartier civil.
- Cantina.
- Marché.
- Administration.
- Caserne / base militaire.
- Clinique.
- Garage / hangar.
- Zone industrielle.
- Bas-fonds criminels.
- Désert extérieur.
- Ruines anciennes.

### Phase 2 — Deuxième planète

Nom provisoire : **Keryn**

Biome : jungle / temple ancien / avant-postes.

Objectif : exploration, événements, ressources rares, RP mystique.

### Phase 3 — Troisième planète

Nom provisoire : **Nivos Station**

Biome : station spatiale / zone neutre.

Objectif : commerce, diplomatie, marché noir, transport spatial.

### Règle de conception

Chaque planète doit avoir une utilité RP. Une planète décorative qui ne sert à rien fatigue les joueurs et disperse la communauté.

---

## 8. Factions

### Factions MVP

#### 1. Autorité galactique / gouvernement local

Rôle : maintenir l’ordre, gérer les lois, délivrer autorisations, organiser la politique locale.

Gameplay :

- Contrôle d’identité.
- Arrestations.
- Enquêtes.
- Permis.
- Lois locales.
- Relations diplomatiques.

#### 2. Corps militaire / sécurité

Rôle : défense de la planète, interventions armées, protection des zones sensibles.

Gameplay :

- Patrouilles.
- Checkpoints.
- Opérations.
- Formation des recrues.
- Gestion des grades.

#### 3. Guilde marchande / transporteurs

Rôle : commerce, transport, ravitaillement, missions économiques.

Gameplay :

- Livraisons.
- Vente de marchandises.
- Entretien des véhicules.
- Contrats avec factions.

#### 4. Syndicat criminel

Rôle : marché noir, contrebande, racket, missions illégales.

Gameplay :

- Trafic.
- Braquages encadrés.
- Corruption.
- Faux papiers.
- Cachettes.

#### 5. Ordre mystique rare

Rôle : force-users / équivalent lore original.

Gameplay :

- Formation très limitée.
- Pouvoirs rares.
- Artefacts.
- Choix moraux.
- Responsabilité RP élevée.

### Règle importante pour les force-users

Ne jamais rendre les pouvoirs mystiques accessibles à tout le monde dès le début. Sinon le serveur devient un deathmatch avec sabres.

Accès recommandé : candidature + progression RP + validation staff lore.

---

## 9. Systèmes de gameplay

## 9.1 Création de personnage

### Fonctionnalités

- Nom RP.
- Prénom RP.
- Âge.
- Espèce/origine.
- Background court.
- Apparence.
- Faction initiale ou civil.
- Choix d’un spawn initial.

### Règles

- Nom cohérent obligatoire.
- Background validable par staff si faction sensible.
- Un joueur peut avoir plusieurs personnages, mais pas d’abus interpersonnage.

### Critères d’acceptation

- Le joueur ne peut pas jouer sans personnage actif.
- Les données sont sauvegardées.
- Le personnage réapparaît avec son argent, faction, inventaire et position selon les règles.

---

## 9.2 Identité et datapad

Le datapad est l’interface centrale du joueur.

### Contenu

- Carte d’identité.
- Informations personnage.
- Argent.
- Faction.
- Grade.
- Missions.
- Contacts.
- Licences/permis.
- Casier judiciaire.
- Paramètres RP.

### Intérêt

Au lieu de multiplier les menus, le datapad devient l’outil immersif principal.

---

## 9.3 Chat RP

### Canaux

- Local RP.
- Chuchoter.
- Crier.
- Action `/me`.
- Description `/do`.
- Radio faction.
- Canal admin.
- Annonce serveur.

### Règles

- Le chat local doit être basé sur la distance.
- Les canaux radio nécessitent un équipement ou une faction.
- Les logs doivent conserver les messages importants.

---

## 9.4 Inventaire

### MVP

- Liste d’objets.
- Poids ou limite de slots.
- Utiliser un objet.
- Donner un objet.
- Jeter un objet.
- Stockage coffre faction.

### Objets MVP

- Argent liquide.
- Documents.
- Comlink/radio.
- Médikit.
- Arme légère.
- Nourriture/boisson.
- Ressource de livraison.
- Clé/carte d’accès.

### Évolution

- Crafting.
- Conteneurs.
- Objets illégaux.
- Objets uniques.
- Artefacts rares.

---

## 9.5 Économie

### MVP

- Argent en banque.
- Argent liquide.
- Salaire selon métier/faction.
- Paiements entre joueurs.
- Boutiques PNJ simples.
- Missions de livraison.

### Économie avancée

- Prix dynamiques.
- Ressources par planète.
- Taxation par gouvernement.
- Marché noir.
- Contrats privés.
- Entreprises joueurs.

### Danger à éviter

Une économie trop généreuse détruit la progression. Une économie trop lente décourage les joueurs.

---

## 9.6 Métiers civils

### MVP recommandé

- Transporteur.
- Mécanicien.
- Médecin.
- Commerçant.
- Mineur/récupérateur.
- Sécurité privée.

### Objectif

Donner du RP aux civils. Si seuls les militaires et criminels ont des choses à faire, le serveur devient instable.

---

## 9.7 Système de loi et criminalité

### Fonctionnalités

- Casier judiciaire.
- Amendes.
- Mandats.
- Arrestation.
- Prison temporaire.
- Fouille.
- Confiscation.
- Licences d’armes.

### Règles de gameplay

- Les arrestations doivent être RP.
- Les abus police/crime doivent être sanctionnés.
- Les braquages doivent avoir des conditions strictes.
- Le staff doit pouvoir revoir les logs.

---

## 9.8 Combat

### Philosophie

Le combat doit servir le RP, pas remplacer le RP.

### MVP

- Armes de base.
- Dégâts équilibrés.
- Système d’inconscience.
- Réanimation médicale.
- Respawn encadré.
- Logs de dégâts/morts.

### Règles

- Pas de freekill.
- Pas d’usage abusif de pouvoirs.
- Pas de combat dans zones safe sauf événement validé.

---

## 9.9 Pouvoirs mystiques / sabres énergétiques

### MVP

À limiter fortement.

Fonctionnalités initiales :

- Arme énergétique rare.
- Blocage/parade simple.
- Pouvoir basique non létal.
- Système de progression manuel ou semi-automatisé.

### Évolution

- Arbre de compétences.
- Pouvoirs défensifs/offensifs.
- Artefacts.
- Alignement moral.
- Maître/apprenti.

### Règle absolue

Les pouvoirs ne doivent pas casser l’équilibre du serveur. Un civil, militaire ou criminel doit pouvoir exister sans être inutile face à un force-user.

---

## 9.10 Véhicules et vaisseaux

### MVP

- Véhicules terrestres.
- Speeder-like original.
- Hangar décoratif.
- Téléportation RP vers une autre zone si nécessaire.

### Version avancée

- Vaisseaux pilotables.
- Hubs spatiaux.
- Transport interplanétaire.
- Combats spatiaux encadrés.
- Maintenance/fuel.

### Recommandation

Ne pas commencer par le combat spatial. C’est très coûteux en dev, assets, équilibrage et performance.

---

## 9.11 Missions et événements

### Missions automatiques MVP

- Livraison.
- Réparation.
- Récupération de ressources.
- Patrouille.
- Contrat médical.
- Transport de passagers.

### Événements staff

- Attaque de pirates.
- Crise politique.
- Convoi sensible.
- Découverte de ruines.
- Trahison interne.
- Blocus.
- Enquête criminelle.

### Objectif

Les missions automatiques remplissent les temps morts. Les événements staff créent la mémoire du serveur.

---

## 10. Architecture technique proposée

## 10.1 Stack nanos world

- Serveur nanos world dédié.
- Packages Lua pour la logique serveur/client.
- UI en HTML/CSS/JS ou React selon besoin.
- Assets via Unreal Engine + ADK nanos world.
- Base de données : PostgreSQL recommandé pour projet sérieux.
- SQLite possible en développement local ou MVP ultra-simple.

## 10.2 Organisation des packages

Structure recommandée :

```txt
Packages/
  gr_core/
    Server/
    Client/
    Shared/
    Package.toml

  gr_database/
    Server/
    Shared/
    Package.toml

  gr_characters/
    Server/
    Client/
    Shared/
    Package.toml

  gr_factions/
    Server/
    Client/
    Shared/
    Package.toml

  gr_inventory/
    Server/
    Client/
    Shared/
    Package.toml

  gr_economy/
    Server/
    Client/
    Shared/
    Package.toml

  gr_chat/
    Server/
    Client/
    Shared/
    Package.toml

  gr_admin/
    Server/
    Client/
    Shared/
    Package.toml

  gr_datapad_ui/
    Client/
    Package.toml

  gr_map_varkos/
    Package.toml
```

## 10.3 Principe de modularité

Chaque système doit être isolé :

- Le système de personnage ne doit pas contenir la logique d’économie.
- Le système de faction ne doit pas gérer directement les sanctions admin.
- Le système d’inventaire ne doit pas contenir des règles de mission.
- Les assets doivent être séparés de la logique.

Cette séparation évite de créer un monstre impossible à maintenir.

---

## 11. Base de données proposée

### Tables principales

#### players

- id
- steam_id ou identifiant joueur
- username
- first_join_at
- last_join_at
- is_banned
- ban_reason

#### characters

- id
- player_id
- first_name
- last_name
- age
- species
- biography
- faction_id
- rank_id
- money_cash
- money_bank
- position_x
- position_y
- position_z
- created_at
- updated_at

#### factions

- id
- name
- type
- description
- is_whitelisted

#### faction_ranks

- id
- faction_id
- name
- level
- permissions_json

#### inventory_items

- id
- character_id
- item_key
- quantity
- metadata_json

#### items

- key
- name
- description
- weight
- is_stackable
- is_illegal

#### bank_transactions

- id
- character_id
- amount
- type
- reason
- created_at

#### criminal_records

- id
- character_id
- officer_character_id
- charge
- fine_amount
- jail_time_minutes
- status
- created_at

#### properties

- id
- name
- type
- owner_character_id
- faction_id
- position_json

#### vehicles

- id
- owner_character_id
- model_key
- name
- state_json
- position_json

#### admin_logs

- id
- staff_player_id
- action
- target_player_id
- target_character_id
- details_json
- created_at

#### chat_logs

- id
- character_id
- channel
- message
- position_json
- created_at

---

## 12. Interfaces à prévoir

### Interfaces joueur

- Menu de création personnage.
- Sélection personnage.
- HUD léger.
- Datapad.
- Inventaire.
- Menu boutique.
- Menu banque.
- Menu faction.
- Menu véhicule.
- Notifications.

### Interfaces staff

- Menu admin.
- Téléportation.
- Spectate.
- Give item/argent.
- Gestion sanctions.
- Logs joueurs.
- Gestion personnages.
- Gestion factions.
- Gestion événements.

### Interfaces faction

- Liste membres.
- Grades.
- Promotions/rétrogradations.
- Coffre faction.
- Annonces internes.
- Missions faction.

---

## 13. Règles RP essentielles

### Règles de base

- Respect du RP obligatoire.
- Pas de freekill.
- Pas de metagaming.
- Pas de powergaming.
- Pas de fearRP irréaliste.
- Pas de revenge kill.
- Pas d’exploitation de bugs.
- Pas d’insultes hors RP.

### Règles factions

- Les factions sensibles nécessitent candidature.
- Les grades élevés nécessitent activité et sérieux.
- Les abus de pouvoir sont sanctionnés.
- Les décisions importantes doivent être traçables.

### Règles criminelles

- Braquages encadrés.
- Kidnapping limité.
- Meurtres justifiés RP.
- Marché noir surveillé par staff.

### Règles force-users

- Accès restreint.
- Pouvoirs soumis à validation.
- RP obligatoire avant combat.
- Perte de privilège possible en cas d’abus.

---

## 14. Staff et organisation humaine

### Rôles nécessaires

#### Owner / Product Owner

- Vision globale.
- Priorités.
- Décisions finales.
- Budget.

#### Lead Developer

- Architecture technique.
- Qualité du code.
- Revue des contributions.
- Déploiement.

#### Développeur Lua nanos world

- Packages gameplay.
- Events.
- Persistance.
- Intégration UI.

#### UI Developer

- Menus HTML/React.
- HUD.
- Datapad.

#### Level Designer / Map Designer

- Planètes.
- Zones RP.
- Optimisation des maps.

#### 3D Artist / Asset Integrator

- Props.
- Véhicules.
- Armures.
- Optimisation assets.

#### Game Designer RP

- Métiers.
- Économie.
- Progression.
- Équilibrage.

#### Lore Master

- Cohérence univers.
- Histoire globale.
- Événements.
- Validation backgrounds sensibles.

#### Admin / Modérateur

- Sanctions.
- Tickets.
- Conflits joueurs.
- Surveillance RP.

#### Community Manager

- Discord.
- Annonces.
- Recrutement.
- Communication.

---

## 15. Méthode de travail recommandée

### Outil Kanban

Trello, Jira, Linear, GitHub Projects ou Notion.

### Colonnes Kanban

- Idées
- Backlog
- À spécifier
- Prêt pour dev
- En cours
- Revue code / test
- Test en serveur dev
- Prêt production
- Terminé
- Bloqué

### Règles Kanban

- Une carte = une fonctionnalité claire.
- Chaque carte doit avoir des critères d’acceptation.
- Pas plus de 2 tâches en cours par développeur.
- Aucun ticket “énorme” en développement direct.
- Les bugs bloquants passent avant les features cosmétiques.

---

## 16. Backlog produit initial

## Epic 1 — Fondation serveur

### US-001 — Installer un serveur nanos world de développement

En tant que développeur, je veux lancer un serveur local pour tester rapidement les packages.

Critères d’acceptation :

- Le serveur démarre localement.
- Un joueur peut rejoindre.
- Les logs serveur sont visibles.
- Les packages de test se chargent correctement.

Priorité : Critique  
Complexité : S

### US-002 — Créer la structure des packages

En tant que développeur, je veux une architecture modulaire pour éviter un code désorganisé.

Critères d’acceptation :

- Les packages de base existent.
- Chaque package a son Package.toml.
- Chaque package a ses dossiers Server/Client/Shared si nécessaire.
- Un package core expose des constantes et helpers communs.

Priorité : Critique  
Complexité : M

### US-003 — Mettre en place la configuration serveur

Critères d’acceptation :

- Config.toml charge les bons packages.
- Les ports sont documentés.
- Le serveur dev et le serveur production sont séparés.
- Les variables sensibles ne sont pas commitées.

Priorité : Critique  
Complexité : S

---

## Epic 2 — Persistance et base de données

### US-004 — Choisir et connecter la base de données

En tant que développeur, je veux connecter PostgreSQL pour sauvegarder les données joueurs.

Critères d’acceptation :

- Connexion DB fonctionnelle.
- Test SELECT/INSERT OK.
- Erreurs DB loggées proprement.
- Identifiants DB sortis du code.

Priorité : Critique  
Complexité : M

### US-005 — Créer les tables de base

Critères d’acceptation :

- Tables players, characters, factions, ranks créées.
- Script SQL versionné.
- Données de test insérées.
- Documentation du schéma initial.

Priorité : Critique  
Complexité : M

### US-006 — Sauvegarder la position personnage

Critères d’acceptation :

- La position est sauvegardée à intervalle raisonnable.
- La position est restaurée à la reconnexion.
- En cas de position invalide, spawn fallback.

Priorité : Haute  
Complexité : M

---

## Epic 3 — Personnages

### US-007 — Création de personnage

Critères d’acceptation :

- Le joueur peut créer un personnage.
- Les champs obligatoires sont validés.
- Le personnage est sauvegardé.
- Le joueur arrive au spawn initial.

Priorité : Critique  
Complexité : L

### US-008 — Sélection de personnage

Critères d’acceptation :

- Le joueur voit ses personnages.
- Il peut choisir un personnage actif.
- Les données sont chargées correctement.
- Le joueur ne peut pas jouer sans personnage.

Priorité : Critique  
Complexité : M

### US-009 — Fiche personnage

Critères d’acceptation :

- Le joueur peut ouvrir son datapad.
- Il voit son identité RP.
- Il voit faction, grade, argent.
- Les données affichées sont cohérentes avec la DB.

Priorité : Haute  
Complexité : M

---

## Epic 4 — Chat RP

### US-010 — Chat local RP

Critères d’acceptation :

- Le message local n’est reçu que dans un rayon défini.
- Le nom RP du personnage est affiché.
- Les messages sont loggés.

Priorité : Critique  
Complexité : M

### US-011 — Commandes /me et /do

Critères d’acceptation :

- `/me` affiche une action RP.
- `/do` affiche une description RP.
- Les messages respectent la distance locale.
- Les abus peuvent être retrouvés dans les logs.

Priorité : Haute  
Complexité : S

### US-012 — Radio faction

Critères d’acceptation :

- Seuls les membres d’une faction voient le canal.
- Le canal peut être désactivé selon équipement.
- Les messages sont loggés.

Priorité : Moyenne  
Complexité : M

---

## Epic 5 — Factions et grades

### US-013 — Créer les factions de base

Critères d’acceptation :

- Les factions existent en base.
- Chaque faction a une description.
- Chaque faction a un type.
- Le joueur peut être assigné à une faction.

Priorité : Haute  
Complexité : M

### US-014 — Gestion des grades

Critères d’acceptation :

- Une faction possède des grades.
- Chaque grade a un niveau.
- Les permissions sont associées au grade.
- Les promotions/rétrogradations sont loggées.

Priorité : Haute  
Complexité : M

### US-015 — Menu faction

Critères d’acceptation :

- Un membre voit sa faction.
- Un officier voit la liste des membres.
- Un officier peut promouvoir/rétrograder selon permissions.
- Les actions sont sauvegardées.

Priorité : Moyenne  
Complexité : L

---

## Epic 6 — Inventaire

### US-016 — Inventaire simple

Critères d’acceptation :

- Le joueur peut ouvrir son inventaire.
- Les objets sont affichés.
- Les quantités sont correctes.
- Les données persistent après reconnexion.

Priorité : Haute  
Complexité : L

### US-017 — Donner un objet

Critères d’acceptation :

- Un joueur peut donner un objet à un joueur proche.
- La quantité est validée.
- L’action est loggée.
- Les deux inventaires sont mis à jour.

Priorité : Moyenne  
Complexité : M

### US-018 — Utiliser un objet

Critères d’acceptation :

- Un objet peut déclencher une action.
- Exemple : médikit soigne le joueur.
- L’objet peut être consommé.
- L’action est sécurisée côté serveur.

Priorité : Moyenne  
Complexité : M

---

## Epic 7 — Économie

### US-019 — Argent liquide et banque

Critères d’acceptation :

- Le joueur possède cash et banque.
- Les montants sont sauvegardés.
- Les montants ne peuvent pas être négatifs sauf cas prévu.
- Les transactions sont loggées.

Priorité : Haute  
Complexité : M

### US-020 — Paiement entre joueurs

Critères d’acceptation :

- Un joueur peut payer un joueur proche.
- Le serveur vérifie le solde.
- La transaction est atomique.
- Les deux joueurs reçoivent une notification.

Priorité : Moyenne  
Complexité : M

### US-021 — Salaire faction/métier

Critères d’acceptation :

- Les salaires sont configurables.
- Le salaire est versé à intervalle défini.
- Le joueur doit être actif.
- Les abus AFK sont limités.

Priorité : Moyenne  
Complexité : M

---

## Epic 8 — Administration et modération

### US-022 — Menu admin MVP

Critères d’acceptation :

- Liste des joueurs connectés.
- Téléportation vers joueur.
- Téléportation joueur vers soi.
- Kick.
- Ban temporaire.
- Logs basiques.

Priorité : Critique  
Complexité : L

### US-023 — Système de permissions staff

Critères d’acceptation :

- Les rôles staff sont définis.
- Chaque commande vérifie la permission.
- Les abus staff sont loggés.

Priorité : Critique  
Complexité : M

### US-024 — Logs disciplinaires

Critères d’acceptation :

- Les sanctions sont sauvegardées.
- Un staff peut consulter l’historique.
- Les logs contiennent date, staff, joueur, raison.

Priorité : Haute  
Complexité : M

---

## Epic 9 — Monde et map MVP

### US-025 — Créer le plan de la planète principale

Critères d’acceptation :

- Carte papier ou schéma produit.
- Zones RP listées.
- Points de spawn définis.
- Zones sensibles définies.

Priorité : Critique  
Complexité : M

### US-026 — Intégrer une première map jouable

Critères d’acceptation :

- La map charge sur serveur.
- Les joueurs spawnent correctement.
- Les collisions sont acceptables.
- Les performances sont testées avec plusieurs joueurs.

Priorité : Critique  
Complexité : XL

### US-027 — Ajouter props et zones interactives

Critères d’acceptation :

- Cantina identifiable.
- Spatioport identifiable.
- Administration identifiable.
- Zone criminelle identifiable.
- Interactions minimales disponibles.

Priorité : Haute  
Complexité : L

---

## Epic 10 — Métiers et missions

### US-028 — Métier transporteur

Critères d’acceptation :

- Le joueur prend une mission.
- Il récupère une cargaison.
- Il livre à un point donné.
- Il reçoit une récompense.
- L’action est loggée.

Priorité : Haute  
Complexité : L

### US-029 — Métier médecin

Critères d’acceptation :

- Le médecin peut soigner.
- Le soin nécessite un objet ou une compétence.
- Les joueurs inconscients peuvent être traités.
- Les abus sont limités.

Priorité : Moyenne  
Complexité : L

### US-030 — Métier mécanicien

Critères d’acceptation :

- Le mécanicien peut réparer un véhicule.
- La réparation consomme du temps ou ressource.
- Le joueur reçoit une rémunération possible.

Priorité : Moyenne  
Complexité : M

---

## Epic 11 — Système légal/criminalité

### US-031 — Casier judiciaire

Critères d’acceptation :

- Un agent autorisé peut ajouter une infraction.
- Le joueur peut recevoir une amende.
- Le casier est consultable selon permissions.
- Les modifications sont loggées.

Priorité : Moyenne  
Complexité : L

### US-032 — Menottes/arrestation

Critères d’acceptation :

- Un agent peut menotter un joueur proche.
- Le joueur menotté a des actions limitées.
- L’action est soumise à règles RP.
- Les abus sont loggés.

Priorité : Moyenne  
Complexité : M

### US-033 — Prison temporaire

Critères d’acceptation :

- Un joueur peut être envoyé en prison pour une durée.
- Il est libéré automatiquement.
- Le staff peut annuler en cas d’erreur.

Priorité : Basse MVP / Haute V2  
Complexité : M

---

## Epic 12 — Communication et communauté

### US-034 — Discord officiel

Critères d’acceptation :

- Discord structuré.
- Règlement visible.
- Salons tickets.
- Salons annonces.
- Salons candidatures.

Priorité : Critique  
Complexité : S

### US-035 — Règlement RP v1

Critères d’acceptation :

- Règlement lisible.
- Exemples concrets.
- Sanctions définies.
- Validation par l’équipe staff.

Priorité : Critique  
Complexité : M

### US-036 — Formulaire candidature faction sensible

Critères d’acceptation :

- Formulaire disponible.
- Questions RP et motivation.
- Process de validation défini.

Priorité : Moyenne  
Complexité : S

---

## 17. Roadmap recommandée

## Phase 0 — Préproduction, 1 à 2 semaines

Objectif : éviter de partir dans tous les sens.

Livrables :

- Vision projet.
- Nom temporaire.
- Liste factions MVP.
- Plan de la première planète.
- Règlement RP v0.1.
- Schéma DB initial.
- Kanban créé.
- Repo Git créé.

## Phase 1 — Prototype technique, 2 à 3 semaines

Objectif : vérifier que nanos world permet bien les systèmes essentiels.

Livrables :

- Serveur local.
- Package core.
- Connexion DB.
- Création personnage simple.
- Spawn personnage.
- Chat local.
- Sauvegarde position.

## Phase 2 — MVP fermé, 4 à 8 semaines

Objectif : serveur jouable par une petite équipe de test.

Livrables :

- Première map jouable.
- Factions.
- Inventaire.
- Argent.
- Admin menu.
- Règlement.
- Discord.
- Tests staff.

## Phase 3 — Alpha communautaire, 4 à 6 semaines

Objectif : accueillir une petite communauté contrôlée.

Livrables :

- Candidatures factions.
- Métiers MVP.
- Logs améliorés.
- Corrections bugs.
- Events scénarisés.
- Optimisation performances.

## Phase 4 — Bêta publique

Objectif : ouvrir plus largement.

Livrables :

- Site ou page de présentation.
- Trailer/screenshots.
- Guide débutant.
- Boutique si légale et non pay-to-win.
- Monitoring serveur.
- Backups automatiques.

## Phase 5 — Expansion

Objectif : ajouter du contenu sans casser la base.

Livrables :

- Deuxième planète.
- Système de transport interplanétaire.
- Pouvoirs mystiques avancés.
- Politique avancée.
- Marché noir.
- Crafting.

---

## 18. Sprint 1 recommandé

Durée : 1 semaine.

Objectif : obtenir une base technique propre.

### Tâches Sprint 1

1. Créer le repo Git.
2. Créer la structure des dossiers serveur.
3. Installer serveur nanos world local.
4. Créer package `gr_core`.
5. Créer package `gr_database`.
6. Tester connexion DB.
7. Créer script SQL initial.
8. Créer package `gr_characters`.
9. Faire un spawn simple.
10. Documenter lancement local.

### Définition de terminé

- Un nouveau développeur peut cloner le repo et lancer le serveur dev avec la documentation.
- Le serveur démarre sans erreur critique.
- Un joueur peut rejoindre.
- Une connexion DB est testée.
- Les premiers packages se chargent.

---

## 19. Sprint 2 recommandé

Durée : 1 à 2 semaines.

Objectif : permettre à un joueur de créer et charger son personnage.

### Tâches Sprint 2

1. Créer table players.
2. Créer table characters.
3. Identifier joueur à la connexion.
4. Afficher menu création personnage.
5. Sauvegarder personnage.
6. Sélectionner personnage.
7. Spawn selon personnage actif.
8. Sauvegarder position.
9. Ajouter logs de connexion.

### Définition de terminé

- Le joueur ne peut pas jouer sans personnage.
- Le personnage persiste après reconnexion.
- Les données sont visibles côté serveur.
- Les erreurs sont loggées proprement.

---

## 20. Sprint 3 recommandé

Durée : 1 à 2 semaines.

Objectif : poser les bases RP.

### Tâches Sprint 3

1. Chat local.
2. Commandes `/me` et `/do`.
3. Factions initiales.
4. Grades initiales.
5. Assignation staff d’un joueur à une faction.
6. Spawn faction.
7. Datapad minimal.
8. Règlement RP v1.

### Définition de terminé

- Une session RP simple est possible.
- Les joueurs peuvent parler localement.
- Les factions existent.
- Le staff peut tester une scène RP encadrée.

---

## 21. Risques majeurs

### Risque 1 — Trop grand scope

Symptôme : vouloir 5 planètes, vaisseaux, Jedi/Sith, politique, économie complète dès le début.

Solution : MVP strict avec une seule planète.

### Risque 2 — Problème légal Star Wars

Symptôme : utilisation directe du nom, logos, musiques, modèles officiels.

Solution : identité originale inspirée, assets propres ou licenciés.

### Risque 3 — Manque d’équipe assets

Symptôme : serveur vide ou moche, ou usage d’assets volés.

Solution : commencer petit, acheter/créer des assets légaux, styliser au lieu de copier.

### Risque 4 — Staff toxique

Symptôme : favoritisme, abus de pouvoirs, sanctions injustes.

Solution : logs staff, règles internes, hiérarchie claire, transparence.

### Risque 5 — RP détruit par le PvP

Symptôme : le serveur devient un deathmatch.

Solution : règles strictes, systèmes d’inconscience, sanctions rapides, récompense du RP civil.

### Risque 6 — Dette technique

Symptôme : tout est codé dans un seul fichier, impossible d’ajouter une feature.

Solution : packages modulaires, conventions, revue de code.

---

## 22. Budget à prévoir

### Budget minimal

- Hébergement serveur : selon charge.
- Nom de domaine éventuel.
- Assets libres ou petits packs légalement utilisables.
- Temps de développement personnel.

### Budget sérieux

- VPS ou serveur dédié.
- Sauvegardes.
- Assets 3D payants.
- UI designer ponctuel.
- Logo/identité visuelle originale.
- Éventuellement site web.

### Budget à éviter

Ne pas payer trop tôt pour des assets ou un serveur puissant avant d’avoir validé le prototype technique.

---

## 23. Ce dont j’ai besoin de vous pour avancer précisément

Pour transformer ce cadrage en plan opérationnel très concret, il faudra décider :

1. Voulez-vous rester officiellement sur “Star Wars RP” ou créer une marque originale inspirée ?
2. Combien de personnes seront dans l’équipe au début ?
3. Qui développe ? Vous seul ou plusieurs personnes ?
4. Voulez-vous PostgreSQL dès le début ou SQLite pour prototype ?
5. Voulez-vous commencer par une map simple ou importer/créer une vraie planète ?
6. Le serveur sera-t-il strict RP ou semi-RP ?
7. Voulez-vous des force-users dès le MVP ou seulement plus tard ?
8. Quel est votre budget mensuel maximum ?
9. Voulez-vous monétiser un jour ?
10. Voulez-vous un Discord et des candidatures dès le lancement ?

---

## 24. Décision recommandée maintenant

Pour réussir, la meilleure décision est :

> Construire d’abord un serveur RP galactique original avec une seule planète, trois factions fortes, création personnage, chat RP, inventaire, argent, métiers simples, menu admin et persistance DB.

Ensuite seulement :

- ajouter les pouvoirs mystiques,
- ajouter les planètes,
- ajouter les vaisseaux,
- ajouter la politique avancée,
- ajouter les grands événements.

Ce projet peut devenir excellent, mais seulement si vous résistez à l’envie de tout faire en même temps.

---

## 25. Kanban initial prêt à copier

### Idées

- Combat spatial.
- Deuxième planète jungle.
- Système politique avancé.
- Crafting avancé.
- Ordre mystique complet.
- Marché noir dynamique.

### Backlog

- Création personnage.
- Persistance DB.
- Chat local.
- Factions.
- Inventaire.
- Économie.
- Admin menu.
- Première map.
- Métiers MVP.
- Règlement RP.

### À spécifier

- Liste exacte des factions.
- Liste exacte des métiers MVP.
- Choix DB.
- Choix nom public.
- Règles force-users.
- Règles criminalité.

### Prêt pour dev

- Installer serveur dev.
- Créer repo Git.
- Créer package core.
- Créer package database.
- Créer script SQL initial.

### En cours

À remplir selon l’équipe.

### Revue code / test

À remplir après premières tâches dev.

### Test serveur dev

À remplir après prototype.

### Prêt production

À remplir quand les fonctionnalités sont validées.

### Terminé

À remplir progressivement.

### Bloqué

À remplir avec cause précise : technique, asset, décision, bug, manque info.

---

## 26. Backlog priorisé MVP

| Priorité | Ticket | Intitulé | Type | Complexité |
|---|---|---|---|---|
| P0 | US-001 | Installer serveur nanos world dev | Technique | S |
| P0 | US-002 | Créer structure packages | Technique | M |
| P0 | US-004 | Connecter base de données | Technique | M |
| P0 | US-005 | Créer tables de base | Technique | M |
| P0 | US-007 | Création personnage | Feature | L |
| P0 | US-008 | Sélection personnage | Feature | M |
| P0 | US-010 | Chat local RP | Feature | M |
| P0 | US-022 | Menu admin MVP | Feature | L |
| P0 | US-025 | Plan planète principale | Design | M |
| P0 | US-034 | Discord officiel | Communauté | S |
| P0 | US-035 | Règlement RP v1 | Communauté | M |
| P1 | US-013 | Factions de base | Feature | M |
| P1 | US-014 | Grades faction | Feature | M |
| P1 | US-016 | Inventaire simple | Feature | L |
| P1 | US-019 | Argent banque/cash | Feature | M |
| P1 | US-026 | Première map jouable | Asset/Map | XL |
| P2 | US-028 | Métier transporteur | Feature | L |
| P2 | US-031 | Casier judiciaire | Feature | L |
| P2 | US-012 | Radio faction | Feature | M |
| P3 | US-033 | Prison temporaire | Feature | M |

---

## 27. Conclusion stratégique

Le bon chemin n’est pas de commencer par “recréer tout Star Wars”. Le bon chemin est de créer une base RP galactique solide, originale, modulaire et fun, puis de l’enrichir.

Votre avantage peut être énorme si vous faites mieux que les autres serveurs RP sur trois points :

1. Une vraie stabilité technique.
2. Des règles RP claires et appliquées.
3. Des systèmes qui donnent du jeu aux civils, pas seulement aux combattants.

Si ces trois points sont réussis, le serveur aura une vraie chance de se démarquer.


---

# Addendum V0.2 — Refonte gameplay RPG/RP systémique

Objectif : transformer le serveur en véritable RPG social et RP, pas seulement en sandbox avec factions. Le joueur doit avoir une progression claire, des choix de spécialisation, des objectifs quotidiens, une identité de classe, des compétences qui montent avec l’usage, du craft utile, des quêtes scénarisées et des mécaniques sociales fortes.

---

## 28. Nouvelle vision gameplay

Le serveur doit mélanger trois couches :

1. **RP social** : factions, dialogues, politique, métiers, événements, réputation.
2. **RPG progression** : niveaux, classes, compétences, talents, équipements, craft.
3. **Sandbox émergente** : joueurs qui créent leurs histoires grâce aux systèmes.

La bonne formule :

> Le RP donne le sens, le RPG donne la progression, le sandbox donne la liberté.

Le joueur doit se connecter en sachant quoi faire, mais sans être prisonnier d’un chemin unique.

---

## 29. Boucle de jeu principale

### Boucle courte — 5 à 15 minutes

- Prendre une activité ou quête.
- Se déplacer vers une zone.
- Interagir avec PNJ, joueur, terminal ou ressource.
- Gagner XP, argent, réputation, matériau ou information.
- Revenir vendre, valider, crafter ou améliorer.

### Boucle moyenne — 30 à 90 minutes

- Participer à une mission de faction.
- Faire une livraison risquée.
- Fabriquer un équipement.
- Monter une compétence.
- Enquêter sur un joueur ou une faction.
- Participer à une opération militaire/criminelle.

### Boucle longue — plusieurs jours/semaines

- Monter une classe.
- Débloquer une spécialisation.
- Monter en grade dans une faction.
- Développer une entreprise.
- Obtenir une réputation rare.
- Débloquer une capacité avancée.
- Participer à l’évolution politique de la planète.

---

## 30. Piliers du nouveau gameplay

### Pilier 1 — Le joueur est défini par ses choix

Un joueur ne doit pas être bon partout. Il doit choisir une voie.

Exemples :

- Soldat spécialisé armes lourdes.
- Médecin de terrain.
- Mécanicien de vaisseaux.
- Marchand influent.
- Contrebandier discret.
- Espion social.
- Artisan d’armes énergétiques.
- Mystique rare avec discipline mentale.

### Pilier 2 — Les compétences montent par la pratique

Un médecin progresse en soignant. Un mécanicien progresse en réparant. Un pilote progresse en pilotant. Cela rend la progression logique et immersive.

### Pilier 3 — Le craft doit alimenter l’économie

Le craft ne doit pas être décoratif. Il doit produire des objets utiles que les joueurs veulent vraiment acheter : armes, armures, composants, médikits, drogues, faux papiers, modules de véhicules, outils, ressources rares.

### Pilier 4 — Les factions créent du pouvoir social

Les factions ne doivent pas seulement donner un uniforme. Elles doivent donner accès à des droits, territoires, missions, budgets, grades, technologies et informations.

### Pilier 5 — Les quêtes doivent provoquer du RP

Une quête ne doit pas être seulement “va tuer 10 mobs”. Elle doit amener les joueurs dans des zones de conflit, de commerce, d’enquête, de négociation ou de danger.

---

## 31. Système de classes

## 31.1 Classes de départ

Au début, le joueur choisit une **orientation de carrière**. Ce choix donne des bonus légers, des quêtes de départ et une progression préférentielle, mais ne bloque pas tout le reste.

### Classe 1 — Recrue militaire

Rôle : combat, discipline, protection, opérations.

Bonus :

- +5% XP armes légères.
- Accès aux quêtes d’entraînement militaire.
- Meilleure résistance au stress de combat.

Compétences principales :

- Armes légères.
- Armes lourdes.
- Tactique.
- Discipline.
- Survie.

### Classe 2 — Médecin / biologiste

Rôle : soin, réanimation, recherche, drogues légales/illégales.

Bonus :

- +10% efficacité médikit basique.
- Accès aux quêtes médicales.
- Peut identifier certains états corporels.

Compétences principales :

- Médecine.
- Chirurgie de terrain.
- Biochimie.
- Diagnostic.
- Pharmacologie.

### Classe 3 — Ingénieur / mécanicien

Rôle : réparation, craft technique, véhicules, énergie.

Bonus :

- +5% vitesse réparation.
- Accès aux plans de craft techniques basiques.
- Peut diagnostiquer les véhicules/équipements.

Compétences principales :

- Mécanique.
- Électronique.
- Fabrication.
- Réparation véhicule.
- Piratage technique.

### Classe 4 — Marchand / logisticien

Rôle : économie, commerce, contrats, transport.

Bonus :

- +5% gain missions commerciales.
- Accès aux contrats de livraison.
- Meilleur prix auprès de certains vendeurs.

Compétences principales :

- Commerce.
- Négociation.
- Logistique.
- Réputation commerciale.
- Gestion d’entreprise.

### Classe 5 — Contrebandier / criminel

Rôle : infiltration, marché noir, discrétion, faux documents.

Bonus :

- Accès à certains contacts illégaux.
- +5% XP discrétion.
- Peut repérer certains points de contrebande.

Compétences principales :

- Discrétion.
- Crochetage/piratage.
- Contrebande.
- Intimidation.
- Falsification.

### Classe 6 — Explorateur / récupérateur

Rôle : exploration, récolte, ruines, ressources rares.

Bonus :

- +5% chance de trouver ressources rares.
- Meilleure orientation hors ville.
- Accès aux quêtes de récupération.

Compétences principales :

- Exploration.
- Survie.
- Récolte.
- Analyse d’artefacts.
- Cartographie.

### Classe 7 — Sensible mystique

Rôle : voie rare, discipline, pouvoirs, lore.

Accès recommandé : non disponible en création libre au MVP public. Déblocage via RP, candidature, événement ou décision staff lore.

Compétences principales :

- Discipline mentale.
- Perception.
- Maîtrise énergétique.
- Méditation.
- Combat rituel.

---

## 31.2 Spécialisations avancées

À partir d’un certain niveau, le joueur choisit une spécialisation.

### Recrue militaire

- Tireur d’élite.
- Soldat lourd.
- Officier tactique.
- Commando.
- Garde d’élite.

### Médecin

- Chirurgien de terrain.
- Pharmacologue.
- Médecin militaire.
- Chercheur biologique.
- Dealer biochimiste côté illégal.

### Ingénieur

- Armurier.
- Mécanicien véhicules.
- Technicien énergie.
- Hacker.
- Fabricant de drones/outils.

### Marchand

- Transporteur longue distance.
- Courtier.
- Industriel.
- Contremaître.
- Banquier/financier RP.

### Contrebandier

- Faussaire.
- Infiltrateur.
- Trafiquant.
- Assassin RP encadré.
- Pirate informatique.

### Explorateur

- Archéologue.
- Chasseur de primes explorateur.
- Prospecteur.
- Cartographe.
- Pisteur.

---

## 32. Système de niveaux

## 32.1 Niveau général

Le niveau général représente l’expérience globale du personnage.

Sources d’XP :

- Quêtes.
- Métiers.
- Craft.
- Exploration.
- Participation à événements.
- Actions RP validées.
- Missions faction.

Règle importante : le niveau général ne doit pas rendre le joueur invincible. Il doit surtout débloquer des possibilités, pas créer un écart impossible entre ancien et nouveau joueur.

### Proposition de niveaux

- Niveau 1 à 10 : débutant, apprentissage.
- Niveau 11 à 25 : joueur confirmé.
- Niveau 26 à 40 : spécialiste.
- Niveau 41 à 60 : vétéran.
- Niveau 61+ : prestige, réputation, cosmétique, responsabilités.

### Déblocages par niveau

- Niveau 3 : accès métier secondaire.
- Niveau 5 : premier talent passif.
- Niveau 10 : choix spécialisation.
- Niveau 15 : accès craft intermédiaire.
- Niveau 20 : licence avancée selon RP.
- Niveau 30 : rôle de mentor possible.
- Niveau 40 : accès responsabilités faction avancées.
- Niveau 60 : prestige/cosmétique/titre.

---

## 32.2 XP anti-farm

Pour éviter que les joueurs montent niveau en boucle sans RP :

- Diminution d’XP sur action répétée.
- Bonus d’XP sur diversité d’activités.
- Plafond d’XP quotidien souple.
- Bonus d’XP événement/staff.
- XP métier séparée de l’XP générale.
- Certaines progressions nécessitent validation RP.

Exemple : faire 100 livraisons identiques ne doit pas être meilleur que participer à une vraie scène RP + mission + commerce.

---

## 33. Système de compétences

Les compétences montent indépendamment du niveau général.

### Catégories de compétences

#### Combat

- Armes légères.
- Armes lourdes.
- Tir de précision.
- Défense.
- Endurance.
- Tactique.

#### Social

- Négociation.
- Intimidation.
- Charisme.
- Commandement.
- Diplomatie.
- Tromperie.

#### Technique

- Mécanique.
- Électronique.
- Piratage.
- Fabrication.
- Maintenance énergétique.
- Ingénierie véhicules.

#### Médical

- Premiers secours.
- Chirurgie.
- Biochimie.
- Diagnostic.
- Stabilisation.

#### Exploration

- Survie.
- Récolte.
- Analyse d’artefacts.
- Cartographie.
- Détection.

#### Illégal

- Crochetage.
- Falsification.
- Contrebande.
- Discrétion.
- Blanchiment.

#### Mystique

- Perception.
- Méditation.
- Discipline mentale.
- Canalisation énergétique.
- Combat rituel.

---

## 33.1 Progression par usage

Chaque compétence gagne de l’XP quand le joueur fait une action pertinente.

Exemples :

- Soigner un joueur blessé donne XP médecine.
- Réparer un véhicule donne XP mécanique.
- Fabriquer une arme donne XP fabrication.
- Pirater un terminal donne XP piratage.
- Négocier via système de contrat donne XP commerce/négociation.
- Explorer une ruine donne XP exploration.

### Anti-abus

- Cooldown par action.
- Gain réduit sur même cible.
- Détection d’action répétée.
- XP seulement si l’action a une conséquence réelle.
- Certaines actions doivent être validées côté serveur.

---

## 34. Arbres de talents

Chaque spécialisation possède un arbre de talents.

### Exemple — Ingénieur Armurier

#### Branche Qualité

- Niveau 1 : réduit les défauts de craft.
- Niveau 2 : augmente la durabilité des armes craftées.
- Niveau 3 : débloque les armes personnalisées.

#### Branche Production

- Niveau 1 : craft plus rapide.
- Niveau 2 : réduction légère des matériaux.
- Niveau 3 : production en lot.

#### Branche Expérimental

- Niveau 1 : modules instables.
- Niveau 2 : bonus aléatoires.
- Niveau 3 : prototypes rares.

### Exemple — Médecin de terrain

#### Branche Urgence

- Stabilisation plus rapide.
- Réanimation plus fiable.
- Soins sous pression.

#### Branche Pharmacie

- Médicaments plus efficaces.
- Stimulants temporaires.
- Antidotes.

#### Branche Chirurgie

- Réduction des séquelles.
- Traitement blessures graves.
- Implants médicaux.

---

## 35. Système de quêtes

## 35.1 Types de quêtes

### Quêtes personnelles

Liées au personnage, à sa classe ou à son background.

Exemples :

- Retrouver un contact disparu.
- Prouver sa valeur auprès d’une faction.
- Rembourser une dette.
- Obtenir une licence.

### Quêtes de faction

Liées aux objectifs d’une faction.

Exemples :

- Patrouiller une zone.
- Protéger un convoi.
- Interroger un suspect.
- Saboter une antenne ennemie.
- Convoyer une cargaison sensible.

### Quêtes économiques

Liées aux métiers et ressources.

Exemples :

- Livrer du carburant.
- Réparer des générateurs.
- Fabriquer des composants.
- Récupérer des matériaux dans une zone dangereuse.

### Quêtes dynamiques

Générées selon l’état du serveur.

Exemples :

- Pénurie médicale : les médecins gagnent plus.
- Convoi attaqué : sécurité et criminels reçoivent des objectifs opposés.
- Zone contaminée : explorateurs et médecins utiles.
- Marché noir actif : contrebandiers et autorités entrent en conflit.

### Quêtes événementielles

Créées par le staff pour faire avancer le lore.

Exemples :

- Découverte d’un artefact.
- Assassinat politique.
- Coupure énergétique globale.
- Épidémie.
- Arrivée d’une flotte ennemie.

---

## 35.2 Structure d’une quête

Chaque quête doit avoir :

- Titre.
- Description RP.
- Donneur de quête.
- Conditions d’accès.
- Objectifs.
- Récompenses.
- Risques.
- Conséquences possibles.
- Logs.

Exemple :

```txt
Quête : Convoi médical vers les bas-fonds
Type : faction / médical / sécurité
Conditions : médecin niveau 5 ou escorte militaire
Objectif : transporter 3 caisses médicales vers la clinique clandestine
Risque : attaque criminelle possible
Récompense : argent, XP médecine, réputation locale
Conséquence : améliore temporairement l’offre de soins des bas-fonds
```

---

## 36. Crafting

## 36.1 Philosophie du craft

Le craft doit créer une interdépendance entre joueurs.

Un soldat a besoin d’un armurier.  
Un armurier a besoin de récupérateurs.  
Un médecin a besoin de biochimistes.  
Un contrebandier a besoin de faussaires.  
Un marchand a besoin de transporteurs.  

C’est comme ça qu’on crée du RP naturel.

---

## 36.2 Ressources

### Ressources communes

- Ferraille.
- Composants électroniques.
- Fibres synthétiques.
- Alliage léger.
- Produits médicaux.
- Carburant.

### Ressources rares

- Cristal énergétique.
- Circuit militaire.
- Métal renforcé.
- Tissu furtif.
- Noyau de générateur.
- Artefact ancien.

### Ressources illégales

- Produit narcotique.
- Puce de falsification.
- Identité vierge.
- Module de brouillage.
- Arme non enregistrée.

---

## 36.3 Catégories de craft

### Armurerie

- Pistolets.
- Fusils.
- Modules d’armes.
- Chargeurs spéciaux.
- Armes énergétiques rares.

### Armures

- Tenue civile renforcée.
- Armure légère.
- Armure tactique.
- Armure lourde.
- Tenue furtive.

### Médecine

- Médikits.
- Bandages.
- Antidotes.
- Stimulants.
- Implants médicaux.

### Technologie

- Radios.
- Scanners.
- Outils de piratage.
- Balises.
- Modules de véhicule.

### Contrebande

- Faux papiers.
- Caches d’objets.
- Brouilleurs.
- Caisses camouflées.
- Produits interdits.

### Mystique

- Artefacts.
- Catalyseurs.
- Focus énergétique.
- Lames énergétiques rares.

---

## 36.4 Qualité d’objet

Chaque objet crafté peut avoir une qualité.

- Commun.
- Amélioré.
- Rare.
- Prototype.
- Légendaire RP.

La qualité dépend :

- Compétence du crafter.
- Qualité des ressources.
- Station utilisée.
- Plan connu.
- Talent débloqué.
- Risque d’échec.

---

## 36.5 Plans de craft

Les objets avancés nécessitent des plans.

Sources de plans :

- Quêtes.
- Factions.
- Marché noir.
- Exploration.
- Recherche.
- Boss/event.
- Récompense staff lore.

Un plan rare est un vrai levier RP : il peut créer du commerce, du vol, de la protection ou des alliances.

---

## 37. HUD et UX

## 37.1 Philosophie HUD

Le HUD doit être immersif et minimal. L’écran ne doit pas ressembler à un MMORPG surchargé.

Le HUD doit donner les infos vitales sans casser le RP.

### HUD permanent recommandé

- Santé.
- État physique : blessé, inconscient, empoisonné, fatigué.
- Argent liquide discret.
- Radio active.
- Objectif de quête actif.
- Notification RP courte.
- Indicateur de zone : civil, danger, faction, interdit.

### À éviter

- Mini-map trop assistée.
- Barres partout.
- Popups constants.
- Gros chiffres de dégâts façon MMO.
- Interface trop arcade.

---

## 37.2 Datapad central

Le datapad devient le menu principal immersif.

Onglets :

1. Identité.
2. Classe.
3. Niveau.
4. Compétences.
5. Quêtes.
6. Inventaire.
7. Craft.
8. Faction.
9. Réputation.
10. Contrats.
11. Messages.
12. Carte simplifiée.

### Règle UX

Toutes les mécaniques RPG doivent passer par le datapad plutôt que par 20 menus différents.

---

## 37.3 UI de progression

### Écran classe

- Classe actuelle.
- Spécialisation.
- Niveau général.
- XP actuelle.
- Talents disponibles.

### Écran compétences

- Liste des compétences.
- Niveau par compétence.
- Barre de progression.
- Dernière action ayant donné XP.
- Bonus débloqués.

### Écran craft

- Catégories.
- Plans connus.
- Ressources nécessaires.
- Chance de qualité.
- Durée de fabrication.
- Station requise.

### Écran quêtes

- Quêtes actives.
- Quêtes de faction.
- Quêtes métier.
- Quêtes événementielles.
- Récompenses.
- Statut.

---

## 38. Réputation

La réputation doit être aussi importante que le niveau.

### Réputations proposées

- Gouvernement local.
- Armée.
- Guilde marchande.
- Bas-fonds.
- Syndicat criminel.
- Médecins.
- Ingénieurs.
- Explorateurs.
- Ordre mystique.

### Effets de réputation

- Accès à des quêtes.
- Meilleurs prix.
- Accès zones.
- Autorisations.
- Plans de craft.
- Titres RP.
- Risques d’hostilité.

### Exemple

Un joueur très réputé auprès du syndicat criminel peut obtenir des missions illégales rares, mais être davantage surveillé par le gouvernement.

---

## 39. Système de réputation morale / alignement

Attention : il ne faut pas faire un système simpliste “gentil/méchant”. Il faut plutôt créer des axes.

### Axes possibles

- Loi ↔ Hors-la-loi.
- Altruisme ↔ Intérêt personnel.
- Discipline ↔ Chaos.
- Public ↔ Secret.
- Tradition ↔ Technologie.

Ces axes peuvent influencer :

- Certaines quêtes.
- Certains dialogues.
- Certains accès faction.
- Certaines capacités mystiques.
- La perception des PNJ/factions.

---

## 40. Progression faction

Chaque faction doit avoir sa propre progression.

### Exemple militaire

- Recrue.
- Soldat.
- Caporal.
- Sergent.
- Lieutenant.
- Capitaine.
- Commandant.

Progression basée sur :

- Missions réussies.
- Présence RP.
- Discipline.
- Validation officier.
- Événements.

### Exemple criminel

- Contact.
- Coursier.
- Vendeur.
- Exécuteur.
- Lieutenant.
- Bras droit.
- Chef de cellule.

Progression basée sur :

- Livraison illégale.
- Discrétion.
- Influence.
- Argent généré.
- Loyauté RP.

---

## 41. Système de contrats joueurs

Les joueurs doivent pouvoir créer des contrats entre eux.

Types de contrats :

- Livraison.
- Protection.
- Réparation.
- Fabrication.
- Prime.
- Information.
- Transport.
- Soins.

Chaque contrat doit avoir :

- Donneur.
- Preneur.
- Objectif.
- Récompense.
- Deadline.
- Statut.
- Validation.

Cela donne du RP même sans staff connecté.

---

## 42. Système de blessures

Pour éviter le deathmatch, il faut un système de blessures plus intéressant qu’une simple mort.

### États possibles

- Blessure légère.
- Saignement.
- Fracture.
- Brûlure énergétique.
- Empoisonnement.
- Inconscience.
- Trauma.

### Effets

- Vitesse réduite.
- Viseur moins stable.
- Impossibilité de courir.
- Besoin de traitement médical.
- Risque de séquelle temporaire.

### Intérêt RP

Les médecins deviennent indispensables. Le combat a des conséquences. Les joueurs réfléchissent avant de tirer.

---

## 43. Système de craft + économie dynamique

Le serveur doit éviter les boutiques qui vendent tout directement. Sinon les artisans ne servent à rien.

### Règle recommandée

- Les PNJ vendent le basique.
- Les joueurs craftent le bon matériel.
- Les objets rares viennent des quêtes, événements, explorations ou factions.

### Flux économique

1. Explorateurs récupèrent ressources.
2. Transporteurs déplacent ressources.
3. Artisans fabriquent objets.
4. Marchands vendent.
5. Factions achètent en masse.
6. Criminels volent ou contrefont.
7. Gouvernement taxe ou contrôle.

---

## 44. Données à persister en base

Pour supporter ces systèmes, ajouter progressivement :

### character_progression

- character_id
- level
- current_xp
- total_xp
- class_key
- specialization_key
- unspent_talent_points

### character_skills

- character_id
- skill_key
- level
- xp
- last_gain_at

### talents

- key
- specialization_key
- name
- description
- max_rank
- prerequisites_json

### character_talents

- character_id
- talent_key
- rank

### quests

- id
- key
- type
- title
- description
- conditions_json
- rewards_json

### character_quests

- character_id
- quest_key
- status
- progress_json
- started_at
- completed_at

### crafting_recipes

- key
- category
- result_item_key
- required_skill_key
- required_skill_level
- ingredients_json
- station_key
- duration_seconds

### character_recipes

- character_id
- recipe_key
- learned_at

### reputations

- character_id
- reputation_key
- value
- rank

### contracts

- id
- creator_character_id
- assignee_character_id
- type
- title
- description
- reward_money
- status
- deadline_at

---

## 45. Packages techniques à ajouter

Pour cette vision RPG/RP, ajouter ces packages :

```txt
Packages/
  gr_progression/
  gr_skills/
  gr_talents/
  gr_quests/
  gr_crafting/
  gr_reputation/
  gr_contracts/
  gr_injuries/
  gr_hud/
  gr_datapad/
```

### Responsabilité par package

#### gr_progression

- Niveau général.
- XP globale.
- Paliers.
- Points de talent.

#### gr_skills

- XP compétence.
- Niveau compétence.
- Anti-farm.
- Bonus passifs.

#### gr_talents

- Arbres de talents.
- Conditions.
- Achat de talents.
- Effets actifs/passifs.

#### gr_quests

- Quêtes.
- Objectifs.
- Progression.
- Récompenses.

#### gr_crafting

- Recettes.
- Stations.
- Ressources.
- Qualité.
- File de craft.

#### gr_reputation

- Réputation faction.
- Déblocages.
- Malus.

#### gr_contracts

- Contrats entre joueurs.
- Validation.
- Paiements.

#### gr_injuries

- Blessures.
- États corporels.
- Soins.
- Séquelles temporaires.

#### gr_hud

- HUD minimal.
- Notifications.
- État joueur.

#### gr_datapad

- Interface principale.
- Navigation entre systèmes.

---

## 46. MVP RPG réaliste

Même si l’ambition est grande, le premier MVP RPG doit rester maîtrisé.

### MVP RPG recommandé

- 6 classes de départ.
- Niveau général jusqu’à 20.
- 12 compétences maximum.
- 1 spécialisation par classe, ou spécialisation bloquée pour V2.
- 20 recettes de craft.
- 15 quêtes simples.
- 5 quêtes dynamiques.
- 5 réputations.
- HUD minimal.
- Datapad avec 5 onglets : identité, progression, quêtes, inventaire, craft.
- Blessures simples : léger, saignement, inconscient.

### À ne pas mettre dans le MVP RPG

- Arbres de talents énormes.
- 100 recettes.
- 50 quêtes scénarisées.
- Équilibrage parfait.
- Pouvoirs mystiques complets.
- Combat spatial complet.
- Réputation politique trop complexe.

---

## 47. Backlog supplémentaire RPG

### Epic 13 — Progression RPG

#### US-037 — Ajouter niveau général personnage

Critères d’acceptation :

- Chaque personnage a un niveau.
- Le niveau est sauvegardé.
- L’XP augmente via une fonction serveur sécurisée.
- Un level-up déclenche une notification.

Priorité : P0  
Complexité : M

#### US-038 — Ajouter classes de départ

Critères d’acceptation :

- Le joueur choisit une classe à la création.
- La classe est sauvegardée.
- La classe donne des bonus de départ.
- La classe s’affiche dans le datapad.

Priorité : P0  
Complexité : M

#### US-039 — Ajouter compétences par usage

Critères d’acceptation :

- Une compétence peut gagner de l’XP.
- La compétence peut monter de niveau.
- Les gains sont limités anti-farm.
- Les compétences sont affichées dans le datapad.

Priorité : P0  
Complexité : L

---

### Epic 14 — HUD et datapad

#### US-040 — HUD minimal RPG

Critères d’acceptation :

- Santé visible.
- État physique visible.
- Quête active visible.
- Notifications propres.
- HUD désactivable/configurable.

Priorité : P0  
Complexité : L

#### US-041 — Datapad progression

Critères d’acceptation :

- Le joueur ouvre le datapad.
- Il voit niveau, classe, XP.
- Il voit ses compétences.
- Les données viennent du serveur.

Priorité : P0  
Complexité : L

#### US-042 — Datapad quêtes

Critères d’acceptation :

- Le joueur voit ses quêtes actives.
- Il voit les objectifs.
- Il voit les récompenses.
- La progression se met à jour.

Priorité : P1  
Complexité : M

---

### Epic 15 — Quêtes

#### US-043 — Moteur de quêtes simple

Critères d’acceptation :

- Une quête peut être démarrée.
- Une quête a des objectifs.
- Une quête peut être complétée.
- Les récompenses sont distribuées côté serveur.

Priorité : P0  
Complexité : L

#### US-044 — Quêtes de classe débutant

Critères d’acceptation :

- Chaque classe a au moins une quête de départ.
- La quête enseigne une mécanique.
- La récompense donne XP et argent.

Priorité : P1  
Complexité : M

#### US-045 — Quêtes dynamiques serveur

Critères d’acceptation :

- Le serveur peut générer une quête selon un événement.
- Les joueurs concernés reçoivent une notification.
- La quête expire après un délai.

Priorité : P2  
Complexité : L

---

### Epic 16 — Craft

#### US-046 — Moteur de recettes

Critères d’acceptation :

- Une recette définit ingrédients, résultat et compétence requise.
- Le serveur vérifie les ressources.
- Le craft retire les ingrédients.
- Le résultat est ajouté à l’inventaire.

Priorité : P0  
Complexité : L

#### US-047 — Stations de craft

Critères d’acceptation :

- Certaines recettes nécessitent une station.
- Le joueur doit être proche de la station.
- Les stations sont placées en map.

Priorité : P1  
Complexité : M

#### US-048 — Qualité des objets craftés

Critères d’acceptation :

- Le craft peut produire différentes qualités.
- La qualité dépend de la compétence et des matériaux.
- La qualité est sauvegardée dans metadata_json.

Priorité : P2  
Complexité : M

---

### Epic 17 — Réputation et contrats

#### US-049 — Réputation faction

Critères d’acceptation :

- Une action peut modifier une réputation.
- La réputation est sauvegardée.
- Le datapad affiche les réputations.
- Certaines quêtes peuvent exiger une réputation minimale.

Priorité : P1  
Complexité : M

#### US-050 — Contrats entre joueurs

Critères d’acceptation :

- Un joueur peut créer un contrat.
- Un autre joueur peut l’accepter.
- Le contrat peut être validé.
- Le paiement est sécurisé.

Priorité : P2  
Complexité : L

---

## 48. Priorité immédiate recommandée

La prochaine version du projet doit se concentrer sur :

1. Classes de départ.
2. Niveau général.
3. Compétences par usage.
4. Datapad progression.
5. Moteur de quêtes simple.
6. Moteur de craft simple.
7. HUD minimal.

C’est le noyau RPG. Une fois ce noyau stable, tout le reste peut s’ajouter autour.

---

## 49. Décision design forte

Le serveur ne doit pas être conçu comme un Star Wars RP classique. Il doit être conçu comme :

> Un RPG social persistant dans un univers galactique, où chaque joueur construit une carrière, une réputation, des compétences et une influence réelle sur le monde.

C’est cette différence qui peut rendre le serveur supérieur aux autres.

---

# Addendum V0.3 — Git, Kanban, Backlog et CI/CD

Objectif : transformer le projet en vrai produit logiciel, avec gestion de version, backlog clair, tickets exploitables, pull requests, validation automatique et déploiement contrôlé.

---

## 50. Choix d’outil recommandé

Outil principal recommandé : **GitHub**.

GitHub permet de gérer au même endroit le code source, les issues, les pull requests, les releases, la documentation Markdown, le Kanban via GitHub Projects et la CI/CD via GitHub Actions.

Pour le démarrage, GitHub Projects est préférable à Jira : moins lourd, directement lié au repo, suffisant pour un projet communautaire open source.

---

## 51. Organisation du repository

Option recommandée : **monorepo**.

```txt
galactic-rp/
  README.md
  CONTRIBUTING.md
  CODE_OF_CONDUCT.md
  LICENSE

  docs/
    architecture.md
    roadmap.md
    backlog.md
    rules-rp.md
    lore.md
    database.md
    ci-cd.md

  server/
    Config.example.toml
    Packages/
      gr_core/
      gr_database/
      gr_characters/
      gr_progression/
      gr_skills/
      gr_inventory/
      gr_crafting/
      gr_quests/
      gr_factions/
      gr_reputation/
      gr_contracts/
      gr_chat/
      gr_voip/
      gr_admin/
      gr_hud/
      gr_datapad/

  ui/
    hud/
    datapad/

  database/
    migrations/
    seeds/

  docker/
    docker-compose.yml
    .env.example

  tools/
    start-dev.ps1
    build-ui.ps1
    sync-ui.ps1
    backup-db.ps1

  .github/
    ISSUE_TEMPLATE/
    workflows/
```

Le monorepo est le meilleur choix au début car il garde les packages Lua, l’UI React, les migrations SQL, Docker et la documentation synchronisés.

---

## 52. Stratégie Git

Branches recommandées :

```txt
main      -> production stable
develop   -> staging / intégration
feature/* -> nouvelles fonctionnalités
fix/*     -> corrections
hotfix/*  -> corrections urgentes production
release/* -> préparation d’une version
```

Règles :

- Pas de push direct sur `main`.
- Toute fonctionnalité passe par une branche `feature/*`.
- Toute modification importante passe par une Pull Request.
- La CI doit passer avant merge.
- `main` doit toujours représenter une version stable.

---

## 53. Convention de commits

Utiliser une convention simple :

```txt
feat: add character creation system
fix: prevent duplicate inventory items
docs: update architecture documentation
ci: add GitHub Actions workflow
refactor: split progression service
chore: update docker compose
```

Types recommandés : `feat`, `fix`, `docs`, `ci`, `refactor`, `chore`, `test`, `perf`.

---

## 54. Kanban GitHub Project

Colonnes recommandées :

```txt
Ideas
Backlog
Ready
In Progress
Code Review
Testing
Ready for Release
Done
Blocked
```

Champs personnalisés :

```txt
Priority: P0 / P1 / P2 / P3
Type: Feature / Bug / Tech / Doc / Asset / RP Design / DevOps
Epic: Core / RPG / UI / Faction / Craft / Quest / Admin / Map / Infra
Complexity: XS / S / M / L / XL
Milestone: MVP Tech / MVP RPG / Alpha / Beta / Release
Owner: personne responsable
```

---

## 55. Labels GitHub recommandés

```txt
type: feature
type: bug
type: tech-debt
type: documentation
type: devops
type: asset
type: game-design
type: rp-rule

priority: p0
priority: p1
priority: p2
priority: p3

epic: core
epic: characters
epic: progression
epic: skills
epic: inventory
epic: crafting
epic: quests
epic: factions
epic: reputation
epic: admin
epic: ui
epic: map
epic: infra

status: blocked
status: needs-spec
status: ready
status: good-first-issue
```

---

## 56. Backlog Infra initial

### US-INFRA-001 — Créer le repository GitHub

Critères d’acceptation : repo créé, README présent, dossiers principaux créés, `.gitignore` ajouté, branche `main` protégée.

Priorité : P0  
Complexité : S

### US-INFRA-002 — Créer le Kanban GitHub Project

Critères d’acceptation : colonnes créées, champs personnalisés créés, labels créés, premières issues ajoutées.

Priorité : P0  
Complexité : S

### US-INFRA-003 — Ajouter templates issues et PR

Critères d’acceptation : template User Story, Bug Report, Technical Task et Pull Request créés.

Priorité : P0  
Complexité : M

### US-INFRA-004 — Ajouter Docker Compose PostgreSQL

Critères d’acceptation : PostgreSQL démarre, pgAdmin fonctionne, volume persistant configuré, `.env.example` présent.

Priorité : P0  
Complexité : M

### US-INFRA-005 — Ajouter migrations SQL initiales

Critères d’acceptation : dossier migrations créé, tables de base créées, script testable en local.

Priorité : P0  
Complexité : M

### US-INFRA-006 — Créer pipeline CI GitHub Actions

Critères d’acceptation : workflow CI créé, déclenché sur PR, build UI, vérification SQL, packaging artefacts.

Priorité : P0  
Complexité : L

### US-INFRA-007 — Créer pipeline release

Critères d’acceptation : release déclenchée par tag, archive serveur générée, artefacts disponibles.

Priorité : P1  
Complexité : M

### US-INFRA-008 — Créer pipeline deploy staging

Critères d’acceptation : déploiement manuel staging, secrets GitHub, upload SSH, backup avant déploiement.

Priorité : P1  
Complexité : L

---

## 57. CI/CD cible

Pipeline CI Pull Request :

```txt
1. Checkout repo
2. Setup Node.js
3. Install dependencies UI
4. Build HUD React
5. Build Datapad React
6. Validate SQL migrations
7. Check secrets obvious
8. Package server artifacts
9. Upload artifacts
```

Pipeline Release :

```txt
1. Build UI
2. Sync UI into packages
3. Package server folder
4. Package migrations
5. Publish GitHub Release
```

Pipeline Deploy Staging :

```txt
1. Build package
2. SSH staging
3. Backup current packages
4. Upload new packages
5. Run migrations if needed
6. Restart nanos world staging server
7. Smoke test
```

Production : déploiement manuel uniquement, avec backup et rollback documenté.

---

## 58. Secrets GitHub à prévoir

```txt
STAGING_HOST
STAGING_USER
STAGING_SSH_KEY
STAGING_DEPLOY_PATH
PROD_HOST
PROD_USER
PROD_SSH_KEY
PROD_DEPLOY_PATH
```

Ne jamais commiter les mots de passe DB, clés SSH, tokens Discord, clés API, fichiers `.env` réels ou `Config.toml` de production.

---

## 59. Definition of Ready

Un ticket est prêt seulement si la description est claire, les critères d’acceptation sont écrits, la priorité est définie, le package concerné est identifié, les impacts DB/UI sont indiqués et la complexité est estimée.

---

## 60. Definition of Done

Un ticket est terminé seulement si le code est mergé, la CI passe, les critères d’acceptation sont validés, le test local ou staging est fait, la documentation est mise à jour si nécessaire et aucun secret n’est commité.

---

## 61. Décision recommandée

Démarrer immédiatement avec GitHub repo, GitHub Project Kanban, issues templates, Pull Request template, Docker PostgreSQL, CI GitHub Actions simple, branches `main/develop/feature`, migrations SQL versionnées et documentation de lancement local.

