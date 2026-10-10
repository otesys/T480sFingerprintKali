# T480sFingerprintKali

Repository für die Einrichtung eines Validity-Fingerabdrucksensors auf Kali Linux
mit `open-fprintd` und `python-validity`.

## Ziel

Dieses Projekt automatisiert die Einrichtung eines Synaptics-Fingerabdrucksensors vom Typ `06cb:009a` unter Kali Linux.

Die Installation basiert auf den in diesem Repository fest eingehängten Upstream-Commits:

- `open-fprintd` @ `b7073730bccca36e84484e3fcb4f8253ea038d07`
- `python-validity` @ `a6bbc21dce7b8b3c3cd92378a0b2579a2fb45920`

## Voraussetzungen

- Kali Linux
- Root-Rechte
- Sensor mit USB-ID `06cb:009a`
- `lsusb` muss den Sensor erkennen

## Installation

```bash
git clone https://github.com/otesys/T480sFingerprintKali.git
cd T480sFingerprintKali
chmod +x install-fingerprint.sh
sudo ./install-fingerprint.sh
```

## Wichtige Hinweise

- Das Installationsskript nutzt systemweite Pfade und keine Home-Verzeichnis-Abhängigkeiten.
- Nach der Installation erscheint das PAM-Menü; dort muss `Fingerprint authentication` aktiviert werden.
- Danach kann das System mit dem Fingerabdruck getestet werden.

## Nach der Installation

```bash
sudo pam-auth-update
fprintd-enroll "$USER"
```

## Test

```bash
sudo -k
sudo true
```

## Lizenz

Dieses Projekt ist unter der GNU General Public License v2 (GPLv2) veröffentlicht.

Siehe [`LICENSE`](LICENSE) für den vollständigen Text.

## Haftungsausschluss

Das Projekt wird ohne Gewährleistung bereitgestellt. Der Benutzer trägt die volle Verantwortung für die Nutzung und die Folgen einer Verwendung.

## Quellen

- https://github.com/uunicorn/open-fprintd
- https://github.com/uunicorn/python-validity
