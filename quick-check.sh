#!/bin/bash
echo "🔍 WHONIX-DOCKER QUICK CHECK"
echo "============================"
echo "Time: $(date)"
echo ""
echo "📦 Container Status:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep whonix || echo "No whonix containers running!"
echo ""
echo "🌉 Gateway Recent Logs:"
docker logs whonix-gateway --tail 5 2>&1 | grep -E "(Tor|Bootstrapped|err)" || echo "No gateway logs"
echo ""
echo "🔒 Running Security Check Inside Workstation:"
echo "--------------------------------------------"
docker exec -u root whonix-workstation bash << 'ENDSCRIPT'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
echo "1. Network Configuration:"
echo "   Gateway IP: ${TOR_GATEWAY:-10.152.152.10}"
echo "   My IP: $(ip addr show | grep 'inet 10.152.152' | awk '{print $2}' | cut -d'/' -f1)"
echo "   DNS Server: $(grep nameserver /etc/resolv.conf | awk '{print $2}')"
echo ""
echo "2. Gateway Services:"
echo -n "   SOCKS proxy (9050): "
nc -z 10.152.152.10 9050 2>/dev/null && echo -e "${GREEN}✓ OK${NC}" || echo -e "${RED}✗ FAIL${NC}"
echo -n "   DNS service (5353): "
nc -z 10.152.152.10 5353 2>/dev/null && echo -e "${GREEN}✓ OK${NC}" || echo -e "${RED}✗ FAIL${NC}"
echo ""
echo "3. Security Status:"
echo -n "   IPv6: "
[ "$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6)" = "1" ] && echo -e "${GREEN}✓ Disabled${NC}" || echo -e "${RED}✗ Enabled${NC}"
echo -n "   Firewall: "
iptables -L OUTPUT -n 2>/dev/null | grep -q "REJECT\|DROP" && echo -e "${GREEN}✓ Active${NC}" || echo -e "${RED}✗ Inactive${NC}"
echo -n "   Default route: "
ip route | grep default | grep -q "10.152.152.10" && echo -e "${GREEN}✓ Via Gateway${NC}" || echo -e "${RED}✗ Wrong${NC}"
echo ""
echo "4. Tor Connection Test:"
echo -n "   Checking Tor... "
TOR_RESULT=$(curl -s --socks5 10.152.152.10:9050 --max-time 10 https://check.torproject.org/api/ip 2>/dev/null)
if echo "$TOR_RESULT" | grep -q '"IsTor":true'; then
    echo -e "${GREEN}✓ CONNECTED${NC}"
    IP=$(echo "$TOR_RESULT" | grep -oE '"IP":"[^"]+' | cut -d'"' -f4)
    echo "   Your Tor IP: $IP"
else
    echo -e "${RED}✗ NOT CONNECTED${NC}"
    echo "   Response: $TOR_RESULT"
fi
echo ""
echo "5. Leak Tests:"
echo -n "   Direct internet: "
timeout 2 curl -s http://1.1.1.1 >/dev/null 2>&1 && echo -e "${RED}✗ LEAK!${NC}" || echo -e "${GREEN}✓ Blocked${NC}"
echo -n "   Direct DNS: "
timeout 2 nslookup google.com 8.8.8.8 >/dev/null 2>&1 && echo -e "${RED}✗ LEAK!${NC}" || echo -e "${GREEN}✓ Blocked${NC}"
echo ""
echo "6. Quick Performance:"
echo -n "   DNS via Tor: "
dig +short example.com @10.152.152.10 -p 5353 >/dev/null 2>&1 && echo -e "${GREEN}✓ Working${NC}" || echo -e "${RED}✗ Failed${NC}"
echo -n "   HTTP via Tor: "
TIME=$(curl -o /dev/null -s -w "%{time_total}" --socks5 10.152.152.10:9050 --max-time 10 https://example.com 2>/dev/null)
[ -n "$TIME" ] && echo -e "${GREEN}✓ ${TIME}s${NC}" || echo -e "${RED}✗ Failed${NC}"
ENDSCRIPT
echo ""
echo "============================"
echo "✅ Check completed!"
