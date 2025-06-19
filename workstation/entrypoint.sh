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

# Защита resolv.conf от изменений (опционально)
# sudo chattr +i /etc/resolv.conf

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

# Настройка маршрутизации
echo "Configuring routing..."
sudo /usr/local/bin/routing.sh

# Тест подключения через Tor (используем правильный IP gateway)
echo "Testing Tor connection..."
if curl -s -x socks5://$GATEWAY_IP:9050 --max-time 10 https://check.torproject.org/api/ip | grep -q '"IsTor":true'; then
    echo "✓ Successfully connected through Tor!"
else
    echo "⚠ Warning: Tor connection test failed (this is normal during startup)"
fi

# IPv6 уже отключен в docker-compose.yml sysctls

# Настройка прокси переменных для приложений
export http_proxy="socks5://$GATEWAY_IP:9050"
export https_proxy="socks5://$GATEWAY_IP:9050"
export ftp_proxy="socks5://$GATEWAY_IP:9050"
export all_proxy="socks5://$GATEWAY_IP:9050"

# Добавляем в bashrc для постоянства
echo "export http_proxy=\"socks5://$GATEWAY_IP:9050\"" >> /home/user/.bashrc
echo "export https_proxy=\"socks5://$GATEWAY_IP:9050\"" >> /home/user/.bashrc
echo "export ftp_proxy=\"socks5://$GATEWAY_IP:9050\"" >> /home/user/.bashrc
echo "export all_proxy=\"socks5://$GATEWAY_IP:9050\"" >> /home/user/.bashrc

# NO_PROXY уже установлен в Dockerfile

echo "Workstation is ready!"
echo "All traffic is now routed through Tor."
echo ""
echo "Tips:"
echo "- Use 'curl https://check.torproject.org/' to verify Tor connection"
echo "- Local Docker networks are accessible directly (in dev mode)"
echo "- All external traffic goes through Tor"
echo ""

# Запуск переданной команды или bash
exec "$@"