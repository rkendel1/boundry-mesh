#!/usr/bin/env bash
# Boundry Mesh host preflight. READ-ONLY: every command below only reads state.
# It changes no firewall rule, restarts nothing and installs nothing.
#
# Run as root on the host:   sudo bash host-preflight.sh > mesh-preflight.txt 2>&1
# The output describes the host's network and firewall. Treat it as sensitive:
# keep it private and do not commit it to a public repository.
set -u
run() { printf '\n### %s\n' "$*"; "$@" 2>&1 || printf '[exit %s]\n' "$?"; }
sh_run() { printf '\n### %s\n' "$1"; bash -c "$1" 2>&1 || printf '[exit %s]\n' "$?"; }

printf 'boundry-mesh host preflight\ngenerated: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Kernel and WireGuard support
run uname -r
run modinfo wireguard
sh_run 'lsmod | grep -i wireguard || echo "wireguard module not loaded (may still be available)"'
sh_run 'command -v wg wg-quick || echo "wireguard-tools not installed"'
sh_run 'command -v mokutil >/dev/null && mokutil --sb-state || echo "mokutil not available"'

# Listeners (TCP and UDP)
run ss -lntup

# Firewall
sh_run 'command -v ufw >/dev/null && ufw status verbose || echo "ufw not present"'
sh_run 'grep -i ipv6 /etc/default/ufw 2>/dev/null || true'
sh_run 'command -v nft >/dev/null && nft list ruleset || echo "nft not present"'
sh_run 'command -v iptables >/dev/null && { iptables -S; iptables -t nat -S; } || echo "iptables not present"'
sh_run 'command -v ip6tables >/dev/null && ip6tables -S || echo "ip6tables not present"'

# Interfaces, addresses, routes
run ip -br link
run ip -br addr
run ip -4 route
run ip -6 addr
run ip -6 route
run ip rule
sh_run 'command -v wg >/dev/null && wg show interfaces || echo "wg not installed"'
run sysctl net.ipv4.ip_forward net.ipv6.conf.all.forwarding net.ipv4.conf.all.rp_filter

# Containers and their networks (names, images, published ports; no environment values)
sh_run "docker version --format '{{.Server.Version}}'"
sh_run "docker info --format 'live-restore={{.LiveRestoreEnabled}} cgroup={{.CgroupDriver}}'"
sh_run "docker ps --format '{{.Names}}\t{{.Image}}\t{{.Ports}}'"
sh_run "docker network ls -q | xargs -r docker network inspect --format '{{.Name}}\tipv6={{.EnableIPv6}}\t{{range .IPAM.Config}}{{.Subnet}} {{end}}'"

# Services and timers
sh_run "systemctl list-units --all --no-pager 'boundry*' 'appboundry*' 'wg-quick*' 'caddy*'"
run systemctl list-timers --all --no-pager

# DNS resolver configuration (for split DNS planning)
sh_run 'command -v resolvectl >/dev/null && resolvectl status --no-pager | head -40 || echo "resolvectl not present"'

# Backups: listing only, newest first
sh_run 'ls -lt /var/backups 2>/dev/null | head -20'

# Capacity
run nproc
run free -m
run df -h /

printf '\n### done\nNot visible from the host: the hosting provider firewall. Check it in the provider console.\n'
