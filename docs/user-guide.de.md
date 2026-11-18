# AstroManager Benutzeranleitung

Diese Anleitung beschreibt AstroManager v1.0.0. [English](user-guide.md)

## Installation und erster Start

Wähle in der [Installationsanleitung](installation.md#deutsch) das Paket
für dein Gerät. Der Einrichtungsassistent in der Übersicht führt dich durch
Sprache, Beobachtungsort und Ausrüstung. Du kannst Schritte überspringen und
den Assistenten in den Einstellungen erneut öffnen. Unter **Einstellungen →
App-Einstellungen → Sprache** kannst du Deutsch, Englisch oder die
Systemsprache wählen.

## Beobachtungsorte und Ausrüstung

Öffne **Einstellungen → Beobachtungsorte** und lege einen Ort an. Trage Name,
Breiten- und Längengrad in Dezimalgrad, Höhe in Metern und eine IANA-Zeitzone
wie `Europe/Berlin` ein. Die Standortberechtigung wird beim Auswählen von
**Aktuellen Standort verwenden** angefragt. Mit einem Standardort kannst du
die Übersicht mit deinen üblichen Koordinaten öffnen.

Wenn du die Himmelshelligkeit am Standort beobachtet hast, kannst du eine
**Bortle-Klasse von 1 bis 9** eintragen. Die Klasse fließt in Zielbewertungen
und Standortvergleiche ein und wird in Sicherungen gespeichert. Wähle
**Nicht eingestuft**, um den Eintrag zu löschen. **Beobachtungsorte
vergleichen** zeigt Dunkelheit, Sichtbarkeit, Prognose und verfügbare
Geländedaten für dasselbe Ziel und Datum an mehreren Orten.

Lege unter **Ausrüstung** Kameras, Optiken und Montierungen an. Aus
Sensorgröße, Brennweite und den gewählten Komponenten eines Optikprofils
berechnet AstroManager Bildfeld und Abbildungsmaßstab.

## Übersicht und Wetter

Wähle oben in der **Übersicht** den Beobachtungsort für die Widgets. Über
**Widgets verwalten** kannst du Widgets hinzufügen, ausblenden oder entfernen.
Wähle **Layout bearbeiten**, um sie am Griff zu ziehen, über die
Pfeilschaltflächen zu versetzen oder über **Größe ändern** anzupassen. Darunter
liegende Widgets rücken beim Ändern der Größe nach. Telefon-, Tablet- und
Desktop-Layouts werden getrennt gespeichert.

Die **7-Nächte-Prognose** zeigt klare Stunden. **Nur nachts** berücksichtigt
die astronomische Dunkelheit. **Ganzer Tag** zählt den örtlichen Kalendertag
von Mitternacht bis Mitternacht. Die Auswahl beeinflusst sowohl die Summe der
klaren Stunden als auch die längste klare Phase. Tippe auf einen Tag für
Details und Prognoseabdeckung.

Mit **Prognose aktualisieren** fragst du neue Daten für den gewählten Ort ab.
Andere Ansichten nutzen die aktualisierten Daten, wenn Ort und Zeitraum
übereinstimmen. Bei einem Abruffehler bleibt die letzte verfügbare Prognose
mit ihrem ursprünglichen Alter sichtbar.

## Himmelsziele, Atlas und Bildausschnitt

Unter **Himmelsziele** kannst du den mitgelieferten OpenNGC-Katalog nach Namen
und Bezeichnungen durchsuchen. Die Detailansicht zeigt Koordinaten,
Sichtbarkeit und vorhandene Katalogangaben. Die Zielempfehlung beurteilt
Zeitfenster anhand von Sichtbarkeit, Dunkelheit, Wetter, Mond, Ausrüstung und
der gespeicherten Bortle-Klasse. Eine aktuelle Prognose mit **100 %
Bewölkung** unterbricht geeignete Zeitfenster. Fehlende oder veraltete
Wetterdaten führen zu vorläufigen Bewertungen.

Öffne den **Himmelsatlas** und tippe auf ein Objekt. Tippe anschließend
oben auf seinen Namen, um Katalogdetails zu öffnen. Die Anzeige des
Gesichtsfelds folgt dem Zoom. Wähle ein Optikprofil und richte den
Kamerarahmen aus. Du kannst ihn verschieben, drehen, speichern und wieder
aufrufen. Die **Himmelskuppel** zeigt den lokalen Himmel für Ort und Zeit
samt Kamerarahmen. Auf kleinen Bildschirmen befinden sich die Atlasoptionen
im ausklappbaren Bedienfeld. Die Aladin-Steuerung lässt sich dort unter
**Info** einblenden.

Für den eingebetteten Atlas werden Aladin Lite und DSS2-Color-Bilder geladen.
Unter Windows kannst du den Atlas in der Web-App öffnen. Katalog und
geometrische Bildfeldberechnung sind lokal verfügbar.

## Eine Nacht planen

Öffne bei einem Ziel im Projekt die **Nachtplanung**. Übernimm oder ändere
Ort und Beobachtungsdatum und plane das Ziel mit Startzeit und Dauer ein.
Die **Nachtübersicht** zeigt astronomische Dunkelheit, freie Zeit und
eingeplante Ziele mit ihren Zeitfenstern. Dort kannst du Blöcke bearbeiten
oder löschen. Überlappungen werden markiert.

Die Zeitleiste reicht von örtlichem Mittag bis zum folgenden Mittag.
Startzeiten vor 12 Uhr liegen am nächsten Kalendertag. Bei der Umstellung
auf Winterzeit helfen UTC-Abweichungen beim Unterscheiden gleichlautender
Uhrzeiten. Unter den Zeitleistenoptionen kannst du Mindesthöhe, Zoom,
Wetteranzeige und die Berücksichtigung des Geländehorizonts einstellen.

Ein Geländeprofil wird am gespeicherten Standort geladen und kann danach
offline angezeigt werden. Die Geländeabdeckung hängt vom Datensatz ab.
Gebäude und Bäume fehlen im Modell. Unbekannte Richtungen sind in der
Profilanzeige als solche erkennbar.

## Projekte, Sessions und Mosaike

Erstelle unter **Projekte** ein Aufnahmeprojekt mit Katalogzielen, Setup,
Notizen, Status und optionalem Integrationsziel. Protokolliere für jede
Session unter anderem Ort, Zeit, Ausrüstung, Belichtungsdauer und die Zahl
akzeptierter und verworfener Frames. Nur akzeptierte Frames tragen zur
nutzbaren Integration bei. Sie ergibt sich aus Belichtungsdauer pro Frame
mal Anzahl akzeptierter Frames.

In den Projektdetails kannst du ein **Mosaik** planen. Wähle Ziel und
Optikprofil, gib Zeilen, Spalten, Überlappung und Drehung an und prüfe die
Vorschau. Das gespeicherte Mosaik kannst du im Atlas öffnen oder als
JSON-Datei mit Panel-Koordinaten in ICRS/J2000 exportieren. Die
Montierungssteuerung liegt bei deiner Aufnahmesoftware.

## Benachrichtigungen

Unter **Einstellungen → Beobachtungsbenachrichtigungen** kannst du auf
Android und iOS Regeln für Ziel, Ort, Mindestbewertung und Mindestdauer
anlegen. Aktiviere die App-Berechtigung, wenn du Systembenachrichtigungen
erhalten möchtest. Die Prüfung läuft beim App-Start, bei der Rückkehr in den
Vordergrund oder über **Jetzt prüfen**. Eine Benachrichtigung erfordert
verwertbare aktuelle Wetterdaten. Die App merkt sich bereits gemeldete
Gelegenheiten.

## Sicherung, Offlinebetrieb und Hilfe

Unter **Einstellungen → Sicherung und Wiederherstellung** erstellst du ein
`.ambackup`. Aktiviere bei Bedarf **Session-Bilder einschließen**. Bewahre
die unverschlüsselte Sicherungsdatei privat und getrennt vom Gerät auf.
Die Wiederherstellung prüft das Archiv und zeigt eine Vorschau.
**Zusammenführen** bricht bei ID-Konflikten ab. **Alle Daten ersetzen**
erfordert eine zusätzliche Bestätigung. Unterstützte ältere ZIP-Sicherungen
können ebenfalls gewählt werden.

Katalog, Planung, Logs und gesicherte Daten sind lokal nutzbar. Onlinezugang
wird für neue Wetterdaten, Höhenwerte und Atlasbilder benötigt. Beim Web-Build
kann ein Neuladen davon abhängen, ob der Server erreichbar ist oder der
Browser die App zwischengespeichert hat.

| Wenn etwas fehlt | Prüfen |
| --- | --- |
| Prognose | Ort, Datum, Internetverbindung, Abrufalter und Abdeckung |
| Geländeprofil | Geländedatensatz, Profilparameter und vorherigen Abruf; Browserbeschränkungen können einen Abruf verhindern |
| Atlasbilder | Netzwerk, WebGL oder System-WebView und **Erneut versuchen** |
| Benachrichtigung | Regel, Geräteberechtigung, Wetterdaten und Zeitpunkt der letzten Prüfung |
| Daten nach Neuinstallation | Sicherung aus dem bisherigen Profil wiederherstellen |

[Datenschutz und Netzwerkzugriffe](privacy.md) ·
[Datenquellen und Grenzen](data-sources.md) ·
[Technisches Backupformat](backup-format.md)
