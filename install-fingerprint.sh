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
[ -n "$USER_NAME" ] && [ "$USER_NAME" != root ] || { echo "Bitte per sudo aus einem normalen Benutzer starten."; exit 1; }
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"

grep -qi kali /etc/os-release || { echo "Kein Kali erkannt."; exit 1; }
lsusb | grep -q "06cb:009a" || { echo "Sensor 06cb:009a nicht gefunden."; exit 1; }

OF_DIR="$USER_HOME/open-fprintd"
PV_DIR="$USER_HOME/python-validity"

echo "== Backup =="
BK="/root/fingerprint-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BK"
cp -a /etc/pam.d "$BK/pam.d"
cp -a /usr/share/dbus-1/system.d "$BK/dbus-system.d" 2>/dev/null || true
cp -a /usr/share/dbus-1/system-services "$BK/dbus-system-services" 2>/dev/null || true
echo "Backup in $BK"

echo "== Pakete =="
apt-get update
apt-get install -y git python3-pip python3-dbus python3-gi python3-setuptools \
  dbus libpam-fprintd fprintd usbutils \
  python3-usb python3-yaml python3-cryptography innoextract

clone_pinned() {
  local url="$1"
  local dir="$2"
  local commit="$3"

  if [ ! -d "$dir/.git" ]; then
    sudo -u "$USER_NAME" git clone "$url" "$dir"
  fi
  sudo -u "$USER_NAME" git -C "$dir" fetch --all -q
  sudo -u "$USER_NAME" git -C "$dir" checkout -q --detach "$commit"
}

echo "== Quellen holen (gepinnt) =="
clone_pinned "$OPEN_FPRINTD_REPO" "$OF_DIR" "$OPEN_FPRINTD_COMMIT"
clone_pinned "$VALIDITY_REPO" "$PV_DIR" "$VALIDITY_COMMIT"

echo "== open-fprintd installieren =="
( cd "$OF_DIR" && python3 setup.py install --force --install-layout deb --prefix=/usr --root=/ )
cp "$OF_DIR"/debian/open-fprintd*.service /usr/lib/systemd/system/

echo "== python-validity installieren =="
( cd "$PV_DIR" && { python3 -m pip install . 2>/dev/null || python3 -m pip install --break-system-packages . ; } )

if [ ! -e /usr/lib/systemd/system/python3-validity.service ] \
   && [ ! -e /etc/systemd/system/python3-validity.service ]; then
  SVC="$(find "$PV_DIR" -name 'python3-validity.service' | head -n1 || true)"
  if [ -n "$SVC" ]; then
    cp "$SVC" /usr/lib/systemd/system/
  else
    echo "WARNUNG: python3-validity.service nicht gefunden. Bitte manuell prüfen."
  fi
fi

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

echo "== Test =="
systemctl is-active python3-validity open-fprintd || true
sudo -u "$USER_NAME" fprintd-list "$USER_NAME" || true

echo "== PAM =="
echo "Jetzt im Menü 'Fingerprint authentication' aktivieren."
echo "Lass ein Root-Terminal offen, bevor du testest."
pam-auth-update

echo "Fertig. Finger anlernen mit: fprintd-enroll $USER_NAME"
