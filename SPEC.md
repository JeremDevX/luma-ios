# Spécification de l’application Luma

Version du document 0.7 · 18 novembre 2026.

## Connexion ESP32-C3

L’application recherche le service BLE `7A2F0008-CB86-4B6D-8F78-38D24B9E1940` et envoie les commandes à la caractéristique `7A2F0002-CB86-4B6D-8F78-38D24B9E1940`. L’ESP32-C3 Mini pilote une matrice RGB WS2812B de 32 × 8 sur GPIO4. L’iPhone envoie les réglages dans un paquet `[0x0A, luminosité, rouge, vert, bleu]`. La luminosité va de 0 à 100 %, chaque canal RGB de 0 à 255. À 0 %, la matrice est éteinte. Les messages, icônes, dessins et activités utilisent la couleur sélectionnée. Les messages programmés reprennent la couleur courante du panneau.

Chaque image fixe est envoyée en deux paquets de 17 octets puis transmise à la chaîne de LED après réception complète. Le texte défilant arrive en fragments ordonnés et l’ESP32 l’anime même après déconnexion. La liaison est accessible sans authentification. L’acquittement BLE confirme l’écriture de la commande. Le rendu visuel doit être vérifié sur la matrice.

État le 18 novembre 2026. Compilations ESP32 et iPhone réussies, tests du moteur et 30 tests unitaires iOS sur simulateur réussis. Montage, ordre des pixels et liaison réelle à vérifier.

## Évolution du 4 novembre 2026

Les caractères `(`, `)`, `=`, `-` et `_` sont utilisables dans les messages. Les vitesses visées sont de 100, 50 et 20 ms par colonne, en cadence cible sur l’ESP32. L’éditeur couvre 32 × 8 pixels : quatre carrés sélectionnables de 8 × 8, avec un aperçu du panneau entier. Les pictogrammes intégrés restent centrés en 8 × 8.

Les brouillons et favoris 8 × 8 existants sont lus et centrés dans la grille 32 × 8. Les nouvelles sauvegardes utilisent des clés distinctes ; les anciennes données restent conservées. Validation sur matériel à effectuer.

## Activités et météo · 4 novembre 2026

L’onglet Activités propose : horloge alternant heure, date et jour ; chronomètre ; minuteur de 1 à 99 minutes avec barre de progression et clignotement final ; Pomodoro de 25 minutes puis 5 minutes de pause en boucle ; animations cœur, étoiles, pluie, flèche et messages surprise prédéfinis. Le panneau n’a pas de son. Un seul mode est affiché à la fois : lancer un mode remplace le précédent. La pause, la reprise et la remise à zéro agissent sur le mode de temps actif. Ces modes s’exécutent sur l’ESP32 et continuent après déconnexion tant qu’il reste alimenté.

Les animations comprennent un cœur à double battement, des étoiles scintillantes, des gouttes d’une LED de large à positions et vitesses aléatoires, une flèche en mouvement et des messages surprise. Les gouttes occupent des colonnes séparées sans collision. La révélation progressive des messages correspond au mode « Apparition », distinct des modes Auto, Fixe et Toujours. Il affiche un mot par écran et découpe les mots dépassant cinq caractères ; l’app indique le nombre de caractères du mot et d’écrans. Exemple : « SALUT BONJOUR » donne « SALUT », « BONJO », « UR ». La limite totale reste de 60 caractères. La météo utilise ce mode ; l’heure, la date et le jour gardent leur transition. Les messages programmés conservent leur transition avant défilement. Chaque animation recommence au début lorsqu’elle est sélectionnée. Rendu matériel à vérifier.

L’heure locale est synchronisée par l’iPhone à chaque connexion. Sans module d’horloge sauvegardée, une coupure de courant exige une nouvelle connexion ; un changement de fuseau horaire ou d’heure nécessite aussi une nouvelle connexion. La précision dépend de l’horloge interne de l’ESP32.

Deux messages quotidiens configurables, de 16 caractères ASCII maximum, sont programmés depuis l’app et exécutés uniquement quand l’iPhone reste connecté en Bluetooth. Ils restent en mémoire jusqu’au redémarrage de l’ESP32, après lequel ils doivent être programmés à nouveau. Les horaires saisis restent sur l’iPhone. Le message remplace le contenu courant au déclenchement.

La météo actuelle de Grenoble est demandée manuellement par l’app sur Internet via Open-Meteo ; la température et une indication simplifiée sont envoyées en texte au panneau. Elle ne se rafraîchit pas automatiquement ; Internet et la connexion Bluetooth sont nécessaires. L’ancien brouillon de message est conservé. Le nouveau service BLE distingue l’app et le firmware mis à jour des versions précédentes.

Vérification : compilations iOS et ESP32, tests unitaires iOS sur simulateur et tests du moteur simulé réussis ; météo en direct, panneau et iPhone physiques à vérifier.

## Mode Apparition · 4 novembre 2026

Le mode Apparition est sélectionnable depuis le message et les réglages. Les mots sont affichés successivement avec apparition et disparition progressives, sans défilement ; les mots de plus de cinq caractères sont découpés. Le panneau gère le cycle hors connexion après réception. Les vitesses Lente, Normale et Rapide correspondent à 4, 3 et 2,4 secondes par écran. L’aperçu utilise la même séquence ; la réduction des animations garde le premier écran fixe. Le service BLE a changé : mettre à jour l’app et l’ESP32 ensemble.

## Visualiseur audio · 4 novembre 2026

Dans Activités, l’utilisateur active explicitement le micro de l’iPhone après autorisation iOS. Une analyse fréquentielle locale produit 32 niveaux de 0 à 8, affichés sous forme de barres et envoyés au panneau en Bluetooth à environ 15 images par seconde au maximum ; les images qui ne peuvent pas être transmises immédiatement sont ignorées. Aucun enregistrement audio n’est conservé et aucun son brut n’est transmis au panneau. La réactivité dépend du micro, du volume ambiant et du débit Bluetooth ; la sensibilité n’a pas été calibrée sur le matériel.

Le micro s’arrête à la demande, à la sortie de l’écran Activités, en arrière-plan, lors d’une interruption audio, de la déconnexion ou au lancement d’un autre affichage. Le panneau s’efface après une seconde sans données. Un message programmé reste prioritaire pendant dix secondes, puis le visualiseur reprend si le téléphone continue à transmettre. Le service BLE change : l’app et l’ESP32 doivent être mis à jour ensemble. Le nouveau fichier Arduino `LumaAudio.h` reste à côté du sketch.

Vérification : compilations iOS et ESP32, tests de spectre synthétique et de protocole simulé ; microphone, latence et affichage physiques à vérifier.

## Transcription vocale en direct · 4 novembre 2026

Correction : les réponses système aux autorisations et les rappels audio ne supposent pas une exécution sur le thread principal ; les mises à jour de l’interface restent isolées sur ce thread. Le texte affiché conserve les phrases reconnues lors des reprises de l’écoute, dans la limite des 500 derniers caractères.

Dans À afficher, démarrer la transcription avec le panneau connecté. Le microphone et la reconnaissance vocale demandent leurs autorisations ; la reconnaissance française doit être disponible localement et aucun audio n’est envoyé sur Internet. Les résultats partiels apparaissent dans l’app ; les mots sont normalisés pour la police puis envoyés en petits groupes au défilement rapide existant. La file d’attente conserve jusqu’à 800 caractères et signale le retard ; si elle se remplit, les mots les plus anciens en attente sont ignorés. La transcription s’arrête au changement de mode, à la déconnexion, au départ de l’écran ou au passage en arrière-plan. La reconnaissance et l’affichage restent à vérifier sur iPhone et matrice physiques.

## Compte-tours OBD simulé · 4 novembre 2026

Le Mac fournit un simulateur local minimal compatible avec les commandes ELM327 nécessaires à la lecture `010C` ; il ne simule pas l’ensemble de l’OBD. Le curseur web règle le régime entre 0 et 12 000 tr/min. Le serveur OBD écoute sur le réseau local, port 35000 ; l’interface web locale utilise le port 8765. Le simulateur n’est pas authentifié et ne doit être utilisé que sur un réseau de confiance. Il n’est pas une interface avec une voiture réelle.

Dans Activités, l’iPhone reçoit l’adresse IP du Mac et demande l’autorisation réseau local. L’app initialise la session, interroge `010C` à intervalle de 200 ms après chaque réponse, décode le régime puis transmet la valeur et le maximum au panneau par BLE. Le maximum initial est 6 000 tr/min et peut être réglé entre 1 000 et 12 000 tr/min ; une demi-échelle allume 16 des 32 colonnes. Le panneau s’efface si les données cessent pendant 1,5 seconde et l’aperçu passe en attente après 1,4 seconde. Un message programmé interrompt le compte-tours dix secondes, puis celui-ci reprend si les valeurs arrivent encore.

La lecture s’arrête à la demande, à la sortie d’Activités, en arrière-plan, lors de la déconnexion ou au lancement d’un autre affichage. Le service BLE est distinct des versions précédentes : mettre à jour l’app et le programme ESP32 ensemble. La connexion à un véritable adaptateur OBD et l’usage comme indicateur de conduite ne sont pas développés ni validés.

Vérification : compilations iOS et ESP32 ; tests du simulateur, décodage, protocole et rendu simulé. Liaison physique iPhone-panneau à vérifier.

## Objectif du produit

Permettre à une personne de composer un message ou de choisir un pictogramme, d’en vérifier le rendu sur une matrice LED, puis de l’afficher sur son panneau. L’expérience doit être simple, en français et utilisable sans compte.

La référence visuelle est la [maquette Figma Projet LED IoT](https://www.figma.com/design/GhrvxUS2ZNhR30qS5GcRi5/Projet-LED-IoT?node-id=24-81). Les ressources du prototype existant servent de référence pour l’alphabet pixel et les pictogrammes.

## Décisions prises

| Sujet | Décision | Origine |
|---|---|---|
| Plateforme | Application native SwiftUI pour iPhone uniquement, iOS 27 minimum | Demande initiale, périmètre confirmé le 30 septembre 2026 |
| Distribution | Application de démonstration ; identifiant `fr.luma.demo` conservé | Décision utilisateur du 30 septembre 2026 |
| Typographie | Police système Apple à la place de Manrope | Choix de l’utilisateur |
| Matériel | Matrice WS2812B RGB 32 × 8, alimentée en 5 V par une alimentation 20 A | Dimensions et matériel communiqués par l’utilisateur |
| Contrôleur | ESP32-C3 Mini alimenté par USB-C, GPIO4 pour les données, masse commune | Carte et alimentation communiquées par l’utilisateur, GPIO4 retenu pour le montage |
| Première livraison | Démonstration locale clairement signalée | Absence de spécification matérielle confirmée par l’utilisateur |
| Documentation | Spécification tenue à jour avec le développement | Demande du 30 septembre 2026 |

Les valeurs par défaut et les limites ci-dessous décrivent l’implémentation actuelle. Elles restent modifiables par décision produit ; leur présence dans ce document ne vaut pas validation d’un comportement matériel.

## Périmètre et état actuel

| Fonction | État | Limite actuelle |
|---|---|---|
| Connexion au panneau Luma | Développé | Un panneau à la fois, vérification matérielle à effectuer |
| Saisie libre et validation d’un message | Développé | Alphabet pixel défini, 60 caractères maximum |
| Aperçu matriciel et défilement | Développé | Rendu sur le téléphone |
| Palette de couleurs | Développé | Une couleur par image sur la matrice RGB |
| Galerie de six pictogrammes | Développé | Dessins prédéfinis de 8 × 8 LED |
| Création d’un dessin personnel | Développé | Grille 32 × 8, quatre carrés sélectionnables, glissement, validation, sauvegarde locale |
| Ajout, retrait et rappel de favoris | Développé | 20 messages et 20 dessins maximum, listes distinctes |
| Luminosité, vitesse et mode de défilement | Développé | Réglages transmis au panneau par BLE |
| Allumage et effacement | Développé | Envoi d’une image vide pour l’extinction |
| Sauvegarde du brouillon et des réglages | Développé | Sur le téléphone |
| Aide et simulation de déconnexion | Développé | États de démonstration |
| Découverte, connexion et envoi Bluetooth | Développé | Validation sur iPhone et matrice à effectuer |
| Installation sur l’iPhone de l’utilisateur | Vérifiée sur matériel réel | Compilation, installation et parcours d’interface réussis sur un iPhone physique sous iOS 27.0 |
| Publication sur l’App Store | Hors périmètre actuel | Aucune publication demandée |

La cible et ses cibles de tests sont configurées pour la famille iPhone uniquement. Les variantes iPad, Mac Catalyst, « Designed for iPad » sur Mac et visionOS ne font pas partie du périmètre.

## Panneau et matrice

La version actuelle utilise un seul panneau « Luma », couleur, monté sur la pièce du dessus. L’ancien profil rouge et le choix entre deux panneaux ont été retirés pour suivre la maquette actualisée.

| Propriété | Luma |
|---|---|
| Matrice | 32 colonnes × 8 lignes, soit 256 LED |
| Couleurs | Citron, Blanc, Ambre, Corail, Azur, Lavande |
| Capacité de texte fixe | 5 caractères |
| Pictogrammes | 8 × 8 LED, centrés dans les colonnes 13 à 20 |
| Dessin personnel | 32 × 8 LED, modifiable carré par carré |

L’utilisateur a confirmé le type WS2812B et la dimension de cette [référence AliExpress](https://fr.aliexpress.com/item/1005002399031444.html). Le programme utilise par défaut un ordre GRB et un câblage en zigzag par colonnes, avec la première LED en haut à gauche. L’ordre et l’orientation restent à vérifier sur l’exemplaire.

## Contrôleur ESP32

L’ESP32-C3 Mini est alimenté par USB-C. La matrice reçoit le 5 V de son alimentation dédiée et partage sa masse avec l’ESP32. GPIO4 commande DIN avec un niveau logique adapté à la matrice. Le [guide de lancement](README.md#panneau-esp32-c3-mini-et-ws2812b) décrit le branchement et l’installation du programme.

## Parcours et écrans

### Accueil et connexion

L’accueil « Connecte ton panneau » présente un aperçu 32 × 8 et un bouton « Connecter ». L’app cherche le service Bluetooth Luma. La recherche peut être annulée. L’onglet Message s’ouvre une fois la connexion établie.

L’aide « Panneau introuvable ? » invite à vérifier le programme installé sur l’ESP32 et l’alimentation du panneau.

### Onglet Message

L’écran « Ton message », sous-titré « Écris, puis affiche. », contient un aperçu, le champ « Ton message », un compteur, l’étoile, les couleurs et les « Favoris ». Toucher un favori remplace le brouillon.

« Afficher sur le panneau » est désactivé si le texte est invalide. Cette action envoie le message, sa couleur et ses réglages. Après l’acquittement Bluetooth, « Commande transmise » montre un aperçu et invite à vérifier le panneau.

### Onglet Icônes et dessin personnel

L’écran « Icônes » propose six pictogrammes et « ＋ Créer un dessin ». Choisir Sourire, Cœur, Flèche, Soleil, Clin d’œil ou Pause met à jour l’aperçu. Le choix de couleur s’applique au contenu courant. Les pictogrammes et dessins ne dépendent pas de la validité du texte.

« Ton dessin » présente l’aperçu du panneau, quatre grilles interactives 8 × 8 sélectionnables et la palette. Le premier pixel touché détermine le mode du geste : s’il est éteint, le glissement allume ; s’il est allumé, le glissement efface. Ce mode reste constant jusqu’au relâchement, même si le doigt repasse sur un pixel ou traverse un pixel d’un état différent. Les pixels traversés entre deux positions du doigt sont remplis pour éviter les trous lors d’un mouvement rapide. Sortir de la grille ne modifie aucun pixel ; rentrer dans la grille conserve le mode du geste sans relier les positions extérieures. Le glissement commencé dans la grille dessine ; le défilement de la page reste disponible en dehors de la grille. Les pixels restent actionnables individuellement par les fonctions d’accessibilité.

Le brouillon est sauvegardé automatiquement. « Valider le dessin » conserve une copie du dessin courant et revient aux Icônes, où ce dessin est sélectionné dans l’aperçu. Il peut ensuite être affiché avec « Afficher sur le panneau ». Valider n’envoie aucune commande et n’ajoute pas automatiquement un favori. Un dessin vide ne peut pas être validé ni ajouté aux favoris.

« Ajouter aux favoris » conserve la forme et la couleur ; le bouton devient « Retirer des favoris » quand cette combinaison est déjà enregistrée. Les dessins favoris sont accessibles dans l’écran Icônes et peuvent être rappelés pour affichage ou modification. Un appui long sur un favori permet de le retirer. La limite est de 20 dessins favoris, distincte des 20 messages favoris ; aucune copie identique de forme et de couleur n’est ajoutée par le bouton. La liste persiste entre les lancements.

« Retour aux icônes » revient à l’écran précédent sans valider les modifications ; le brouillon reste sauvegardé, et le contenu précédemment validé reste sélectionné. « Effacer le dessin » demande confirmation puis vide uniquement le brouillon. Modifier ou effacer le brouillon, ou retirer un favori, ne change pas le dessin validé ni le contenu déjà affiché.

### Onglet Panneau

L’écran « Réglages », sous-titré « Ajuste ton panneau. », présente « Luma — 32 × 8 · 256 LED », la luminosité, le défilement, la vitesse et l’allumage. Le brouillon est sauvegardé immédiatement. « Appliquer les réglages » envoie les nouveaux réglages avec le contenu affiché, ou avec le brouillon lors du premier envoi.

« Déconnecter » demande confirmation puis revient à l’accueil. L’ESP32 conserve le contenu fixe ou autonome tant qu’il reste alimenté. Les activités qui dépendent d’un flux de l’iPhone s’arrêtent. L’iPhone conserve le brouillon, le dessin et les favoris.

### Effacement et perte de connexion

« Effacer le panneau » demande confirmation puis envoie une image vide. Le brouillon et les favoris sont gardés. Un nouvel affichage affiche à nouveau le contenu à la luminosité choisie.

Si la liaison Bluetooth est interrompue, « Connexion perdue » conserve le brouillon et propose « Reconnecter ».

## Règles du message et du rendu

Le rendu convertit le texte en majuscules et normalise les accents Unicode. Le texte saisi peut conserver sa casse dans le champ ; la validation, le compteur et les favoris ajoutés utilisent la version normalisée.

- Un message vide ou composé uniquement d’espaces est invalide.
- Le texte normalisé peut contenir au maximum 60 caractères. Une saisie plus longue reste visible pour correction, mais son affichage est interdit.
- Alphabet disponible : A à Z, 0 à 9, espace, `! ? . , : ' - + / ( ) = _` et les lettres É, È, Ê, À, Ç, Ù, Ô, Ï.
- Les caractères non pris en charge, notamment les emoji et les sauts de ligne, sont signalés et empêchent l’affichage d’un message.
- Les lettres utilisent des glyphes de 5 × 7 pixels, avec une colonne entre deux caractères.
- En mode Auto, le texte défile quand sa largeur dépasse celle du panneau. La largeur vaut `6 × nombre de caractères − 1` ; le seuil actuel est donc 5 caractères.
- En mode Fixe, le texte tient immobile. Un texte trop large est tronqué par les limites du panneau ; aucune réduction de police n’est appliquée.
- En mode Toujours, le texte défile même s’il tient dans la matrice.
- Les vitesses locales correspondent à un déplacement d’une colonne toutes les 100 ms, 50 ms ou 20 ms. La cadence réelle dépend du temps de mise à jour des matrices.
- Les pictogrammes restent fixes. Les réglages de défilement concernent le texte.
- La luminosité varie de 0 à 100 %. À 0 %, la matrice et son aperçu s’éteignent.
- La pause de l’aperçu agit uniquement sur son animation locale.

Un caractère invalide peut apparaître comme un point d’interrogation dans l’aperçu, tout en bloquant la commande d’affichage. L’aperçu permet d’éditer le brouillon ; il ne constitue pas une confirmation de réception matérielle.

## Favoris et valeurs par défaut

L’étoile ajoute ou retire le texte normalisé des favoris. Un message invalide ne peut pas être ajouté. À 20 favoris, un favori existant doit être retiré avant d’en ajouter un nouveau.

| Élément | Valeur initiale |
|---|---|
| Message | MERCI |
| Favoris | MERCI, BONJOUR, À BIENTÔT |
| Couleur | Citron |
| Pictogramme | Sourire |
| Luminosité | 40 % |
| Défilement | Auto |
| Vitesse | Normale |
| Panneau allumé | Activé dans le brouillon |

## Données et conservation

Le téléphone conserve les dessins favoris et leurs couleurs, le brouillon du dessin personnel de 256 pixels, le message, la couleur, le pictogramme, la luminosité, le mode de défilement, la vitesse, l’état d’allumage du brouillon et les favoris. La sauvegarde est locale, dans les préférences de l’application.

Au lancement, l’application revient à l’accueil et reprend le brouillon sauvegardé. Le contenu affiché lors de la dernière commande ainsi que la sélection du dessin validé sont propres à la session de l’app.

Si les données enregistrées ne peuvent pas être restaurées, l’application revient aux valeurs initiales et informe l’utilisateur. Aucune synchronisation cloud, télémétrie ou gestion de compte n’est implémentée.

## Interface et accessibilité

La version actuelle reprend les couleurs et ressources graphiques de Figma, un thème sombre et la police système Apple. Les onglets, curseurs, sélecteurs et interrupteurs sont des contrôles iOS natifs. Les différences visuelles avec la maquette incluent ces contrôles, la typographie et le bandeau de démonstration.

Le texte utilise Dynamic Type. La galerie passe à deux colonnes pour les grandes tailles d’accessibilité. Les principaux contrôles possèdent des libellés d’accessibilité. Chaque pixel du dessin annonce sa ligne, sa colonne et son état. La réduction des animations désactive le défilement automatique de l’aperçu ; les animations s’arrêtent aussi quand l’application est inactive.

La prise en charge de ces fonctions est implémentée. Un audit complet avec VoiceOver, les grandes tailles de texte et sur iPhone physique reste à effectuer.

## Validation matérielle

Sur l’iPhone et la matrice, vérifier la découverte Bluetooth, les six couleurs, la luminosité, le défilement, l’extinction et la reconnexion. Un dessin en L dans le coin supérieur gauche permet de vérifier l’orientation et l’enchaînement des LED.

## Vérification et critères d’acceptation

Validation historique du 30 septembre 2026 avec Xcode 27.0 et le simulateur iPhone 17e sous iOS 27.0. Version 0.4 : compilation réussie et 17 tests réussis, sans échec ni test ignoré : 16 tests unitaires et un parcours d’interface. Les gestes natifs d’ajout et d’effacement, la validation, l’ajout/retrait d’un favori et le retour sont vérifiés par le parcours d’interface. Le rappel des dessins, leur couleur, la persistance, la limite et la corruption des favoris sont vérifiés par tests unitaires. La capture de l’éditeur avec les nouvelles actions a été inspectée visuellement.

Version 0.5 : configuration limitée à l’iPhone pour l’app et les tests ; variantes Mac Catalyst, Mac « Designed for iPad » et visionOS désactivées ; équipe de développement ajoutée aux deux cibles de tests. La compilation pour les tests ne produit ni erreur ni avertissement. Les 17 tests ont réussi sur un iPhone physique sous iOS 27.0 : 16 tests unitaires et un parcours d’interface, sans échec ni test ignoré.

| Critère | Vérification connue |
|---|---|
| Validation des accents, messages vides, limite et caractères inconnus | Tests unitaires réussis |
| Dimensions des matrices, centrage et pictogrammes 8 × 8 | Tests unitaires réussis |
| Seuils et modes de défilement, bouclage et extinction | Tests unitaires réussis |
| Sauvegarde du message et du dessin, favoris, restauration et données corrompues | Tests unitaires réussis |
| Dessin par glissement, mode verrouillé, interpolation et sortie de grille | Tests unitaires et gestes natifs réussis |
| Validation des dessins, favoris de dessins et rappel avec couleur | Tests unitaires réussis ; validation et ajout/retrait testés dans l’interface |
| Blocage d’une commande invalide ou hors session prête | Tests unitaires réussis |
| Connexion unique, couleur, affichage, icône, dessin, effacement, réglages et déconnexion | Test d’interface réussi |
| Installation et lancement sur l’iPhone de l’utilisateur | Vérifiés par le parcours d’interface réussi sur un iPhone physique sous iOS 27.0 |
| Communication avec la matrice WS2812B | Développée, validation matérielle à effectuer |
| Audit complet d’accessibilité | À effectuer |

Le problème de signature Apple signalé le 30 septembre est résolu : l’équipe est configurée pour l’app et ses deux cibles de tests, et les 17 tests réussissent sur un iPhone physique sous iOS 27.0.

## Suite du développement

Les points suivants restent ouverts et ne constituent pas des fonctionnalités supplémentaires validées :

1. Vérifier le câblage, l’ordre des LED, la liaison Bluetooth et le rendu RGB sur le montage.
2. Vérifier l’accessibilité sur les appareils retenus.

Les comptes, le cloud, les programmations horaires, la gestion simultanée de plusieurs panneaux et les autres plateformes n’ont pas été demandés. Ils ne font pas partie de cette version.

## Maintenance du document

À chaque évolution du développement, mettre à jour les sections touchées, la date, les états et le journal ci-dessous. Distinguer les demandes validées, les propositions, l’implémentation et la vérification. Une fonctionnalité développée ne devient pas « vérifiée sur matériel » sans preuve correspondante.

Lorsqu’un comportement change, remplacer la règle courante dans sa section et résumer la décision au journal. Ne pas conserver deux descriptions contradictoires. Les changements de protocole, de données sauvegardées, de compatibilité iOS ou de parcours doivent être répercutés dans cette spec et dans le guide de lancement si nécessaire.

Cette maintenance accompagne les sessions de développement dans ce projet. Aucun suivi périodique en arrière-plan n’est configuré.

## Journal des évolutions

| Date | Évolution | État |
|---|---|---|
| 18 novembre 2026 | Adaptation iOS et ESP32-C3 Mini à la matrice WS2812B 32 × 8, GPIO4, couleurs RGB et luminosité de 0 à 100 % | Compilations iPhone et ESP32, tests du moteur et 30 tests iOS réussis sur simulateur. Validation matérielle à effectuer. |
| 4 novembre 2026 | Simulateur OBD sur Mac et compte-tours 32 colonnes, maximum initial 6 000 tr/min | Tests logiciels ; vérification matérielle à effectuer |
| 4 novembre 2026 | Visualiseur audio par micro iPhone, analyse locale et barres BLE | Tests logiciels ; vérification matérielle à effectuer |
| 4 novembre 2026 | Mode Apparition mot par mot, compteur et découpage des mots longs | Tests unitaires iOS et simulation du protocole réussis ; vérification matérielle à effectuer |
| 4 novembre 2026 | Révélation progressive des textes et pluie fine aléatoire sans collision | Tests logiciels réussis ; vérification matérielle à effectuer |
| 4 novembre 2026 | Animations retravaillées pour le panneau 32 × 8 | Aperçu sur grille et tests du moteur ; vérification matérielle à effectuer |
| 4 novembre 2026 | Horloge, minuteurs, Pomodoro, animations, météo Grenoble et messages programmés avec Bluetooth | Compilé et testé en simulation ; vérification matérielle à effectuer |
| 4 novembre 2026 | Défilement exécuté sur ESP32 après transfert unique ; service BLE changé pour distinguer les anciennes versions | Compilation iOS et ESP32 ; vérification matérielle à effectuer |
| 4 novembre 2026 | Défilement accéléré, caractères supplémentaires, dessin sur quatre carrés et conservation des anciens dessins | Compilation et tests unitaires réussis ; vérification matérielle à effectuer |
| 30 septembre 2026 | Périmètre confirmé comme démonstration iPhone uniquement ; cibles alignées et signature des tests configurée | Vérifié sur iPhone physique : compilation sans avertissement et 17 tests réussis |
| 30 septembre 2026 | Dessin par glissement avec mode verrouillé, validation et retour aux Icônes, favoris de dessins persistants avec leur couleur | Développé ; 17 tests réussis sur simulateur |
| 30 septembre 2026 | Matrice couleur passée à 32 × 8 (256 LED), profil rouge retiré, parcours unique, tutoiement et éditeur de dessin 8 × 8 issus de Figma | Développé ; 13 tests réussis sur simulateur |
| 30 septembre 2026 | Première application SwiftUI, deux panneaux virtuels, messages, favoris, pictogrammes, réglages et ressources Figma | Développé ; validé sur simulateur |
| 30 septembre 2026 | Police Apple retenue ; connexion réelle différée en attente du matériel | Décisions utilisateur |
| 30 septembre 2026 | Problème de profil de signature lors de l’installation sur iPhone | Signalé ; résolution à confirmer |
| 30 septembre 2026 | Création de cette spécification et de sa consigne de maintenance | Document de référence créé |
| 30 septembre 2026 | Référence ESP32 fournie ; identification ESP32-S3 provisoire, capacités BLE vérifiées auprès d’Espressif et architecture BLE proposée | Documentation mise à jour ; aucune connexion matérielle développée ou testée |

## Références du projet

- [Guide de lancement](README.md)
- [Projet Xcode](Luma.xcodeproj)
- [Modèles et valeurs par défaut](Luma/Models.swift)
- [Règles de validation et de rendu](Luma/PixelRenderer.swift)
- [État et conservation locale](Luma/LumaStore.swift)
- [Tests unitaires](LumaTests/) et [parcours d’interface](LumaUITests/)
