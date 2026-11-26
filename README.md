# Kilométrage Pro

Application Flutter Web (PWA) de suivi des kilomètres professionnels et privés.

## Construire la version PWA hors ligne

```powershell
flutter pub get
flutter build web --release --no-web-resources-cdn
```

Publier **tout le contenu de `build/web`** sur un hébergement HTTPS (racine d'un
domaine ou sous-dossier : tous les chemins sont relatifs).

## Installer sur iPhone

1. Ouvrir l'adresse dans **Safari**, attendre l'affichage complet (connexion requise).
2. **Partager > Sur l'écran d'accueil**.
3. Ouvrir l'icône. L'application installée a son **propre stockage** : elle
   démarre vide, les relevés saisis dans Safari n'y sont pas copiés.

Après chaque publication : ouvrir l'application une fois **avec** connexion
(le service worker télécharge alors la nouvelle version), puis elle fonctionne
hors ligne. Si elle reste bloquée au chargement, un bouton « Réparer et
recharger » apparaît au bout de 20 s.

## Fonctionnement hors ligne

- `web/index.html` enregistre `web/offline_worker.js` (réseau d'abord, cache en secours).
- `web/flutter_bootstrap.js` n'enregistre **pas** le service worker de Flutter.
- Pour repartir d'un cache vide, changer `VERSION` dans `offline_worker.js`.

## Développement

```powershell
flutter run -d chrome
```

## Lecture du compteur sur photo (OCR)

Le bouton « Lire depuis une photo » utilise Tesseract.js, hébergé avec l'application.
Avant le premier build, télécharger les fichiers une seule fois :

```powershell
powershell -ExecutionPolicy Bypass -File tool\fetch_ocr.ps1
```

Cela remplit `web/ocr/` (≈ 15 Mo). Le premier usage doit se faire en ligne ; les
fichiers sont ensuite mis en cache pour l'utilisation hors connexion.
