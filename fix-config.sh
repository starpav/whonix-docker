#!/bin/bash

echo "🔧 FIXING WHONIX-DOCKER CONFIGURATION"
echo "===================================="
echo ""

# 1. Исправляем routing.sh
echo "1. Fixing routing.sh..."
docker exec -u root whonix-workstation bash << 'EOF'
# Создаем исправленную версию
cat > /usr/local/bin/routing-fixed.sh << 'SCRIPT'
#!/bin/bash
set -e

GATEWAY_IP="${TOR_GATEWAY:-10.152.152.10}"
DEV_MODE="${DEV_MODE:-false}"

echo "Configuring Workstation routing..."

# Получение интерфейсов
TOR_IFACE=$(ip route | grep "10.152.152.0/24" | awk '{print $3}')
if [ -z "$TOR_IFACE" ]; then
    echo "Error: Tor network interface not found!"
    exit 1
fi

# Очистка существующих правил
iptables -F OUTPUT 2>/dev/null || true

# КРИТИЧНО: Устанавливаем политику DROP
iptables -P OUTPUT DROP

# Разрешаем необходимое
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -d $GATEWAY_IP -j ACCEPT
iptables -A OUTPUT -d 127.0.0.0/8 -j ACCEPT
iptables -A OUTPUT -d 10.0.0.0/8 -j ACCEPT
iptables -A OUTPUT -d 172.16.0.0/12 -j ACCEPT
iptables -A OUTPUT -d 192.168.0.0/16 -j ACCEPT

# В dev режиме разрешаем больше
if [ "$DEV_MODE" = "true" ]; then
    DEV_IFACE=$(ip route | grep "172.30.0.0/24" | awk '{print $3}' || echo "")
    if [ -n "$DEV_IFACE" ]; then
        iptables -A OUTPUT -o $DEV_IFACE -j ACCEPT
    fi
fi

# ВАЖНО: Блокируем всё остальное
iptables -A OUTPUT -j REJECT --reject-with icmp-net-unreachable

# Настройка маршрутов
ip route del default 2>/dev/null || true
ip route add default via $GATEWAY_IP dev $TOR_IFACE

echo "Firewall rules applied:"
iptables -L OUTPUT -n -v --line-numbers
echo ""
echo "Routing configuration completed!"
SCRIPT

chmod 755 /usr/local/bin/routing-fixed.sh

# Сохраняем оригинал
cp /usr/local/bin/routing.sh /usr/local/bin/routing.sh.original

# Заменяем на исправленную версию
cp /usr/local/bin/routing-fixed.sh /usr/local/bin/routing.sh
echo "✓ routing.sh fixed!"
EOF
echo ""

# 2. Применяем исправленный скрипт
echo "2. Applying fixed routing..."
docker exec -u root whonix-workstation /usr/local/bin/routing.sh
echo ""

# 3. Проверяем healthcheck Gateway
echo "3. Checking Gateway healthcheck command..."
docker inspect whonix-gateway --format='{{json .Config.Healthcheck}}' | jq
echo ""

# 4. Проверяем healthcheck изнутри Gateway
echo "4. Testing healthcheck from inside Gateway..."
docker exec whonix-gateway sh -c 'curl -x socks5://127.0.0.1:9050 -s --max-time 10 https://check.torproject.org/api/ip | grep -o "IsTor":[^,}]*'
echo ""

# 5. Альтернативный healthcheck
echo "5. Alternative healthcheck test..."
docker exec whonix-gateway sh -c 'nc -z 127.0.0.1 9050 && echo "SOCKS port OK" || echo "SOCKS port FAILED"'
echo ""

# 6. Финальная проверка
echo "6. Final security check:"
docker exec -u root whonix-workstation bash -c '
echo -n "Firewall policy: "
iptables -L OUTPUT | head -1
echo -n "Blocking rules: "
iptables -L OUTPUT -n | grep -c "REJECT"
echo -n "Direct access blocked: "
timeout 1 curl -s http://1.1.1.1 2>&1 && echo "NO ❌" || echo "YES ✅"
echo -n "Tor working: "
curl -s --socks5 10.152.152.10:9050 --max-time 5 https://api.ipify.org >/dev/null 2>&1 && echo "YES ✅" || echo "NO ❌"
'
echo ""

echo "===================================="
echo "✅ Configuration fixed!"
echo ""
echo "To make changes permanent, update workstation/routing.sh in your project"
echo "and rebuild the container with: docker-compose build workstation"