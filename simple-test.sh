#!/bin/bash

echo "🔍 WHONIX-DOCKER SIMPLE TEST"
echo "============================"
echo ""

# 1. Проверка контейнеров
echo "1. Container Status:"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep whonix
echo ""

# 2. Почему Gateway unhealthy?
echo "2. Gateway Health Check:"
docker inspect whonix-gateway --format='{{.State.Health.Status}}: {{.State.Health.Log}}'
echo ""

# 3. Простая проверка из workstation
echo "3. Basic Connectivity Test:"
docker exec whonix-workstation bash -c 'nc -zv 10.152.152.10 9050 2>&1'
docker exec whonix-workstation bash -c 'nc -zv 10.152.152.10 5353 2>&1'
echo ""

# 4. Проверка Tor
echo "4. Tor Connection Test:"
docker exec whonix-workstation bash -c 'curl -s --socks5 10.152.152.10:9050 --max-time 15 https://check.torproject.org/api/ip | grep -o "IsTor\":[^,]*"'
echo ""

# 5. Получить IP через Tor
echo "5. Your Tor IP:"
docker exec whonix-workstation bash -c 'curl -s --socks5 10.152.152.10:9050 --max-time 10 https://api.ipify.org && echo'
echo ""

# 6. Проверка DNS
echo "6. DNS Test:"
docker exec whonix-workstation bash -c 'dig +short example.com @10.152.152.10 -p 5353'
echo ""

# 7. Проверка блокировки прямого доступа
echo "7. Security Check (should timeout):"
docker exec whonix-workstation bash -c 'timeout 3 curl -s http://1.1.1.1 || echo "✓ Direct access blocked"'
echo ""

# 8. Проверка настроек
echo "8. Workstation Configuration:"
docker exec whonix-workstation bash -c 'echo "IPv6: $(cat /proc/sys/net/ipv6/conf/all/disable_ipv6)"'
docker exec whonix-workstation bash -c 'echo "DNS: $(grep nameserver /etc/resolv.conf)"'
docker exec whonix-workstation bash -c 'echo "Default route: $(ip route | grep default)"'
echo ""

# 9. Проверка iptables
echo "9. Firewall Status:"
docker exec -u root whonix-workstation bash -c 'iptables -L OUTPUT -n | grep -c "REJECT\|DROP" | xargs echo "Blocking rules:"'
echo ""

echo "============================"
echo "Test completed!"