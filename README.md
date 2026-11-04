# Luma — iOS 27

Application native SwiftUI pour iPhone, issue de la maquette [Projet LED IoT](https://www.figma.com/design/GhrvxUS2ZNhR30qS5GcRi5/Projet-LED-IoT?node-id=24-81).

La [spécification de référence](SPEC.md) décrit les fonctions, les règles, les décisions, l’état du développement et les points ouverts. Elle est mise à jour avec les évolutions de l’application.

## Ouvrir et lancer

1. Ouvrir `Luma.xcodeproj` avec Xcode 27.
2. Choisir le schéma **Luma**, puis un simulateur iPhone sous iOS 27.
3. Lancer avec **⌘R**. Toucher « Connecter » sur l’écran d’accueil.
4. Pour un iPhone physique, choisir votre équipe dans **Signing & Capabilities** et un identifiant d’application disponible.

Aucune dépendance externe ni aucun compte nécessaires. La météo nécessite une connexion Internet et utilise Open-Meteo. La cible minimale est iOS 27.0 sur iPhone. iPad, Mac Catalyst, l’exécution « Designed for iPad » sur Mac et visionOS ne sont pas pris en charge. Les ressources graphiques sont incluses dans le projet et fonctionnent hors ligne.

## Fonctionnement

- Un panneau monochrome Luma de 32 × 8, soit 256 LED, sur la pièce du dessus. Défilement automatique au-delà de 5 caractères.
- Saisie libre avec alphabet pixel partagé avec le prototype existant, accents français, limite de 60 caractères et validation des caractères non pris en charge.
- Six couleurs pour les aperçus des messages, icônes et dessins ; le MAX7219 reste monochrome.
- Six pictogrammes de 8 × 8 LED et un éditeur de dessin personnel 32 × 8, avec sélection du carré à dessiner, sauvegardé localement : glisser pour ajouter ou effacer, valider pour revenir aux Icônes, ajouter aux favoris pour garder la forme et la couleur.
- 20 dessins favoris rappelables depuis Icônes, en plus des messages favoris.
- Favoris modifiables, conservés avec le message et les réglages entre les lancements.
- Luminosité, modes Auto/Fixe/Toujours/Apparition, trois vitesses, pause de l’aperçu et allumage/extinction. Le mode Apparition affiche chaque mot successivement : cinq caractères par écran, mots plus longs découpés et compteur dans l’app.
- Compte-tours OBD simulé : régime transmis par le Mac, maximum réglable et barre sur 32 colonnes.
- Visualiseur audio : micro de l’iPhone après autorisation, analyse locale et barres sur la matrice tant que l’app est ouverte et connectée. Aucun son brut n’est envoyé ni enregistré.
- Horloge synchronisée par l’iPhone, date et jour ; chronomètre, minuteur avec progression et Pomodoro.
- Animations, messages surprise et deux messages quotidiens programmés pendant la connexion Bluetooth.
- Météo de Grenoble sur demande, fournie via Open-Meteo lorsque l’iPhone a accès à Internet.
- Aperçu animé et confirmation affichant le contenu du panneau virtuel.
- Recherche et connexion Bluetooth LE au panneau ESP32-C3, commandes et déconnexion.
- Police système Apple avec Dynamic Type, contrôles natifs et réduction des animations selon le réglage d’accessibilité.

## Panneau ESP32-C3 et MAX7219

Ouvrir `~/Documents/Arduino/luma/LumaESP32/LumaESP32.ino` dans Arduino IDE et téléverser le programme avec les fichiers `LumaModes.h`, `LumaTransition.h`, `LumaAudio.h` et `LumaRPM.h` situés dans le même dossier sur l’ESP32-C3. Il pilote quatre MAX7219 8 × 8 en chaîne : DIN GPIO4, CS GPIO5 et CLK GPIO6. Alimenter le panneau selon les caractéristiques de son module et relier les masses. Vérifier les niveaux logiques du module ; un adaptateur 3,3 V vers 5 V peut être nécessaire.

Autoriser le Bluetooth sur l’iPhone puis toucher « Connecter ». Le service n’est pas authentifié : un appareil à proximité peut le commander. La matrice est monochrome ; les couleurs restent limitées à l’aperçu. Le défilement, l’horloge, les minuteurs et les animations sont exécutés par l’ESP32 après transfert ; ils continuent après déconnexion. Après coupure de courant, reconnecter l’iPhone pour synchroniser l’heure et reprogrammer les messages. Les messages programmés ne se déclenchent que pendant une connexion Bluetooth active. Les anciens dessins 8 × 8 restent centrés et conservés. Mettre à jour l’application et téléverser le programme ESP32 ensemble : le nouveau service Bluetooth ne se connecte pas aux versions précédentes. La liaison et le câblage restent à vérifier sur matériel.

## Simulateur OBD sur Mac

1. Ouvrir `~/Documents/Arduino/luma/OBDSimulator/LancerSimulateur.command`. La fenêtre Terminal doit rester ouverte ; le curseur s’ouvre dans le navigateur du Mac.
2. Mettre le Mac et l’iPhone sur le même Wi-Fi. Dans Luma, après connexion du panneau, ouvrir **Activités → Compte-tours OBD**, saisir l’adresse du Mac indiquée sur la page et toucher **Connecter le simulateur**. Autoriser le réseau local si iOS le demande.
3. Déplacer le curseur : le régime et la barre changent. Le maximum initial est 6 000 tr/min. Pour arrêter, utiliser le bouton dans Luma puis Ctrl+C dans Terminal.

Le serveur écoute sur le réseau local sans authentification : utiliser un réseau de confiance, sans ouverture vers Internet. Il simule uniquement les commandes nécessaires au régime ; aucune lecture de voiture réelle n’est implémentée. Ne pas utiliser ce mode comme indicateur de conduite.

## Organisation

- `Luma/Models.swift` : profil du panneau et état du brouillon.
- `Luma/LumaStore.swift` : état de session et sauvegarde locale.
- `Luma/PixelRenderer.swift`, `PixelFont.swift` : validation et rendu matriciel.
- `Luma/*View.swift` : écrans SwiftUI.
- `Luma/Components.swift` : composants visuels et aperçu dynamique.
- `Luma/Assets.xcassets` : couleurs et SVG exportés de Figma.
- `LumaTests` : règles du rendu, validation, persistance et commandes locales.
- `LumaUITests` : parcours sur simulateur avec captures.

La police Apple remplace Manrope à la demande de l’utilisateur. Les onglets, sélecteurs et curseurs utilisent les composants natifs iOS ; leur forme diffère donc du prototype web. Les panneaux LED sont rendus dynamiquement à partir du même alphabet et des mêmes matrices que le prototype, et les pictogrammes de galerie utilisent les exports Figma.

## Vérifier

Dans Xcode : **⌘U** pour lancer les tests du schéma Luma. Les tests d’interface conservent leurs captures dans le rapport de test.

Validation du 30 septembre 2026 : compilation sans erreur ni avertissement avec Xcode 27.0 ; **17 tests réussis, 0 échec, 0 test ignoré**, sur un iPhone physique sous iOS 27.0. Cela comprend 16 tests unitaires et un parcours d’interface vérifiant notamment les gestes d’ajout et d’effacement, la validation et les favoris de dessins. Aucun test sur panneau Bluetooth réel n’a été effectué.

Les fichiers du prototype web et les sources synchronisées du projet n’ont pas été modifiés.
