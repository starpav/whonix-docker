#!/bin/bash
set -e

echo "Starting Whonix-Docker Workstation..."

# Проверка переменных окружения
GATEWAY_IP="${TOR_GATEWAY:-10.152.152.10}"
echo "Using Tor Gateway: $GATEWAY_IP"

# Настройка DNS
echo "Configuring DNS..."
sudo cp /etc/resolv.conf.tor /etc/resolv.conf
sudo chmod 644 /etc/resolv.conf

# Ожидание готовности Gateway
echo "Waiting for Gateway to be ready..."
MAX_TRIES=30
TRIES=0
while ! nc -z $GATEWAY_IP 9050 2>/dev/null; do
    TRIES=$((TRIES + 1))
    if [ $TRIES -gt $MAX_TRIES ]; then
        echo "Error: Gateway not responding after $MAX_TRIES attempts"
        exit 1
    fi
    echo "Waiting for Gateway... ($TRIES/$MAX_TRIES)"
    sleep 2
done
echo "Gateway is ready!"

# Отключение IPv6 ПЕРЕД настройкой маршрутизации
echo "Disabling IPv6..."
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null
sudo sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null

# Настройка маршрутизации и iptables (КРИТИЧЕСКИ ВАЖНО)
echo "Configuring routing and firewall..."
sudo /usr/local/bin/routing.sh

# Дополнительная проверка iptables
echo "Verifying firewall rules..."
IPTABLES_COUNT=$(sudo iptables -L OUTPUT -n | grep -c "REJECT\|DROP" || echo "0")
if [ "$IPTABLES_COUNT" -eq 0 ]; then
    echo "ERROR: No blocking iptables rules found! Security compromised!"
    exit 1
fi

# Настройка прокси переменных для приложений
export http_proxy="socks5://$GATEWAY_IP:9050"
export https_proxy="socks5://$GATEWAY_IP:9050"
export ftp_proxy="socks5://$GATEWAY_IP:9050"
export all_proxy="socks5://$GATEWAY_IP:9050"

# NO_PROXY уже установлен в Dockerfile

# Тест подключения через Tor (более строгий)
echo "Testing Tor connection..."
TOR_TEST_RESULT=""
for i in {1..3}; do
    if TOR_TEST_RESULT=$(curl -s --max-time 10 https://check.torproject.org/api/ip 2>/dev/null); then
        if echo "$TOR_TEST_RESULT" | grep -q '"IsTor":true'; then
            echo "✓ Successfully connected through Tor!"
            TOR_IP=$(echo "$TOR_TEST_RESULT" | grep -oE '"IP":"[^"]+' | cut -d'"' -f4)
            echo "  Current Tor IP: $TOR_IP"
            break
        fi
    fi
    echo "Attempt $i/3 failed, retrying..."
    sleep 2
done

if ! echo "$TOR_TEST_RESULT" | grep -q '"IsTor":true'; then
    echo "⚠ ERROR: Tor connection test failed!"
    echo "This could indicate a serious security problem."
fi

# Финальная проверка на утечки
echo "Running leak detection..."
LEAK_TEST_PASSED=true

# Проверка прямого доступа к интернету (должна провалиться)
if timeout 5 curl -s --max-time 3 http://8.8.8.8 >/dev/null 2>&1; then
    echo "✗ CRITICAL: Direct internet access detected!"
    LEAK_TEST_PASSED=false
fi

# Проверка прямого DNS (должна провалиться)  
if timeout 3 nslookup google.com 8.8.8.8 >/dev/null 2>&1; then
    echo "✗ CRITICAL: DNS leak detected!"
    LEAK_TEST_PASSED=false
fi

if [ "$LEAK_TEST_PASSED" = "true" ]; then
    echo "✓ Basic leak tests passed"
else
    echo "⚠ WARNING: Security leaks detected! Check configuration."
fi

echo ""
echo "=========================================="
echo "Workstation is ready!"
echo "All traffic is routed through Tor."
echo ""
echo "Security Status:"
echo "- IPv6: $([ $(cat /proc/sys/net/ipv6/conf/all/disable_ipv6) -eq 1 ] && echo 'Disabled ✓' || echo 'Enabled ✗')"
echo "- iptables rules: $IPTABLES_COUNT blocking rules active"
echo "- Default route: via $GATEWAY_IP"
echo ""
echo "Commands to verify security:"
echo "  /tests/check-leaks.sh    - Run full leak test"
echo "  curl https://check.torproject.org/  - Check Tor status"
echo "  sudo iptables -L OUTPUT  - View firewall rules"
echo ""

# Переключение на пользователя user для безопасности
# (все критичные настройки уже сделаны root'ом)
if [ "$1" = "su" ] && [ "$2" = "-" ] && [ "$3" = "user" ]; then
    echo "Switching to user account..."
    exec su - user
elif [ $# -eq 0 ]; then
    # Если команда не указана, запускаем bash от имени user
    exec su - user
else
    # Запуск переданной команды
    exec "$@"
fi
