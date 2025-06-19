#!/bin/bash
set -e

# Whonix-Docker Workstation routing configuration
# Настройка умной маршрутизации: локальные сети напрямую, остальное через Tor

GATEWAY_IP="${TOR_GATEWAY:-10.152.152.10}"
DEV_MODE="${DEV_MODE:-false}"

echo "Configuring Workstation routing..."

# Функция для добавления маршрута
add_route() {
    local network=$1
    local gateway=$2
    local interface=$3
    
    if ip route show | grep -q "$network"; then
        echo "Route for $network already exists"
    else
        echo "Adding route: $network via $gateway dev $interface"
        ip route add $network via $gateway dev $interface 2>/dev/null || true
    fi
}

# Получение интерфейсов
TOR_IFACE=$(ip route | grep "10.152.152.0/24" | awk '{print $3}')
DEV_IFACE=$(ip route | grep "172.30.0.0/24" | awk '{print $3}' || echo "")

if [ -z "$TOR_IFACE" ]; then
    echo "Error: Tor network interface not found!"
    exit 1
fi

# Установка шлюза по умолчанию через Tor Gateway
echo "Setting default gateway to $GATEWAY_IP..."
ip route del default 2>/dev/null || true
ip route add default via $GATEWAY_IP dev $TOR_IFACE

# В режиме разработки настраиваем маршруты для локальных Docker сетей
if [ "$DEV_MODE" = "true" ] && [ -n "$DEV_IFACE" ]; then
    echo "Development mode enabled. Configuring local routes..."
    
    # Получаем gateway для dev сети
    DEV_GATEWAY=$(ip route | grep "172.30.0.0/24" | grep -oE 'src [0-9.]+' | awk '{print $2}')
    
    if [ -n "$DEV_GATEWAY" ]; then
        # Docker сети обычно в диапазоне 172.16.0.0/12
        add_route "172.16.0.0/12" "$DEV_GATEWAY" "$DEV_IFACE"
        # Добавляем также другие приватные сети если нужно
        # add_route "192.168.0.0/16" "$DEV_GATEWAY" "$DEV_IFACE"
    fi
fi

# Проверка маршрутов
echo "Current routing table:"
ip route show

# Защита от утечек - блокируем прямой доступ к внешним IP
if [ "$DEV_MODE" != "true" ]; then
    echo "Applying strict routing rules..."
    # Блокируем все кроме локальных сетей и Tor
    iptables -A OUTPUT -d 127.0.0.0/8 -j ACCEPT
    iptables -A OUTPUT -d 10.152.152.0/24 -j ACCEPT
    iptables -A OUTPUT -d 172.16.0.0/12 -j ACCEPT
    iptables -A OUTPUT -d 192.168.0.0/16 -j ACCEPT
    iptables -A OUTPUT -j REJECT
fi

echo "Routing configuration completed!"