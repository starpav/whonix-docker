#!/bin/bash

# Whonix-Docker Connectivity Test
# Проверяет доступность различных сервисов

echo "=== Whonix-Docker Connectivity Test ==="
echo ""

GATEWAY_IP="${TOR_GATEWAY:-10.152.152.10}"

# Цвета
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Функция для тестирования
test_connection() {
    local name=$1
    local url=$2
    local proxy=$3
    
    echo -n "Testing $name... "
    
    if [ -n "$proxy" ]; then
        RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -x "$proxy" --max-time 10 "$url" 2>/dev/null)
    else
        RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null)
    fi
    
    if [ "$RESPONSE" = "200" ] || [ "$RESPONSE" = "301" ] || [ "$RESPONSE" = "302" ]; then
        echo -e "${GREEN}✓ Connected (HTTP $RESPONSE)${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed (HTTP $RESPONSE)${NC}"
        return 1
    fi
}

# 1. Тест Gateway
echo "1. Gateway Services:"
echo -n "   - Tor SOCKS proxy... "
if nc -z $GATEWAY_IP 9050 2>/dev/null; then
    echo -e "${GREEN}✓ Available${NC}"
else
    echo -e "${RED}✗ Not available${NC}"
fi

echo -n "   - Tor DNS service... "
if nc -z $GATEWAY_IP 5353 2>/dev/null; then
    echo -e "${GREEN}✓ Available${NC}"
else
    echo -e "${RED}✗ Not available${NC}"
fi

# 2. Тесты через Tor
echo ""
echo "2. External connectivity through Tor:"
test_connection "Tor Project" "https://torproject.org" "socks5://$GATEWAY_IP:9050"
test_connection "DuckDuckGo" "https://duckduckgo.com" "socks5://$GATEWAY_IP:9050"
test_connection "Debian" "https://debian.org" "socks5://$GATEWAY_IP:9050"
test_connection "GitHub" "https://github.com" "socks5://$GATEWAY_IP:9050"

# 3. Проверка Onion сервисов
echo ""
echo "3. Onion services (v3):"
test_connection "DuckDuckGo Onion" "https://duckduckgogg42xjoc72x3sjasowoarfbgcmvfimaftt6twagswzczad.onion" "socks5://$GATEWAY_IP:9050"

# 4. Проверка локальных сетей (если в dev режиме)
if [ "$DEV_MODE" = "true" ]; then
    echo ""
    echo "4. Local Docker networks:"
    
    # Пример проверки локального сервиса
    echo -n "   - Local services accessible... "
    if ping -c 1 -W 2 172.30.0.1 >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Yes${NC}"
    else
        echo -e "${YELLOW}⚠ No local services found${NC}"
    fi
fi

# 5. Проверка скорости
echo ""
echo "5. Connection speed test:"
echo -n "   Downloading test file (1MB)... "
START_TIME=$(date +%s.%N)
if curl -s -x socks5://$GATEWAY_IP:9050 -o /dev/null --max-time 30 https://www.ovh.net/files/1Mb.dat; then
    END_TIME=$(date +%s.%N)
    DURATION=$(echo "$END_TIME - $START_TIME" | bc)
    SPEED=$(echo "scale=2; 1024 / $DURATION" | bc)
    echo -e "${GREEN}✓ Done ($SPEED KB/s)${NC}"
else
    echo -e "${RED}✗ Failed${NC}"
fi

# 6. Резюме
echo ""
echo "======================================="
echo "Connectivity test completed."
echo ""
echo "Tips:"
echo "- Slow speeds are normal when using Tor"
echo "- Some sites may block Tor exit nodes"
echo "- Use 'docker logs whonix-gateway' to check Gateway logs"
echo "- Use 'docker exec whonix-gateway tor-resolve example.com' to test DNS"