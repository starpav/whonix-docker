#!/bin/bash

echo "🔍 DEEP SECURITY CHECK"
echo "====================="
echo ""

# 1. Проверка реальных правил iptables
echo "1. Current iptables rules (detailed):"
docker exec -u root whonix-workstation iptables -L OUTPUT -n -v --line-numbers
echo ""

# 2. Проверка политики
echo "2. OUTPUT chain policy:"
docker exec -u root whonix-workstation iptables -L OUTPUT | head -1
echo ""

# 3. Попытка установить DROP политику
echo "3. Setting DROP policy..."
docker exec -u root whonix-workstation iptables -P OUTPUT DROP 2>&1 || echo "Failed to set DROP"
docker exec -u root whonix-workstation iptables -L OUTPUT | head -1
echo ""

# 4. Содержимое routing.sh
echo "4. Content of routing.sh (iptables section):"
docker exec whonix-workstation grep -A20 -B5 "iptables" /usr/local/bin/routing.sh || echo "No iptables commands found"
echo ""

# 5. Проверка entrypoint.sh
echo "5. How routing.sh is called:"
docker exec whonix-workstation grep -A5 -B5 "routing" /usr/local/bin/entrypoint.sh
echo ""

# 6. Реальный тест безопасности
echo "6. Real security test:"
echo -n "   Direct IP (should fail): "
docker exec whonix-workstation timeout 2 curl -s http://1.1.1.1 >/dev/null 2>&1 && echo "❌ LEAKED!" || echo "✅ Blocked"

echo -n "   Direct DNS (should fail): "
docker exec whonix-workstation timeout 2 nslookup google.com 8.8.8.8 >/dev/null 2>&1 && echo "❌ LEAKED!" || echo "✅ Blocked"

echo -n "   Tor access (should work): "
docker exec whonix-workstation curl -s --socks5 10.152.152.10:9050 --max-time 5 https://api.ipify.org >/dev/null 2>&1 && echo "✅ Working" || echo "❌ Failed"
echo ""

# 7. Gateway статус после рестарта
echo "7. Gateway status:"
docker ps | grep gateway
docker logs whonix-gateway --tail 5 2>&1 | grep -E "(Bootstrapped|err|warn)"
echo ""

# 8. Альтернативный подсчет правил
echo "8. Firewall rules count (alternative):"
echo -n "   ACCEPT rules: "
docker exec -u root whonix-workstation iptables -L OUTPUT -n | grep -c "ACCEPT"
echo -n "   REJECT rules: "
docker exec -u root whonix-workstation iptables -L OUTPUT -n | grep -c "REJECT"
echo -n "   Total rules: "
docker exec -u root whonix-workstation iptables -L OUTPUT -n | tail -n +3 | wc -l
echo ""

echo "====================="
echo "✅ Deep check completed"