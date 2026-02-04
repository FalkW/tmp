#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo -e "\n[ERROR] in line $LINENO: exit code $?"' ERR

CTID="101"
CTID_CONFIG_PATH="/etc/pve/lxc/${CTID}.conf"

command -v pveversion >/dev/null

test -f "$CTID_CONFIG_PATH"

grep -q "lxc.cgroup2.devices.allow: c 10:200 rwm" "$CTID_CONFIG_PATH" \
  || echo "lxc.cgroup2.devices.allow: c 10:200 rwm" >>"$CTID_CONFIG_PATH"

grep -q "lxc.mount.entry: /dev/net/tun" "$CTID_CONFIG_PATH" \
  || echo "lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file" >>"$CTID_CONFIG_PATH"

pct exec "$CTID" -- bash -c '
set -e
export DEBIAN_FRONTEND=noninteractive

ID=$(grep "^ID=" /etc/os-release | cut -d"=" -f2 | tr -d "\"")
VER=$(grep "^VERSION_CODENAME=" /etc/os-release | cut -d"=" -f2 | tr -d "\"")

apt-get update -qq
apt-get install -y curl ca-certificates gnupg >/dev/null

curl -fsSL https://pkgs.tailscale.com/stable/${ID}/${VER}.noarmor.gpg \
  | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null

echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/${ID} ${VER} main" \
  >/etc/apt/sources.list.d/tailscale.list

apt-get update -qq
apt-get install -y tailscale >/dev/null

systemctl enable --now tailscaled >/dev/null 2>&1 || true
'

TAGS=$(awk -F': ' '/^tags:/ {print $2}' "$CTID_CONFIG_PATH" | head -n1 || true)
TAGS="${TAGS:+$TAGS; }tailscale"
pct set "$CTID" -tags "$TAGS" >/dev/null
