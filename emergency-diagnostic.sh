#!/bin/bash

echo "🚨 EMERGENCY SECURITY DIAGNOSTIC"
echo "================================"
echo "Analyzing why direct internet access is working..."
echo ""

# 1. Check current firewall status
echo "1. CURRENT FIREWALL STATUS:"
echo "─────────────────────────────"
docker exec -u root whonix-workstation bash -c '
echo "iptables OUTPUT chain:"
iptables -L OUTPUT -n -v --line-numbers 2>/dev/null || echo "iptables not available"

echo ""
echo "iptables policy:"
iptables -L OUTPUT | head -1 2>/dev/null || echo "Cannot check policy"
'

echo ""
echo "2. NETWORK INTERFACES:"
echo "─────────────────────────"
docker exec whonix-workstation bash -c '
echo "Active interfaces:"
ip addr show | grep -E "inet|BROADCAST"

echo ""
echo "Routing table:"
ip route show
'

echo ""
echo "3. DNS CONFIGURATION:"
echo "─────────────────────────"
docker exec whonix-workstation cat /etc/resolv.conf

echo ""
echo "4. CHECKING IF ROUTING SCRIPT RAN:"
echo "─────────────────────────────────"
docker exec whonix-workstation bash -c '
echo "Checking if routing.sh exists and is executable:"
ls -la /usr/local/bin/routing.sh

echo ""
echo "Checking recent logs for routing execution:"
grep -i "routing\|iptables" /var/log/syslog 2>/dev/null | tail -5 || echo "No syslog available"
'

echo ""
echo "5. DOCKER NETWORK ANALYSIS:"
echo "──────────────────────────"
echo "Container networks:"
docker inspect whonix-workstation | grep -A 20 "Networks"

echo ""
echo "Available Docker networks:"
docker network ls | grep whonix

echo ""
echo "6. TESTING DIFFERENT ROUTES:"
echo "──────────────────────────"
docker exec whonix-workstation bash -c '
echo "Testing through different interfaces:"

echo -n "Direct curl to 1.1.1.1: "
timeout 2 curl -s --interface eth0 http://1.1.1.1 >/dev/null 2>&1 && echo "WORKS (BAD!)" || echo "Blocked (good)"

echo -n "Via Tor proxy: "
timeout 5 curl -s --socks5 10.152.152.10:9050 https://api.ipify.org >/dev/null 2>&1 && echo "WORKS (good)" || echo "Failed (bad)"

echo -n "DNS to 8.8.8.8: "
timeout 2 nslookup google.com 8.8.8.8 >/dev/null 2>&1 && echo "WORKS (BAD!)" || echo "Blocked (good)"
'

echo ""
echo "7. CONTAINER CAPABILITIES:"
echo "────────────────────────"
docker exec whonix-workstation bash -c '
echo "Container capabilities:"
cat /proc/self/status | grep Cap

echo ""
echo "Effective UID:"
id
'

echo ""
echo "8. EMERGENCY FIX ATTEMPT:"
echo "────────────────────────"
echo "Attempting to apply emergency firewall rules..."

docker exec -u root whonix-workstation bash -c '
# Clear all rules
iptables -F OUTPUT 2>/dev/null || true

# Set DROP policy
iptables -P OUTPUT DROP 2>/dev/null || echo "Cannot set DROP policy"

# Allow essentials
iptables -A OUTPUT -o lo -j ACCEPT 2>/dev/null || true
iptables -A OUTPUT -d 10.152.152.10 -j ACCEPT 2>/dev/null || true
iptables -A OUTPUT -d 127.0.0.0/8 -j ACCEPT 2>/dev/null || true
iptables -A OUTPUT -d 10.0.0.0/8 -j ACCEPT 2>/dev/null || true
iptables -A OUTPUT -d 172.16.0.0/12 -j ACCEPT 2>/dev/null || true
iptables -A OUTPUT -d 192.168.0.0/16 -j ACCEPT 2>/dev/null || true

# Block everything else
iptables -A OUTPUT -j REJECT --reject-with icmp-net-unreachable 2>/dev/null || true

echo "Emergency rules applied!"
echo ""
echo "New iptables rules:"
iptables -L OUTPUT -n --line-numbers
'

echo ""
echo "9. POST-FIX LEAK TEST:"
echo "────────────────────"
docker exec whonix-workstation bash -c '
for ip in 1.1.1.1 8.8.8.8; do
    echo -n "Testing $ip after fix: "
    timeout 2 curl -s $ip 2>&1 | grep -q "unreachable\|refused\|timeout" && echo "✓ BLOCKED" || echo "✗ STILL LEAKING"
done

echo -n "Tor still working: "
timeout 5 curl -s --socks5 10.152.152.10:9050 https://api.ipify.org >/dev/null 2>&1 && echo "✓ YES" || echo "✗ NO"
'

echo ""
echo "================================"
echo "🔍 DIAGNOSIS COMPLETE"
echo ""
echo "If leaks are still detected, the issue may be:"
echo "1. Docker network configuration allowing bypass"
echo "2. Missing NET_ADMIN capability for iptables"
echo "3. Container not properly isolated"
echo "4. Routing script not executing properly"
echo ""
echo "Run this script and share the output for further analysis."