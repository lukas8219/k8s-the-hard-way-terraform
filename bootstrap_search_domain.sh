#!/usr/bin/env bash
set -euxo pipefail

DOMAIN="kubernetes.local"

# Descobre interface default, ex: ens4
IFACE="$(ip route show default | awk '{print $5; exit}')"

# 1. Garante systemd-resolved ativo
systemctl enable --now systemd-resolved

# 2. Garante que /etc/resolv.conf aponta para o stub do resolved
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# 3. Aplica search domain diretamente na interface ativa
resolvectl domain "$IFACE" "$DOMAIN"
resolvectl default-route "$IFACE" yes

# 4. Persistência via systemd-networkd drop-in, se a interface for gerenciada por networkd
mkdir -p /etc/systemd/network/10-gce.network.d

cat >/etc/systemd/network/10-gce.network.d/search-domain.conf <<EOF
[Network]
Domains=${DOMAIN}
EOF

systemctl restart systemd-networkd || true
systemctl restart systemd-resolved

# 5. Reaplica depois do restart, porque DHCP pode sobrescrever no boot
resolvectl domain "$IFACE" "$DOMAIN"
