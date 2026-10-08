# LingoDesk

[English](README.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md) · [한국어](README.ko.md) · [Français](README.fr.md) · [العربية](README.ar.md) · [Español](README.es.md) · **Deutsch**

LingoDesk wandelt Sprache und den auf deinem Android-Gerät abgespielten Ton in zweisprachige Live-Untertitel und Besprechungsnotizen um. Die App eignet sich für Vorlesungen, Onlinekurse, Meetings und Gespräche. Mit schwebenden Untertiteln kannst du Übersetzungen auch beim Verwenden anderer Apps lesen.

<p align="center"><img src="docs/images/lingodesk-logo-rounded.png" width="240" height="240" alt="LingoDesk" /></p>

## Screenshots

<p><img src="docs/images/captions.png" width="240" alt="LingoDesk" /> <img src="docs/images/overlay.png" width="240" alt="LingoDesk" /></p>

[APK herunterladen](https://github.com/Stickmin522/LingoDesk/releases/latest)

## Funktionen

- Mikrofon, Geräteaudio oder beide Quellen gleichzeitig aufnehmen.
- Zwei unterschiedliche Sprachen aus 60 unterstützten Sprachen auswählen. Die Übersetzung funktioniert automatisch in beide Richtungen.
- Per Schaltfläche zwischen zweisprachigen Untertiteln und Live-Notizen wechseln.
- Aufnahme und Übersetzung laufen beim Ansehen früherer Aufnahmen und beim Wechsel in andere Apps im Hintergrund weiter. Die Aufnahme wird in der App beendet.
- Schwebende Untertitel erscheinen nur während einer aktiven Sitzung, wenn du die App verlässt. Das Fenster lässt sich verschieben und skalieren; die Werkzeugleiste blendet sich automatisch aus. Das Schließen des Fensters beendet die Aufnahme nicht.
- Aktivierung, Position und Größe des schwebenden Fensters werden gespeichert.
- 60 Oberflächensprachen auswählen oder der Systemsprache folgen. Auf dem Gerät nicht unterstützte Sprachen werden auf Englisch angezeigt. Die App verwendet Systemschriften.
- Gespeicherte Aufnahmen abspielen und als WAV, TXT, SRT oder JSON exportieren.
- Anpassung an Smartphones, Tablets, faltbare Geräte, Querformat und geteilte Bildschirme sowie helles und dunkles Design.

## Erste Schritte

Benötigt wird ein ARM64-Gerät mit Android 10 oder neuer.

1. Installiere die APK und richte den unten beschriebenen Dienst ein.
2. Wähle zwei unterschiedliche Sprachen und eine Audioquelle aus, erteile die erforderlichen Berechtigungen und starte die Aufnahme.
3. Aktiviere schwebende Untertitel und die Berechtigung zur Anzeige über anderen Apps. Während einer Aufnahme erscheinen die Untertitel nach der Rückkehr zum Startbildschirm.
4. Kehre zur App zurück, um die Aufnahme zu beenden und zu speichern. Im Verlauf kannst du sie abspielen oder exportieren.

## LecSync

Spracherkennung, Live-Übersetzung und Notizen verwenden die LecSync-API und benötigen eine Internetverbindung. Erstelle in der [LecSync-Konsole](https://www.lecsync.com/dashboard/api) deinen eigenen API-Schlüssel und trage ihn in den Einstellungen ein. Die Nutzung wird dem Konto dieses Schlüssels berechnet. Die App verbindet sich direkt mit der API und ist daher unabhängig von einer separat eingerichteten Übersetzungswebsite. Aufnahmen und Verlauf bleiben auf dem Gerät und werden nicht mit einem Website-Konto synchronisiert. Weitere Informationen stehen in der [API-Dokumentation](https://www.lecsync.com/developers).

## Aus dem Quellcode bauen

Siehe die [Build-Anleitung](docs/BUILD.md).

## Schlagwörter

Android, Flutter, Rust, Kotlin, Live-Übersetzung, Spracherkennung, zweisprachige Untertitel, schwebende Untertitel, Hintergrundaufnahme, Systemaudio, ARM64, Android 17, mehrsprachige Übersetzung, Besprechungsnotizen.
