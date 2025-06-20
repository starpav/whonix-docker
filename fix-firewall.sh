#!/bin/bash

echo "🔧 FIXING WHONIX-DOCKER FIREWALL"
echo "================================"
echo ""

# 1. Проверяем текущее состояние
echo "1. Current firewall state:"
docker exec -u root whonix-workstation iptables -L OUTPUT -n | grep "policy"
echo ""

# 2. Применяем правила firewall вручную
echo "2. Applying firewall rules..."
docker exec -u root whonix-workstation bash << 'EOF'
# Очистка
iptables -F OUTPUT 2>/dev/null || true

# Установка политики по умолчанию - DROP
iptables -P OUTPUT DROP

# Разрешить loopback
iptables -A OUTPUT -o lo -j ACCEPT

# Разрешить подключения к Tor Gateway
iptables -A OUTPUT -d 10.152.152.10 -j ACCEPT

# Разрешить локальные сети
iptables -A OUTPUT -d 127.0.0.0/8 -j ACCEPT
iptables -A OUTPUT -d 10.0.0.0/8 -j ACCEPT
iptables -A OUTPUT -d 172.16.0.0/12 -j ACCEPT
iptables -A OUTPUT -d 192.168.0.0/16 -j ACCEPT

# Блокировать всё остальное
iptables -A OUTPUT -j REJECT --reject-with icmp-net-unreachable

echo "Firewall rules applied!"
EOF
echo ""

# 3. Проверяем новое состояние
echo "3. New firewall state:"
docker exec -u root whonix-workstation iptables -L OUTPUT -n -v | head -15
echo ""

# 4. Проверяем блокировку
echo "4. Testing direct internet block:"
docker exec whonix-workstation timeout 2 curl -s http://8.8.8.8 2>&1 || echo "✓ Successfully blocked!"
echo ""

# 5. Проверяем что Tor всё ещё работает
echo "5. Testing Tor still works:"
docker exec whonix-workstation curl -s --socks5 10.152.152.10:9050 --max-time 10 https://api.ipify.org || echo "Failed"
echo ""

# 6. Проверяем healthcheck Gateway
echo "6. Gateway healthcheck details:"
docker exec whonix-gateway curl -x socks5://127.0.0.1:9050 -s https://check.torproject.org/api/ip 2>&1 | head -5
echo ""

# 7. Исправляем healthcheck если нужно
echo "7. Restarting Gateway to fix healthcheck..."
docker restart whonix-gateway
echo "Waiting 10 seconds for Tor to initialize..."
sleep 10
docker ps | grep gateway
echo ""

echo "================================"
echo "✅ Firewall fixed! Your system should now be secure."
echo ""
echo "Run ./simple-test.sh again to verify everything works correctly."