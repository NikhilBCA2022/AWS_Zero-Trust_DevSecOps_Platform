#!/bin/bash
set -euo pipefail

# Enable IPv4 forwarding.
cat >/etc/sysctl.d/99-runner-nat.conf <<'SYSCTL'
net.ipv4.ip_forward = 1
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
SYSCTL

sysctl --system

# Install and enable persistent iptables rules on Amazon Linux 2023.
dnf install -y iptables-services

systemctl enable iptables

# Clear existing forwarding and NAT rules before configuring them.
iptables -F FORWARD
iptables -t nat -F POSTROUTING

# Default-deny forwarded traffic.
iptables -P FORWARD DROP

# Allow return traffic for established connections.
iptables -A FORWARD \
  -m conntrack --ctstate ESTABLISHED,RELATED \
  -j ACCEPT

# Allow new HTTPS connections originating from the runner subnet.
iptables -A FORWARD \
  -s "${runner_subnet_cidr}" \
  ! -d "${vpc_cidr}" \
  -p tcp --dport 443 \
  -m conntrack --ctstate NEW,ESTABLISHED \
  -j ACCEPT

# Translate runner subnet addresses for outbound HTTPS connections.
iptables -t nat -A POSTROUTING \
  -s "${runner_subnet_cidr}" \
  -p tcp --dport 443 \
  -j MASQUERADE

# Persist rules across reboot.
service iptables save
systemctl restart iptables

echo "NAT bootstrap completed."
