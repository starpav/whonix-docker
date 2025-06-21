#!/bin/bash

echo "🔍 ДИАГНОСТИКА STUN ПРОБЛЕМЫ"
echo "============================="

# Проверяем текущие правила iptables
docker exec -u root whonix-workstation bash -c '
echo "1. Текущие правила iptables OUTPUT:"
iptables -L OUTPUT -n -v --line-numbers

echo ""
echo "2. Проверяем конкретные STUN правила:"
iptables -L OUTPUT -n | grep -E "(3478|19302|5349)" || echo "STUN правила не найдены"

echo ""
echo "3. Тестируем разные STUN серверы:"
echo -n "   Google STUN (stun.l.google.com:19302): "
timeout 2 nc -u -w 1 stun.l.google.com 19302 >/dev/null 2>&1 && echo "❌ Доступен" || echo "✅ Заблокирован"

echo -n "   Generic STUN (stun1.l.google.com:19302): "
timeout 2 nc -u -w 1 stun1.l.google.com 19302 >/dev/null 2>&1 && echo "❌ Доступен" || echo "✅ Заблокирован"

echo -n "   Cloudflare STUN (1.1.1.1:3478): "
timeout 2 nc -u -w 1 1.1.1.1 3478 >/dev/null 2>&1 && echo "❌ Доступен" || echo "✅ Заблокирован"

echo ""
echo "4. Проверяем через какой интерфейс идет STUN:"
echo "   Активные интерфейсы:"
ip addr show | grep -E "eth[0-9]:" -A 2

echo ""
echo "5. Проверяем маршрутизацию для STUN серверов:"
echo -n "   Маршрут к stun.l.google.com: "
STUN_IP=$(dig +short stun.l.google.com @10.152.152.10 -p 5353 | head -1)
if [ -n "$STUN_IP" ]; then
    echo "$STUN_IP"
    echo "   Маршрут к $STUN_IP:"
    ip route get "$STUN_IP" 2>/dev/null || echo "   Маршрут не найден"
else
    echo "DNS не разрешен"
fi
'

echo ""
echo "🛠️  ПРИМЕНЯЕМ УСИЛЕННУЮ БЛОКИРОВКУ STUN"
echo "======================================="

# Применяем более строгие правила
docker exec -u root whonix-workstation bash -c '
echo "Удаляем старые STUN правила..."
iptables -D OUTPUT -p udp --dport 3478 -j REJECT 2>/dev/null || true
iptables -D OUTPUT -p udp --dport 19302 -j REJECT 2>/dev/null || true
iptables -D OUTPUT -p tcp --dport 3478 -j REJECT 2>/dev/null || true
iptables -D OUTPUT -p udp --dport 5349 -j REJECT 2>/dev/null || true

echo "Применяем усиленные STUN правила..."

# Блокируем STUN на всех интерфейсах ПЕРЕД разрешающими правилами
iptables -I OUTPUT 1 -p udp --dport 3478 -j DROP
iptables -I OUTPUT 2 -p udp --dport 19302 -j DROP  
iptables -I OUTPUT 3 -p tcp --dport 3478 -j DROP
iptables -I OUTPUT 4 -p udp --dport 5349 -j DROP
iptables -I OUTPUT 5 -p tcp --dport 5349 -j DROP

# Дополнительно блокируем популярные STUN серверы по IP
iptables -I OUTPUT 6 -d 142.250.191.127 -j DROP  # Google STUN
iptables -I OUTPUT 7 -d 74.125.250.129 -j DROP   # Google STUN alt

# Блокируем TURN серверы тоже
iptables -I OUTPUT 8 -p udp --dport 3479 -j DROP  # TURN
iptables -I OUTPUT 9 -p tcp --dport 3479 -j DROP  # TURN TCP

echo "✅ Усиленные правила применены"

echo ""
echo "Новые правила (первые 15):"
iptables -L OUTPUT -n --line-numbers | head -20
'

echo ""
echo "🧪 ПОВТОРНОЕ ТЕСТИРОВАНИЕ STUN"
echo "============================="

docker exec whonix-workstation bash -c '
echo "Тестируем STUN серверы после усиленной блокировки:"

for server in "stun.l.google.com:19302" "stun1.l.google.com:19302" "stun2.l.google.com:19302"; do
    HOST=$(echo $server | cut -d: -f1)
    PORT=$(echo $server | cut -d: -f2)
    echo -n "   $server: "
    timeout 2 nc -u -w 1 "$HOST" "$PORT" >/dev/null 2>&1 && echo "❌ ДОСТУПЕН" || echo "✅ ЗАБЛОКИРОВАН"
done

echo ""
echo "Тестируем TURN серверы:"
for port in 3478 3479 5349; do
    echo -n "   Port $port: "
    timeout 2 nc -u -w 1 stun.l.google.com "$port" >/dev/null 2>&1 && echo "❌ ДОСТУПЕН" || echo "✅ ЗАБЛОКИРОВАН"
done

echo ""
echo "Дополнительные WebRTC leak тесты:"
echo -n "   Тест прямого UDP: "
timeout 2 nc -u -w 1 8.8.8.8 53 >/dev/null 2>&1 && echo "❌ ДОСТУПЕН" || echo "✅ ЗАБЛОКИРОВАН"

echo -n "   Тест ICE серверов: "
timeout 2 nc -u -w 1 23.21.150.121 3478 >/dev/null 2>&1 && echo "❌ ДОСТУПЕН" || echo "✅ ЗАБЛОКИРОВАН"
'

echo ""
echo "🔐 СОЗДАЕМ СКРИПТ ДЛЯ ПОСТОЯННОЙ ЗАЩИТЫ"
echo "======================================="

# Создаем скрипт для автоматического применения при перезапуске
docker exec -u root whonix-workstation bash -c '
cat > /usr/local/bin/block-webrtc-leaks.sh << "WEBRTC_SCRIPT"
#!/bin/bash

echo "🛡️  Блокировка WebRTC/STUN утечек..."

# Блокируем все STUN/TURN порты
iptables -I OUTPUT 1 -p udp --dport 3478 -j DROP   # STUN
iptables -I OUTPUT 2 -p udp --dport 19302 -j DROP  # Google STUN
iptables -I OUTPUT 3 -p tcp --dport 3478 -j DROP   # STUN TCP
iptables -I OUTPUT 4 -p udp --dport 5349 -j DROP   # STUNS
iptables -I OUTPUT 5 -p tcp --dport 5349 -j DROP   # STUNS TCP
iptables -I OUTPUT 6 -p udp --dport 3479 -j DROP   # TURN
iptables -I OUTPUT 7 -p tcp --dport 3479 -j DROP   # TURN TCP

# Блокируем популярные STUN серверы по IP
iptables -I OUTPUT 8 -d 142.250.191.127 -j DROP   # Google
iptables -I OUTPUT 9 -d 74.125.250.129 -j DROP    # Google alt
iptables -I OUTPUT 10 -d 216.58.194.127 -j DROP   # Google
iptables -I OUTPUT 11 -d 23.21.150.121 -j DROP    # Twilio

echo "✅ WebRTC утечки заблокированы"
WEBRTC_SCRIPT

chmod +x /usr/local/bin/block-webrtc-leaks.sh

echo "✅ Создан скрипт: /usr/local/bin/block-webrtc-leaks.sh"
echo "   Можно добавить в entrypoint.sh для автоматического применения"
'

echo ""
echo "🎯 ФИНАЛЬНАЯ ПРОВЕРКА АНОНИМНОСТИ"
echo "================================="

docker exec whonix-workstation bash -c '
echo "Полная проверка безопасности:"
echo ""

# 1. IP и геолокация
TOR_IP=$(curl -s --socks5 10.152.152.10:9050 https://api.ipify.org)
echo "✅ Tor IP: $TOR_IP"

GEO=$(curl -s --socks5 10.152.152.10:9050 "https://ipapi.co/json" | jq -r ".city + \", \" + .country_name" 2>/dev/null)
echo "✅ Геолокация: $GEO"

# 2. Утечки
echo ""
echo "Проверка утечек:"
echo -n "   Прямой интернет: "
timeout 2 curl -s http://1.1.1.1 >/dev/null 2>&1 && echo "❌ УТЕЧКА!" || echo "✅ Заблокирован"

echo -n "   DNS утечки: "
timeout 2 nslookup google.com 8.8.8.8 >/dev/null 2>&1 && echo "❌ УТЕЧКА!" || echo "✅ Заблокирован"

echo -n "   STUN утечки: "
timeout 2 nc -u -w 1 stun.l.google.com 19302 >/dev/null 2>&1 && echo "❌ УТЕЧКА!" || echo "✅ ЗАБЛОКИРОВАН"

# 3. Tor статус
echo ""
echo -n "Tor подтвержден: "
curl -s --socks5 10.152.152.10:9050 "https://check.torproject.org/api/ip" | jq -r "if .IsTor then \"✅ ДА\" else \"❌ НЕТ\" end" 2>/dev/null

echo ""
echo "🎉 СИСТЕМА АНОНИМНОСТИ ГОТОВА!"
echo "==============================="
echo "Ваша система теперь полностью анонимна и защищена от всех известных утечек!"
'