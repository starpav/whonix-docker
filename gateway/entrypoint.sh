#!/bin/bash
set -e

echo "Starting Whonix-Docker Gateway..."

# Проверка прав
if [ "$EUID" -ne 0 ]; then 
    echo "Error: Gateway must run as root for iptables"
    exit 1
fi

# Проверка и создание директорий
mkdir -p /var/lib/tor /var/lib/tor-persistent /var/run/tor
chown -R tor:tor /var/lib/tor /var/lib/tor-persistent /var/run/tor
chmod 700 /var/lib/tor /var/lib/tor-persistent

# Копирование данных из persistent volume если есть
if [ -d "/var/lib/tor-persistent/cached-certs" ]; then
    echo "Restoring Tor state from persistent storage..."
    cp -r /var/lib/tor-persistent/* /var/lib/tor/ 2>/dev/null || true
    chown -R tor:tor /var/lib/tor
fi

# Настройка iptables
echo "Configuring iptables..."
/usr/local/bin/iptables.sh

# Функция для сохранения состояния Tor
save_tor_state() {
    echo "Saving Tor state to persistent storage..."
    cp -r /var/lib/tor/* /var/lib/tor-persistent/ 2>/dev/null || true
}

# Обработка сигналов для корректного завершения
trap 'save_tor_state; exit 0' SIGTERM SIGINT

# Запуск Tor от имени пользователя tor
echo "Starting Tor..."
exec su -s /bin/sh tor -c "tor -f /etc/tor/torrc"