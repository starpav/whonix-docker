#!/bin/bash

# Whonix-Docker Complete Test Runner
# Запускает все тесты и форматирует вывод для удобного чтения

set -e

# Цвета и символы
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Файл для логов
LOG_FILE="/tmp/whonix-test-$(date +%Y%m%d_%H%M%S).log"

# Функция для красивого вывода
print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}$1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

print_section() {
    echo -e "\n${CYAN}▶ $1${NC}"
    echo -e "${CYAN}$(printf '─%.0s' {1..60})${NC}"
}

# Начало тестирования
clear
echo -e "${BOLD}🔒 WHONIX-DOCKER SYSTEM TEST REPORT${NC}"
echo -e "📅 Date: $(date)"
echo -e "🖥️  Host: $(hostname)"
echo -e "📁 Working directory: $(pwd)"
echo ""

# Запись в лог
{
    echo "WHONIX-DOCKER TEST REPORT"
    echo "========================="
    echo "Date: $(date)"
    echo "Host: $(hostname)"
    echo ""
} > "$LOG_FILE"

# 1. ПРОВЕРКА ОКРУЖЕНИЯ
print_header "1. ENVIRONMENT CHECK"

print_section "Docker Status"
echo -n "Docker Engine: "
if docker version --format '{{.Server.Version}}' 2>/dev/null; then
    echo -e " ${GREEN}✓${NC}"
else
    echo -e " ${RED}✗ Not running${NC}"
    exit 1
fi

echo -n "Docker Compose: "
if docker-compose version --short 2>/dev/null; then
    echo -e " ${GREEN}✓${NC}"
else
    echo -e " ${RED}✗ Not found${NC}"
    exit 1
fi

print_section "Container Status"
GATEWAY_STATUS=$(docker ps --filter "name=whonix-gateway" --format "table {{.Status}}" | tail -n 1)
WORKSTATION_STATUS=$(docker ps --filter "name=whonix-workstation" --format "table {{.Status}}" | tail -n 1)

echo -e "Gateway:     ${GATEWAY_STATUS:-${RED}Not running${NC}}"
echo -e "Workstation: ${WORKSTATION_STATUS:-${RED}Not running${NC}}"

# Проверка что контейнеры запущены
if [[ -z "$GATEWAY_STATUS" ]] || [[ -z "$WORKSTATION_STATUS" ]]; then
    echo -e "\n${RED}ERROR: Containers not running!${NC}"
    echo "Please run: docker-compose up -d"
    exit 1
fi

# 2. СЕТЕВАЯ ИНФОРМАЦИЯ
print_header "2. NETWORK INFORMATION"

print_section "Network Configuration"
echo "Gateway IP:      10.152.152.10"
echo "Workstation IP:  10.152.152.11"
echo "Tor SOCKS Port:  9050"
echo "Tor DNS Port:    5353"

print_section "Active Networks"
docker network ls | grep whonix | while read -r line; do
    echo "  $line"
done

# 3. GATEWAY ПРОВЕРКИ
print_header "3. GATEWAY CHECKS"

print_section "Tor Status"
echo -n "Tor Process: "
if docker exec whonix-gateway pgrep -x tor >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Running${NC}"
    
    # Версия Tor
    TOR_VERSION=$(docker exec whonix-gateway tor --version | head -n 1 | cut -d' ' -f3)
    echo "Tor Version: $TOR_VERSION"
else
    echo -e "${RED}✗ Not running${NC}"
fi

print_section "Gateway Ports"
docker exec whonix-gateway netstat -tuln | grep -E "(9050|5353)" | while read -r line; do
    echo "  $line"
done

print_section "Gateway iptables Rules"
IPTABLES_COUNT=$(docker exec whonix-gateway iptables -L -n | grep -c "DROP\|REJECT" || echo "0")
echo "Active blocking rules: $IPTABLES_COUNT"

# 4. WORKSTATION ПРОВЕРКИ
print_header "4. WORKSTATION CHECKS"

print_section "System Configuration"
echo -n "IPv6 Status: "
IPV6_DISABLED=$(docker exec whonix-workstation cat /proc/sys/net/ipv6/conf/all/disable_ipv6)
if [ "$IPV6_DISABLED" = "1" ]; then
    echo -e "${GREEN}✓ Disabled${NC}"
else
    echo -e "${RED}✗ Enabled${NC}"
fi

echo -n "DNS Configuration: "
DNS_SERVER=$(docker exec whonix-workstation cat /etc/resolv.conf | grep nameserver | awk '{print $2}')
if [ "$DNS_SERVER" = "10.152.152.10" ]; then
    echo -e "${GREEN}✓ Using Gateway${NC}"
else
    echo -e "${RED}✗ Wrong DNS: $DNS_SERVER${NC}"
fi

print_section "Routing Table"
docker exec whonix-workstation ip route | head -5

# 5. ЗАПУСК ТЕСТОВ БЕЗОПАСНОСТИ
print_header "5. SECURITY TESTS"

print_section "Running leak detection test..."
echo ""
# Запускаем тест и сохраняем вывод
LEAK_TEST_OUTPUT=$(docker exec whonix-workstation /tests/check-leaks.sh 2>&1)
LEAK_TEST_EXIT=$?
echo "$LEAK_TEST_OUTPUT"

if [ $LEAK_TEST_EXIT -eq 0 ]; then
    echo -e "\n${GREEN}✓ All leak tests passed${NC}"
else
    echo -e "\n${RED}✗ Some leak tests failed${NC}"
fi

# 6. ТЕСТ СВЯЗНОСТИ
print_header "6. CONNECTIVITY TESTS"

print_section "Running connectivity test..."
echo ""
# Запускаем тест связности
CONN_TEST_OUTPUT=$(docker exec whonix-workstation /tests/test-connectivity.sh 2>&1 | head -30)
echo "$CONN_TEST_OUTPUT"

# 7. РЕАЛЬНАЯ ПРОВЕРКА TOR
print_header "7. LIVE TOR CHECK"

print_section "Current Tor Status"
echo -n "Checking Tor connection... "
TOR_CHECK=$(docker exec whonix-workstation curl -s --max-time 10 https://check.torproject.org/api/ip 2>/dev/null || echo "{}")

if echo "$TOR_CHECK" | grep -q '"IsTor":true'; then
    echo -e "${GREEN}✓ Connected through Tor${NC}"
    
    TOR_IP=$(echo "$TOR_CHECK" | grep -oE '"IP":"[^"]+' | cut -d'"' -f4)
    echo "Your Tor IP: ${BOLD}$TOR_IP${NC}"
    
    # Геолокация
    GEO_INFO=$(docker exec whonix-workstation curl -s "http://ip-api.com/json/$TOR_IP" 2>/dev/null || echo "{}")
    COUNTRY=$(echo "$GEO_INFO" | grep -oE '"country":"[^"]+' | cut -d'"' -f4)
    CITY=$(echo "$GEO_INFO" | grep -oE '"city":"[^"]+' | cut -d'"' -f4)
    
    if [ -n "$COUNTRY" ]; then
        echo "Exit Location: $CITY, $COUNTRY"
    fi
else
    echo -e "${RED}✗ NOT connected through Tor!${NC}"
fi

# 8. ПРОИЗВОДИТЕЛЬНОСТЬ
print_header "8. PERFORMANCE METRICS"

print_section "Resource Usage"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" whonix-gateway whonix-workstation

print_section "Network Latency"
echo -n "Tor latency test: "
LATENCY=$(docker exec whonix-workstation bash -c 'time=$(curl -o /dev/null -s -w "%{time_total}\n" --socks5 10.152.152.10:9050 https://example.com); echo "${time}s"')
echo "$LATENCY"

# 9. ИТОГОВАЯ СВОДКА
print_header "9. TEST SUMMARY"

echo -e "\n${BOLD}Test Results:${NC}"
echo ""

# Подсчет результатов
TOTAL_CHECKS=0
PASSED_CHECKS=0

# Анализ вывода тестов
if echo "$LEAK_TEST_OUTPUT" | grep -q "All tests passed"; then
    echo -e "  ${GREEN}✓${NC} Leak Detection: PASSED"
    ((PASSED_CHECKS++))
else
    echo -e "  ${RED}✗${NC} Leak Detection: FAILED"
fi
((TOTAL_CHECKS++))

if [ "$IPV6_DISABLED" = "1" ]; then
    echo -e "  ${GREEN}✓${NC} IPv6 Disabled: PASSED"
    ((PASSED_CHECKS++))
else
    echo -e "  ${RED}✗${NC} IPv6 Disabled: FAILED"
fi
((TOTAL_CHECKS++))

if [ "$DNS_SERVER" = "10.152.152.10" ]; then
    echo -e "  ${GREEN}✓${NC} DNS Configuration: PASSED"
    ((PASSED_CHECKS++))
else
    echo -e "  ${RED}✗${NC} DNS Configuration: FAILED"
fi
((TOTAL_CHECKS++))

if echo "$TOR_CHECK" | grep -q '"IsTor":true'; then
    echo -e "  ${GREEN}✓${NC} Tor Connection: ACTIVE"
    ((PASSED_CHECKS++))
else
    echo -e "  ${RED}✗${NC} Tor Connection: FAILED"
fi
((TOTAL_CHECKS++))

# Финальный вердикт
echo ""
echo -e "${BOLD}Overall Status: $PASSED_CHECKS/$TOTAL_CHECKS tests passed${NC}"

if [ $PASSED_CHECKS -eq $TOTAL_CHECKS ]; then
    echo -e "\n${GREEN}${BOLD}✅ SYSTEM IS SECURE AND WORKING PROPERLY${NC}"
else
    echo -e "\n${YELLOW}${BOLD}⚠️  ATTENTION REQUIRED - Some tests failed${NC}"
fi

# 10. РЕКОМЕНДАЦИИ
print_header "10. RECOMMENDATIONS"

if [ $PASSED_CHECKS -lt $TOTAL_CHECKS ]; then
    echo "Please check the following:"
    echo ""
    
    if ! echo "$TOR_CHECK" | grep -q '"IsTor":true'; then
        echo "• Tor connection issues - check Gateway logs:"
        echo "  docker logs whonix-gateway"
    fi
    
    if [ "$IPV6_DISABLED" != "1" ]; then
        echo "• IPv6 is not disabled - security risk!"
    fi
    
    if [ "$DNS_SERVER" != "10.152.152.10" ]; then
        echo "• DNS is not using Gateway - potential leak!"
    fi
else
    echo "✓ All systems operational"
    echo "✓ No security issues detected"
    echo ""
    echo "Tips for usage:"
    echo "• Use 'curl https://check.torproject.org/' to verify Tor"
    echo "• Run '/tests/check-leaks.sh' periodically"
    echo "• Monitor Gateway logs: 'docker logs -f whonix-gateway'"
fi

# Сохранение полного отчета
{
    echo ""
    echo "DETAILED TEST OUTPUT"
    echo "==================="
    echo ""
    echo "Leak Test Output:"
    echo "$LEAK_TEST_OUTPUT"
    echo ""
    echo "Connectivity Test Output:"
    echo "$CONN_TEST_OUTPUT"
} >> "$LOG_FILE"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "📄 Full log saved to: ${BOLD}$LOG_FILE${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

# Если есть проблемы, показываем код выхода
if [ $PASSED_CHECKS -lt $TOTAL_CHECKS ]; then
    exit 1
fi

exit 0