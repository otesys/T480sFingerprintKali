#!/usr/bin/env bash
# Fingerprint-Setup für Kali (Sensor 06cb:009a) mit open-fprintd + python-validity
# Benutzung: sudo ./install-fingerprint.sh
set -euo pipefail

OPEN_FPRINTD_REPO="https://github.com/uunicorn/open-fprintd.git"
OPEN_FPRINTD_COMMIT="b7073730bccca36e84484e3fcb4f8253ea038d07"
VALIDITY_REPO="https://github.com/uunicorn/python-validity.git"
VALIDITY_COMMIT="a6bbc21dce7b8b3c3cd92378a0b2579a2fb45920"

[ "$EUID" -eq 0 ] || { echo "Bitte mit sudo ausführen."; exit 1; }
USER_NAME="${SUDO_USER:-}"
if [ -z "$USER_NAME" ] || [ "$USER_NAME" = root ]; then echo "Bitte per sudo aus einem normalen Benutzer starten."; exit 1; fi

grep -qi kali /etc/os-release || { echo "Kein Kali erkannt."; exit 1; }
lsusb | grep -q "06cb:009a" || { echo "Sensor 06cb:009a nicht gefunden."; exit 1; }

echo "Hinweis: Öffne jetzt einen zweiten Terminal-Tab (oder eine TTY mit Strg+Alt+F3), starte dort 'sudo -i' und lass die Sitzung offen. Sie dient als Rückfallebene, falls die PAM-Konfiguration Probleme macht."
read -r -p "Zum Fortfahren Enter drücken ... "

echo "== Backup =="
BK="/root/fingerprint-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BK"
cp -a /etc/pam.d "$BK/pam.d" 2>/dev/null || true
cp -a /usr/share/dbus-1/system.d "$BK/dbus-system.d" 2>/dev/null || true
cp -a /usr/share/dbus-1/system-services "$BK/dbus-system-services" 2>/dev/null || true
cp -a /etc/systemd/system/python3-validity.service "$BK/" 2>/dev/null || true
echo "Backup in $BK"

echo "== Pakete =="
apt-get update
apt-get install -y git python3-pip python3-venv python3-dbus python3-gi python3-setuptools \
  dbus libpam-fprintd fprintd usbutils \
  python3-usb python3-yaml python3-cryptography innoextract

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
OF_DIR="$WORK/open-fprintd"
PV_DIR="$WORK/python-validity"
VENV=/opt/python-validity

clone_pinned() {
  local url="$1"
  local dir="$2"
  local commit="$3"

  git clone -q "$url" "$dir"
  git -C "$dir" checkout -q --detach "$commit"
}

echo "== Quellen holen (gepinnt) =="
clone_pinned "$OPEN_FPRINTD_REPO" "$OF_DIR" "$OPEN_FPRINTD_COMMIT"
clone_pinned "$VALIDITY_REPO" "$PV_DIR" "$VALIDITY_COMMIT"

echo "== open-fprintd installieren =="
( cd "$OF_DIR" && python3 setup.py install --force --install-layout deb --prefix=/usr --root=/ )
cp "$OF_DIR"/debian/open-fprintd*.service /usr/lib/systemd/system/

echo "== python-validity installieren (venv in $VENV) =="
rm -rf "$VENV"
python3 -m venv --system-site-packages "$VENV"
"$VENV/bin/python3" -m pip install "$PV_DIR"

DBUS_SERVICE="$VENV/lib/python-validity/dbus-service"
FW_TOOL="$VENV/bin/validity-sensors-firmware"
if [ ! -f "$DBUS_SERVICE" ]; then
  FOUND="$(find "$VENV" -name dbus-service -type f | head -n1 || true)"
  [ -z "$FOUND" ] || DBUS_SERVICE="$FOUND"
fi
if [ ! -x "$FW_TOOL" ]; then
  FOUND="$(find "$VENV" -name validity-sensors-firmware -type f | head -n1 || true)"
  [ -z "$FOUND" ] || FW_TOOL="$FOUND"
fi
test -f "$DBUS_SERVICE" || { echo "FEHLER: dbus-service nicht gefunden (siehe: find $VENV)."; exit 1; }
test -x "$FW_TOOL" || { echo "FEHLER: validity-sensors-firmware nicht gefunden/ausführbar (siehe: find $VENV)."; exit 1; }

echo "== systemd-Unit python3-validity =="
cat > /etc/systemd/system/python3-validity.service <<EOF
[Unit]
Description=python-validity driver dbus service
After=open-fprintd.service dbus.service

[Service]
Type=simple
ExecStartPre=$FW_TOOL
ExecStart=$VENV/bin/python3 $DBUS_SERVICE --debug
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "== D-Bus-Policies =="
install -m 644 "$OF_DIR/dbus_service/net.reactivated.Fprint.conf" /usr/share/dbus-1/system.d/
install -m 644 "$OF_DIR/dbus_service/net.reactivated.Fprint.service" /usr/share/dbus-1/system-services/
install -m 644 "$PV_DIR/dbus_service/io.github.uunicorn.Fprint.conf" /usr/share/dbus-1/system.d/
systemctl reload dbus

echo "== Dienste =="
systemctl daemon-reload
systemctl enable open-fprintd-suspend.service open-fprintd-resume.service || true
systemctl enable python3-validity.service || true
systemctl restart python3-validity.service
sleep 4

echo "== Systemd tmpfiles-Konfiguration =="
echo 'd /run/python-validity 0755 root root -' | sudo tee /etc/tmpfiles.d/python-validity.conf > /dev/null
sudo systemd-tmpfiles --create /etc/tmpfiles.d/python-validity.conf

echo "== Test =="
systemctl is-active python3-validity open-fprintd || true
sudo -u "$USER_NAME" fprintd-list "$USER_NAME" || true

echo "== PAM =="
echo "Im folgenden Menü bitte 'Fingerprint authentication' auswählen und aktivieren."
read -r -p "Zum Fortfahren Enter drücken ... "
pam-auth-update

echo "Fertig. Finger anlernen mit: fprintd-enroll $USER_NAME"
