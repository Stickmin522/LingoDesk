# LingoDesk

[English](README.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · **Français** · [العربية](README.ar.md) · [Español](README.es.md) · [Deutsch](README.de.md)

LingoDesk transforme la voix et les sons diffusés sur votre appareil Android en sous-titres bilingues et en notes de réunion, en temps réel. Utilisez-le pendant vos cours, réunions et conversations, avec des sous-titres flottants qui restent visibles lorsque vous utilisez une autre application.

<p align="center"><img src="docs/images/lingodesk-logo-rounded.png" width="240" height="240" alt="LingoDesk" /></p>

## Captures d’écran

<p><img src="docs/images/captions.png" width="240" alt="LingoDesk" /> <img src="docs/images/overlay.png" width="240" alt="LingoDesk" /></p>

[Télécharger l’APK](https://github.com/Stickmin522/LingoDesk/releases/latest)

## Fonctionnalités

- Enregistrez le microphone, le son de l’appareil ou les deux à la fois.
- Choisissez deux langues différentes parmi les 60 langues prises en charge : la traduction fonctionne automatiquement dans les deux sens.
- Passez des sous-titres bilingues aux notes en direct avec un bouton.
- L’enregistrement et la traduction continuent en arrière-plan lorsque vous consultez l’historique ou utilisez d’autres applications. Arrêtez l’enregistrement dans l’application.
- Les sous-titres flottants apparaissent uniquement pendant une session active, lorsque vous quittez l’application. Déplacez et redimensionnez la fenêtre ; sa barre d’outils se masque automatiquement. Fermer la fenêtre ne coupe pas l’enregistrement.
- L’application mémorise l’activation, la position et la taille de la fenêtre flottante.
- Choisissez parmi 60 langues d’interface ou suivez la langue du système. Les langues non prises en charge par l’appareil s’affichent en anglais. Les polices sont celles du système.
- Réécoutez vos enregistrements et exportez-les en WAV, TXT, SRT ou JSON.
- Interface adaptée aux téléphones, tablettes, écrans pliables, au mode paysage et à l’écran partagé, avec thèmes clair et sombre.

## Premiers pas

Un appareil ARM64 sous Android 10 ou version ultérieure est nécessaire.

1. Installez l’APK et configurez le service décrit ci-dessous.
2. Choisissez deux langues différentes et une source audio, accordez les autorisations demandées et lancez l’enregistrement.
3. Activez les sous-titres flottants et l’autorisation d’affichage par-dessus les autres applications pour les lire depuis l’écran d’accueil pendant une session.
4. Revenez dans l’application pour arrêter et enregistrer. L’historique permet la lecture et l’exportation.

## LecSync

La reconnaissance vocale, la traduction et les notes utilisent l’API LecSync et nécessitent une connexion Internet. Créez votre propre clé API dans la [console LecSync](https://www.lecsync.com/dashboard/api), puis saisissez-la dans les paramètres de l’application. L’utilisation est facturée au compte associé à cette clé. L’application se connecte directement à l’API et ne dépend donc pas d’un site de traduction déployé séparément. Les enregistrements et l’historique restent sur votre appareil, sans synchronisation avec un compte du site. Consultez la [documentation de l’API](https://www.lecsync.com/developers) pour en savoir plus.

## Compiler le projet

Consultez le [guide de compilation](docs/BUILD.md).

## Mots-clés

Android, Flutter, Rust, Kotlin, traduction en direct, reconnaissance vocale, sous-titres bilingues, sous-titres flottants, enregistrement en arrière-plan, audio système, ARM64, Android 17, traduction multilingue, notes de réunion.
