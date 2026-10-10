# Fingerprint-Setup für Kali Linux (T480s)

Automatisiertes Installationsskript für Fingerprint-Authentifizierung auf Kali Linux mit `open-fprintd` + `python-validity` Backend.

Getestet auf:
- **Lenovo ThinkPad T480s** mit Synaptics Metallica MIS Touch Fingerprint Reader (USB ID `06cb:009a`)

## Kompatibilität mit anderen Modellen

Dieses Skript funktioniert **prinzipiell** mit allen Fingerprint-Sensoren, die von `python-validity` unterstützt werden. Das sind insbesondere:

- Synaptics-Sensoren (ID `06cb:*`):
  - T480s (getestet: `06cb:009a`)
  - T490
  - T580
  - X1 Carbon (Gen 5-7)
  - E580
  - E590
  - L14 Gen1

- Goodix-Sensoren (ID `27c6:*`):
  - Erfordern zusätzliche Firmware
  - T14 Gen1 und später (teilweise)

- Upek-Sensoren (Legacy, `147e:*`):
  - Limitierte Unterstützung
  - Funktioniert oft mit `libfprint` allein

**Vor der Nutzung auf anderen Modellen:**
1. Sensor-ID prüfen: `lsusb | grep -E "06cb|27c6|147e"`
2. Falls andere ID: Repository `python-validity` prüfen, ob dein Sensor darin gelistet ist
3. Ggf. andere Firmware-Quellen nötig (vor allem bei Goodix)

## Installation

### Voraussetzungen
- Kali Linux (aktuelle Version)
- Fingerprint-Sensor vorhanden und erkannt (`lsusb`)
- Sudo-Rechte

### Schritt 1: Repository klonen

```bash
git clone https://github.com/otesys/T480sFingerprintKali.git
cd T480sFingerprintKali
chmod +x install-fingerprint.sh
```

### Schritt 2: Installation ausführen

```bash
sudo ./install-fingerprint.sh
```

Das Skript wird dich unterwegs auffordern, im `pam-auth-update`-Menü "Fingerprint authentication" zu aktivieren. **Lass vorher ein Root-Terminal offen** (`sudo -i`), falls etwas schiefgeht.

### Schritt 3: Finger anlernen

Nach erfolgreicher Installation:

```bash
fprintd-enroll $USER
```

Finger mehrmals von Wurzel zur Spitze über den Sensor ziehen, bis "enroll-completed" erscheint.
Ohne weitere Angaben wird dies für den linken Zeigefinger gespeichert

### Schritt 4: Test

```bash
# Fingerabdruck als sudo prüfen
sudo -k
sudo true

# Mit Fingerabdruck verifizieren
fprintd-verify $USER
```

## Was macht das Skript?

1. **Prüfungen**: Kali, Root, Sensor vorhanden?
2. **Backup**: PAM- und D-Bus-Konfigurationen sichern
3. **Pakete**: Abhängigkeiten installieren
4. **Quellen**: `open-fprintd` und `python-validity` (an getestete Commits gepinnt)
5. **Installation**: Beide aus Source bauen
6. **D-Bus-Policy**: Korrekte Berechtigungen setzen
7. **Systemd-Units**: Services registrieren
8. **PAM**: Fingerprint-Authentifizierung für Login/sudo aktivieren
9. **Test**: Sensor erkannt?

## Fehlerbehandlung

### "No devices available"
- Sensor erkannt? → `lsusb | grep 06cb`
- D-Bus-Policy nicht geladen? → `systemctl reload dbus && systemctl restart python3-validity`
- Nach `apt upgrade`? → Skript erneut ausführen (überschreibt D-Bus-Dateien)

### "ListEnrolledFingers failed: AccessDenied"
- `io.github.uunicorn.Fprint.conf` fehlt? → `sudo systemctl reload dbus`

### PAM kaputt
- Root-Terminal öffnen und Backup zurückspielen:
  ```bash
  sudo cp -a /root/fingerprint-backup-YYYYMMDD-HHMMSS/pam.d/* /etc/pam.d/
  sudo systemctl restart systemd-logind
  ```

### Sensor wird nach Neustart nicht erkannt
- Firmware wird bei Reboot neu geladen. Normal, dauert ~5 Sekunden.
- Prüfen: `sudo journalctl -u python3-validity -n 20`

## Nach Neuinstallation von Kali

1. Dieses Repo klonen
2. `sudo ./install-fingerprint.sh` ausführen
3. Finger ggf. neu anlernen (`fprintd-enroll`)

**Hinweis**: Die Klone von `open-fprintd` und `python-validity` landen in `$HOME`. Sie dürfen **nicht gelöscht** werden, weil `python3-validity.service` `dbus-service` direkt von dort startet.

## Deinstallation

```bash
sudo systemctl stop python3-validity open-fprintd
sudo systemctl disable open-fprintd-suspend.service open-fprintd-resume.service
sudo apt remove libpam-fprintd fprintd
# Bei Bedarf: PAM zurücksetzen
sudo pam-auth-update
```

## Bekannte Einschränkungen

- **Keine Authentifizierungsprüfung**: `open-fprintd` setzt D-Bus-Policies nicht um. Das ist experimentell. Nicht für sensible Umgebungen empfohlen.
- **Neuinstallation**: Angelerni Finger können bei Neupaarung verloren gehen.
- **GDM**: Manche Display-Manager unterstützen Fingerprint-Login nicht. `sudo` funktioniert immer.

## Lizenz

Dieses Projekt ist unter der **GNU General Public License v2 (GPLv2)** lizenziert.

Siehe [`LICENSE`](LICENSE) für die vollständige Lizenzierungsinformation.

### Abhängigkeiten

- **open-fprintd**: GPLv2
- **python-validity**: MIT

Die Kombination wird unter GPLv2 veröffentlicht.

### Haftungsausschluss

Dieses Skript wird **AS IS** bereitgestellt, **ohne Haftung oder Garantie jeglicher Art**. Der Benutzer trägt die volle Verantwortung für die Nutzung und alle Folgen einer Verwendung.

## Weitere Links

- [uunicorn/open-fprintd](https://github.com/uunicorn/open-fprintd)
- [uunicorn/python-validity](https://github.com/uunicorn/python-validity)
- [fprintd Dokumentation](https://manpages.debian.org/fprintd)

## Support

Falls das Skript bei dir nicht funktioniert:
1. Sensor-ID posten: `lsusb | grep -E "06cb|27c6|147e"`
2. Logs: `sudo journalctl -u python3-validity -u open-fprintd -n 50`
3. Fehler: Vollständige Meldung des Skripts
