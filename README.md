# Fingerabdruckleser auf Kali Linux: ThinkPad T480s / T480

Dieses Repository enthält ein Installationsskript für den Synaptics **Metallica MIS Touch Fingerprint Reader** mit der USB-ID `06cb:009a` unter Kali Linux.

Es verwendet:

- <a href="https://github.com/uunicorn/open-fprintd">`open-fprintd`</a>
- <a href="https://github.com/uunicorn/python-validity">`python-validity`</a>
- `fprintd` und PAM für die Anmeldung bzw. `sudo`-Authentifizierung

> **Status:** Erfolgreich getestet auf einem Lenovo ThinkPad **T480s** mit Kali Linux und dem Sensor `06cb:009a`.

## Kompatibilität

| Modell | Status | Voraussetzung |
|---|---|---|
| ThinkPad T480s | Getestet | `lsusb` zeigt `06cb:009a Synaptics, Inc. Metallica MIS Touch Fingerprint Reader` |
| ThinkPad T480 | Voraussichtlich kompatibel, nicht getestet | Nur Geräte mit derselben USB-ID `06cb:009a` |

Beim ThinkPad T480 ist der Fingerabdruckleser optional. Daher muss die tatsächliche Sensor-ID vor der Installation geprüft werden:

```bash
lsusb | grep -E '06cb|fingerprint|Fingerprint'
```

Das Skript darf nur verwendet werden, wenn die Ausgabe `06cb:009a` enthält. Bei einer anderen USB-ID beendet das Skript die Installation absichtlich.

## Voraussetzungen

- Kali Linux
- Ein ThinkPad mit erkanntem Sensor `06cb:009a`
- Internetzugang
- Ein Benutzer mit `sudo`-Rechten
- Ein zweites, geöffnetes Root-Terminal als Rückfallebene während der PAM-Konfiguration

## Installation

```bash
git clone https://github.com/otesys/T480sFingerprintKali.git
cd T480sFingerprintKali
chmod +x install-fingerprint.sh
bash -n install-fingerprint.sh
```

In einem **separaten Terminal** eine Root-Shell als Rückfallebene öffnen und offen lassen:

```bash
sudo -i
```

Danach das Skript im normalen Terminal starten:

```bash
sudo ./install-fingerprint.sh
```

Das Skript klont `open-fprintd` und `python-validity` in gepinnten Versionen in das Home-Verzeichnis des aufrufenden Benutzers (`~/open-fprintd`, `~/python-validity`). Diese Verzeichnisse dürfen nicht gelöscht werden, solange der Dienst darauf verweist (prüfbar mit `systemctl cat python3-validity`).

Vor Änderungen wird ein Backup angelegt unter:

```text
/root/fingerprint-backup-YYYYMMDD-HHMMSS/
```

## PAM konfigurieren

Während der Installation startet `pam-auth-update`.

1. `Fingerprint authentication` auswählen.
2. Die Auswahl bestätigen.
3. Das offene Root-Terminal erst schließen, nachdem `sudo` erfolgreich getestet wurde.

## Fingerabdruck anlernen

```bash
fprintd-enroll "$USER"
fprintd-list "$USER"
```

## Funktion testen

```bash
fprintd-verify "$USER"
sudo -k
sudo true
```

## Diagnose

```bash
systemctl status python3-validity open-fprintd
sudo journalctl -u python3-validity -u open-fprintd -n 50 --no-pager
lsusb | grep 06cb:009a
```

## Sicherheits- und Betriebsrisiken

`python-validity` und `open-fprintd` sind experimentell. Laut Upstream fehlen dem Projekt vollständige Authentifizierungsprüfungen. Dieses Setup nicht als alleinigen Schutz für sensible Systeme oder Daten verwenden.

Das Skript verändert PAM-Konfigurationen, D-Bus-Richtlinien, systemd-Units und installiert Python-Pakete. Vorher wichtige Daten sichern.

## Rückweg

```bash
sudo systemctl stop python3-validity open-fprintd
sudo systemctl disable python3-validity open-fprintd-suspend open-fprintd-resume
sudo cp -a /root/fingerprint-backup-YYYYMMDD-HHMMSS/pam.d/. /etc/pam.d/
sudo systemctl restart systemd-logind
```

## Lizenz

Dieses Projekt soll unter der GNU General Public License v2.0 stehen. Die Datei `LICENSE` muss dafür den offiziellen GPLv2-Text enthalten (https://www.gnu.org/licenses/old-licenses/gpl-2.0.txt). Dies ist keine Rechtsberatung.

## Haftungsausschluss

Dieses Projekt wird ohne Gewährleistung bereitgestellt. Die Nutzung erfolgt vollständig auf eigenes Risiko.
