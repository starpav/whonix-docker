#!/bin/bash

echo "🔒 WHONIX-DOCKER SECURITY FIX"
echo "============================="
echo "Fixing the dual-interface leak vulnerability"
echo ""

# The problem: Container has two network interfaces
# eth0: 10.152.152.11 (tor_net) - routes through Tor Gateway
# eth1: 172.30.0.2 (dev_net) - bypasses Tor completely!

echo "🔍 Current problem analysis:"
echo "- eth0 (Tor): $(docker exec whonix-workstation ip addr show eth0 | grep inet | awk '{print $2}')"
echo "- eth1 (Dev):  $(docker exec whonix-workstation ip addr show eth1 | grep inet | awk '{print $2}')"
echo ""

# SOLUTION 1: Immediate firewall fix - block eth1 completely
echo "🛡️  SOLUTION 1: Immediate firewall fix"
echo "────────────────────────────────────"

docker exec -u root whonix-workstation bash << 'EOF'
echo "Applying strict firewall rules to block eth1..."

# Clear existing rules
iptables -F OUTPUT
iptables -F FORWARD 2>/dev/null || true

# Set strict DROP policy
iptables -P OUTPUT DROP

# Allow loopback (essential)
iptables -A OUTPUT -o lo -j ACCEPT

# Allow only to Tor Gateway through eth0
iptables -A OUTPUT -o eth0 -d 10.152.152.10 -j ACCEPT

# BLOCK ALL TRAFFIC ON ETH1 (dev network)
iptables -A OUTPUT -o eth1 -j REJECT --reject-with icmp-net-unreachable

# Allow local IPC within tor_net only
iptables -A OUTPUT -o eth0 -d 10.152.152.0/24 -j ACCEPT

# Explicitly block all other destinations
iptables -A OUTPUT -j REJECT --reject-with icmp-net-unreachable

echo "✅ Strict firewall applied!"
echo ""
echo "New iptables rules:"
iptables -L OUTPUT -n -v --line-numbers
EOF

echo ""
echo "🧪 TESTING AFTER FIREWALL FIX:"
echo "─────────────────────────────"

# Test the fix
docker exec whonix-workstation bash << 'EOF'
echo "Testing various leak vectors:"

for target in "1.1.1.1" "8.8.8.8" "google.com"; do
    echo -n "Direct to $target: "
    timeout 3 curl -s "$target" >/dev/null 2>&1 && echo "❌ LEAK!" || echo "✅ Blocked"
done

echo -n "Tor connectivity: "
timeout 10 curl -s --socks5 10.152.152.10:9050 https://api.ipify.org >/dev/null 2>&1 && echo "✅ Working" || echo "❌ Failed"

echo -n "DNS leak test: "
timeout 3 nslookup google.com 8.8.8.8 >/dev/null 2>&1 && echo "❌ LEAK!" || echo "✅ Blocked"
EOF

echo ""
echo "🔧 SOLUTION 2: Permanent Docker configuration fix"
echo "────────────────────────────────────────────────"

# Check current docker-compose setup
if [ -f "docker-compose.dev.yml" ]; then
    echo "⚠️  Found docker-compose.dev.yml which may override network settings"
    echo ""
    echo "Current dev_net configuration in docker-compose.dev.yml:"
    grep -A 5 "dev_net:" docker-compose.dev.yml || echo "No dev_net config found"
fi

echo ""
echo "Creating fixed docker-compose configuration..."

# Create a secure version
cat > docker-compose.secure.yml << 'SECURE_COMPOSE'
version: '3.8'

# Secure override - removes dev_net from workstation entirely
services:
  workstation:
    networks:
      tor_net:
        ipv4_address: 10.152.152.11
    # Remove dev_net completely for security
    environment:
      - DEV_MODE=false  # Disable dev mode features
      - SECURITY_MODE=strict

networks:
  tor_net:
    driver: bridge
    internal: true  # Ensure complete isolation
    ipam:
      driver: default
      config:
        - subnet: 10.152.152.0/24

# If you need dev_net for other containers, keep it separate:
  dev_net:
    driver: bridge
    internal: true  # MUST be internal
    ipam:
      driver: default
      config:
        - subnet: 172.30.0.0/24
SECURE_COMPOSE

echo "✅ Created docker-compose.secure.yml"

echo ""
echo "🔧 SOLUTION 3: Fix routing.sh to handle multiple interfaces"
echo "─────────────────────────────────────────────────────────"

# Create improved routing script
docker exec -u root whonix-workstation bash << 'EOF'
cat > /usr/local/bin/routing-secure.sh << 'ROUTING_SCRIPT'
#!/bin/bash
set -e

echo "🔒 Configuring SECURE Workstation routing..."

GATEWAY_IP="${TOR_GATEWAY:-10.152.152.10}"

# Get all network interfaces
ALL_INTERFACES=$(ip link show | grep -E '^[0-9]+:' | grep -v lo | awk -F': ' '{print $2}' | sed 's/@.*//')

echo "Found interfaces: $ALL_INTERFACES"

# Clear all existing rules
iptables -F OUTPUT 2>/dev/null || true
iptables -F FORWARD 2>/dev/null || true

# Set DROP policy (fail-secure)
iptables -P OUTPUT DROP

# Essential: allow loopback
iptables -A OUTPUT -o lo -j ACCEPT

# Find the Tor interface (should have route to 10.152.152.0/24)
TOR_IFACE=""
for iface in $ALL_INTERFACES; do
    if ip route show dev "$iface" | grep -q "10.152.152.0/24"; then
        TOR_IFACE="$iface"
        break
    fi
done

if [ -z "$TOR_IFACE" ]; then
    echo "❌ ERROR: No Tor network interface found!"
    exit 1
fi

echo "✅ Using Tor interface: $TOR_IFACE"

# ALLOW: Only traffic to Tor Gateway through Tor interface
iptables -A OUTPUT -o "$TOR_IFACE" -d "$GATEWAY_IP" -j ACCEPT

# ALLOW: Local communication within Tor network only
iptables -A OUTPUT -o "$TOR_IFACE" -d 10.152.152.0/24 -j ACCEPT

# BLOCK: All other interfaces explicitly
for iface in $ALL_INTERFACES; do
    if [ "$iface" != "$TOR_IFACE" ]; then
        echo "🚫 Blocking interface: $iface"
        iptables -A OUTPUT -o "$iface" -j REJECT --reject-with icmp-net-unreachable
    fi
done

# BLOCK: Everything else
iptables -A OUTPUT -j REJECT --reject-with icmp-net-unreachable

# Set up routing (remove any non-Tor defaults)
echo "Setting up secure routing..."

# Remove all default routes
ip route del default 2>/dev/null || true

# Add ONLY Tor gateway as default
ip route add default via "$GATEWAY_IP" dev "$TOR_IFACE"

echo "✅ Secure routing configuration completed!"
echo ""
echo "Active rules:"
iptables -L OUTPUT -n --line-numbers
echo ""
echo "Routing table:"
ip route show
ROUTING_SCRIPT

chmod +x /usr/local/bin/routing-secure.sh

echo "✅ Created secure routing script"
echo ""
echo "Applying secure routing now..."
/usr/local/bin/routing-secure.sh
EOF

echo ""
echo "🧪 FINAL SECURITY TEST:"
echo "────────────────────"

docker exec whonix-workstation bash << 'EOF'
echo "Comprehensive leak test:"

# Test direct IP access
for ip in "1.1.1.1" "8.8.8.8" "9.9.9.9"; do
    echo -n "Direct IP $ip: "
    timeout 3 curl -s --max-time 2 "http://$ip" >/dev/null 2>&1 && echo "❌ LEAK!" || echo "✅ Blocked"
done

# Test domain access
for domain in "google.com" "cloudflare.com" "github.com"; do
    echo -n "Direct domain $domain: "
    timeout 3 curl -s --max-time 2 "http://$domain" >/dev/null 2>&1 && echo "❌ LEAK!" || echo "✅ Blocked"
done

# Test DNS leaks
echo -n "DNS to 8.8.8.8: "
timeout 3 nslookup google.com 8.8.8.8 >/dev/null 2>&1 && echo "❌ LEAK!" || echo "✅ Blocked"

echo -n "DNS to 1.1.1.1: "
timeout 3 nslookup google.com 1.1.1.1 >/dev/null 2>&1 && echo "❌ LEAK!" || echo "✅ Blocked"

# Test Tor functionality
echo -n "Tor SOCKS proxy: "
timeout 10 curl -s --socks5 10.152.152.10:9050 https://check.torproject.org/api/ip >/dev/null 2>&1 && echo "✅ Working" || echo "❌ Failed"

echo -n "Getting Tor IP: "
TOR_IP=$(timeout 10 curl -s --socks5 10.152.152.10:9050 https://api.ipify.org 2>/dev/null)
if [ -n "$TOR_IP" ]; then
    echo "✅ $TOR_IP"
else
    echo "❌ Failed"
fi
EOF

echo ""
echo "🎯 NEXT STEPS:"
echo "─────────────"
echo ""
echo "1. IMMEDIATE: The firewall fix has been applied and should stop leaks"
echo ""
echo "2. PERMANENT: Choose one of these approaches:"
echo "   a) Use secure compose: docker-compose -f docker-compose.yml -f docker-compose.secure.yml up -d"
echo "   b) Edit docker-compose.yml to remove dev_net from workstation"
echo "   c) Keep using the secure routing script"
echo ""
echo "3. VERIFY: Run this test regularly:"
echo "   docker exec whonix-workstation timeout 3 curl -s http://1.1.1.1 && echo 'LEAK!' || echo 'SECURE'"
echo ""
echo "4. MONITOR: Check iptables rules:"
echo "   docker exec -u root whonix-workstation iptables -L OUTPUT -n"
echo ""

# Save the fix script for future use
cat > permanent-fix.sh << 'PERMANENT'
#!/bin/bash
# Permanent security fix for Whonix-Docker

echo "Applying permanent security fix..."

# Stop containers
docker-compose down

# Use secure configuration
docker-compose -f docker-compose.yml -f docker-compose.secure.yml up -d

echo "Waiting for containers to start..."
sleep 15

# Apply secure routing
docker exec -u root whonix-workstation /usr/local/bin/routing-secure.sh

echo "✅ Permanent fix applied!"
echo "Test with: docker exec whonix-workstation timeout 3 curl -s http://1.1.1.1 && echo 'LEAK!' || echo 'SECURE'"
PERMANENT

chmod +x permanent-fix.sh

echo "📁 CREATED FILES:"
echo "- docker-compose.secure.yml (secure network config)"
echo "- permanent-fix.sh (one-click permanent fix)"
echo ""
echo "🛡️  SECURITY STATUS: Current session should now be secure!"
echo "🔄 For permanent fix, run: ./permanent-fix.sh"