#!/bin/bash

# Whonix-Docker Leak Test Script
# Проверяет систему на утечки IP и DNS

echo "=== Whonix-Docker Leak Detection Test ==="
echo ""

GATEWAY_IP="${TOR_GATEWAY:-10.152.152.10}"
ERRORS=0

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Функция для проверки
check_test() {
    local test_name=$1
    local result=$2
    local expected=$3
    
    if [ "$result" = "$expected" ]; then
        echo -e "${GREEN}✓${NC} $test_name"
    else
        echo -e "${RED}✗${NC} $test_name"
        ERRORS=$((ERRORS + 1))
    fi
}

# 1. Проверка Tor подключения
echo "1. Checking Tor connection..."
TOR_CHECK=$(curl -s -x socks5://$GATEWAY_IP:9050 https://check.torproject.org/api/ip 2>/dev/null)
if echo "$TOR_CHECK" | grep -q '"IsTor":true'; then
    check_test "Tor connection active" "true" "true"
    TOR_IP=$(echo "$TOR_CHECK" | grep -oE '"IP":"[^"]+' | cut -d'"' -f4)
    echo "   Current Tor IP: $TOR_IP"
else
    check_test "Tor connection active" "false" "true"
fi

# 2. Проверка DNS резолвинга
echo ""
echo "2. Checking DNS resolution..."
DNS_TEST=$(dig +short example.com @$GATEWAY_IP -p 5353 2>/dev/null)
if [ -n "$DNS_TEST" ]; then
    check_test "DNS through Tor Gateway" "success" "success"
    echo "   Resolved IP: $DNS_TEST"
else
    check_test "DNS through Tor Gateway" "failed" "success"
fi

# 3. Проверка прямого DNS (должен быть заблокирован)
echo ""
echo "3. Checking for DNS leaks..."
LEAK_TEST=$(dig +short example.com @8.8.8.8 +timeout=2 2>&1)
if echo "$LEAK_TEST" | grep -qE "(timed out|refused|unreachable)"; then
    check_test "Direct DNS blocked" "blocked" "blocked"
else
    check_test "Direct DNS blocked" "leaked" "blocked"
    echo -e "   ${RED}WARNING: DNS leak detected!${NC}"
fi

# 4. Проверка прямого интернет соединения
echo ""
echo "4. Checking direct internet access..."
DIRECT_TEST=$(curl -s --max-time 5 http://example.com 2>&1)
if echo "$DIRECT_TEST" | grep -qE "(Failed to connect|Connection refused|timed out)"; then
    check_test "Direct internet blocked" "blocked" "blocked"
else
    check_test "Direct internet blocked" "accessible" "blocked"
    echo -e "   ${RED}WARNING: Direct internet access detected!${NC}"
fi

# 5. Проверка WebRTC (симуляция)
echo ""
echo "5. Checking WebRTC leak prevention..."
# В реальности WebRTC работает в браузере, здесь просто проверяем STUN
STUN_TEST=$(nc -u -w 2 stun.l.google.com 19302 </dev/null 2>&1)
if echo "$STUN_TEST" | grep -qE "(refused|unreachable)"; then
    check_test "STUN/WebRTC blocked" "blocked" "blocked"
else
    check_test "STUN/WebRTC blocked" "accessible" "blocked"
fi

# 6. Проверка IPv6
echo ""
echo "6. Checking IPv6 status..."
IPV6_STATUS=$(cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null)
if [ "$IPV6_STATUS" = "1" ]; then
    check_test "IPv6 disabled" "disabled" "disabled"
else
    check_test "IPv6 disabled" "enabled" "disabled"
    echo -e "   ${RED}WARNING: IPv6 is enabled!${NC}"
fi

# 7. Проверка маршрутизации
echo ""
echo "7. Checking routing table..."
DEFAULT_ROUTE=$(ip route | grep default | grep -oE 'via [0-9.]+' | awk '{print $2}')
if [ "$DEFAULT_ROUTE" = "$GATEWAY_IP" ]; then
    check_test "Default route via Tor Gateway" "correct" "correct"
else
    check_test "Default route via Tor Gateway" "incorrect" "correct"
    echo "   Current default route: $DEFAULT_ROUTE"
fi

# 8. Проверка реального IP через Tor
echo ""
echo "8. Getting external IP through Tor..."
EXTERNAL_IP=$(curl -s -x socks5://$GATEWAY_IP:9050 https://api.ipify.org 2>/dev/null)
if [ -n "$EXTERNAL_IP" ]; then
    echo "   External IP (via Tor): $EXTERNAL_IP"
    
    # Проверка, что это Tor exit node
    TOR_EXIT_CHECK=$(curl -s "https://check.torproject.org/torbulkexitlist" | grep -c "$EXTERNAL_IP")
    if [ "$TOR_EXIT_CHECK" -gt 0 ]; then
        check_test "IP is Tor exit node" "true" "true"
    else
        echo -e "   ${YELLOW}Note: IP might be a bridge or not yet listed${NC}"
    fi
fi

# Итоговый результат
echo ""
echo "======================================="
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}All tests passed! Your system appears to be leak-free.${NC}"
    exit 0
else
    echo -e "${RED}$ERRORS test(s) failed! Please check your configuration.${NC}"
    exit 1
fi