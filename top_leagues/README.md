# Predict

© 2026 Stephen O'Donnell, Tanguy Labbe · GNU GPL v3 ou ultérieure (fichier `LICENSE`).

App macOS de prévision (Ligue 1, Bundesliga, Premier League, Serie A, Liga) et de simulation de paris. Un modèle
statistique, calibré sur les 10 dernières saisons, estime chaque match,
simule la fin de saison et propose des paris avec leur précision mesurée.

## Fonctionnalités principales

- **Tableau de bord** : prochaine journée avec les probabilités 1/N/2, paris
  conseillés, classement avec les chances de titre, de top 3 et des 3
  dernières places, points à surveiller.
- **Journées & cotes** : scores, xG et cotes de Winamax, Unibet, Bwin et
  Betclic, match par match.
- **Classements et analyse d'équipe** : général, domicile, extérieur,
  xPoints ; forme, bilans et calendrier de chaque club.
- **Conseils de paris** : quoi parier, à quelle cote et quelle mise, avec un
  verdict « Parier », « Petite mise au plus » ou « Ne pas parier » fondé sur
  les saisons passées.
- **Simulation des paris** : bankroll suivie selon quatre méthodes de mise
  (fixe, Kelly, ½ Kelly, ¼ Kelly).
- **Probabilités finales** : classement final simulé des milliers de fois.
- **Backtest** : précision du modèle face aux bookmakers.

Les données viennent toutes seules de football-data.co.uk, gratuitement.
Une clé gratuite The Odds API (Paramètres › Saison) ajoute les cotes
Winamax, Unibet et Betclic. Pas de mot de passe ; tout reste sur votre Mac,
dans `Documents/Predict`.

## Compiler

Il faut macOS 14 ou plus récent et les outils en ligne de commande d'Apple
(Xcode n'est pas nécessaire) :

```bash
xcode-select --install
```

Puis, dans le dossier `Predict` :

```bash
./build.sh        # crée build/Predict.app
./build.sh run    # compile puis lance l'app
```

## Ajouter Predict à ses applications

```bash
./build.sh install    # compile puis copie Predict dans /Applications
```

Ou glissez `build/Predict.app` dans le dossier Applications du Finder.
Predict apparaît alors dans le Launchpad et dans Spotlight (⌘ Espace,
« Predict »). Pour la garder dans le Dock : clic droit sur son icône ›
Options › Garder dans le Dock.

Quittez Predict avant de recompiler : une app déjà ouverte n'est pas
remplacée.

Si vous avez reçu l'app déjà compilée, macOS la bloque au premier lancement,
car elle n'est pas notarisée. Ouvrez Réglages Système › Confidentialité et
sécurité › **Ouvrir quand même**, ou :

```bash
xattr -dr com.apple.quarantine /Applications/Predict.app
```

## Utilisation

Au premier lancement, Predict télécharge la saison en cours et les 10
précédentes, puis calibre le modèle (quelques secondes). Ensuite, chaque
semaine, un clic sur **Mettre à jour en ligne** dans le tableau de bord
suffit. Mode d'emploi complet : Paramètres (⌘,) › Aide.

Simulation à but d'étude : aucun résultat passé ne garantit un gain futur.
Ne misez que ce que vous pouvez perdre ; aide : Joueurs Info Service,
09 74 75 13 13.

## Licence

Logiciel libre de Stephen O'Donnell et Tanguy Labbe : vous pouvez le
redistribuer et le modifier selon les termes de la licence publique générale
GNU, version 3 ou ultérieure. Fourni sans aucune garantie. Texte complet
dans `LICENSE`. Les noms des championnats et les écussons des clubs sont des marques de
leurs titulaires respectifs.
