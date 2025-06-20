#!/bin/bash

echo "🔍 WHONIX-DOCKER STEP-BY-STEP TEST"
echo "==================================="
echo ""

# Каждая команда отдельно с || true чтобы не прерывался скрипт

echo "1️⃣ DNS Port Check:"
docker exec whonix-workstation nc -zv 10.152.152.10 5353 2>&1 || true
echo ""

echo "2️⃣ Tor Status Check:"
docker exec whonix-workstation curl -s --socks5 10.152.152.10:9050 --max-time 15 https://check.torproject.org/api/ip 2>&1 | head -20 || true
echo ""

echo "3️⃣ Get Tor IP:"
docker exec whonix-workstation curl -s --socks5 10.152.152.10:9050 --max-time 10 https://api.ipify.org 2>&1 || true
echo ""
echo ""

echo "4️⃣ DNS Resolution Test:"
docker exec whonix-workstation dig +short example.com @10.152.152.10 -p 5353 2>&1 || true
echo ""

echo "5️⃣ Direct Internet Block Test:"
docker exec whonix-workstation timeout 3 curl -s http://1.1.1.1 2>&1 || echo "✓ Blocked (good!)"
echo ""

echo "6️⃣ IPv6 Status:"
docker exec whonix-workstation cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>&1 || true
echo ""

echo "7️⃣ DNS Config:"
docker exec whonix-workstation grep nameserver /etc/resolv.conf 2>&1 || true
echo ""

echo "8️⃣ Routing Table:"
docker exec whonix-workstation ip route 2>&1 || true
echo ""

echo "9️⃣ Firewall Rules Count:"
docker exec -u root whonix-workstation iptables -L OUTPUT -n 2>&1 | grep -c "REJECT\|DROP" || echo "0"
echo ""

echo "🔟 Alternative Tor Check:"
docker exec whonix-workstation curl -s --socks5 10.152.152.10:9050 https://httpbin.org/ip 2>&1 || true
echo ""

echo "==================================="
echo "✅ All tests completed!"