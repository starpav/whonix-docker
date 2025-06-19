#!/bin/bash
set -e

# Whonix-Docker Gateway iptables rules
# Блокирует весь трафик кроме Tor

# Переменные
TOR_UID=100
TRANS_PORT=9040
DNS_PORT=5353
TOR_NET="10.152.152.0/24"

echo "Setting up iptables rules for Tor transparent proxy..."

# Очистка существующих правил
iptables -F
iptables -t nat -F
iptables -X
iptables -t nat -X

# Политики по умолчанию - блокировать всё
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# IPv6 - полная блокировка
ip6tables -F
ip6tables -P INPUT DROP
ip6tables -P FORWARD DROP
ip6tables -P OUTPUT DROP

# === INPUT правила ===
# Разрешить loopback
iptables -A INPUT -i lo -j ACCEPT

# Разрешить established соединения
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Разрешить подключения от Workstation к Tor портам
iptables -A INPUT -s $TOR_NET -p tcp --dport 9050 -j ACCEPT  # SOCKS
# iptables -A INPUT -s $TOR_NET -p tcp --dport $TRANS_PORT -j ACCEPT  # TransPort - DISABLED
iptables -A INPUT -s $TOR_NET -p udp --dport $DNS_PORT -j ACCEPT  # DNSPort

# === OUTPUT правила ===
# Разрешить loopback
iptables -A OUTPUT -o lo -j ACCEPT

# Разрешить Tor выходить в интернет
iptables -A OUTPUT -m owner --uid-owner $TOR_UID -j ACCEPT

# Разрешить DNS запросы от root (для резолвинга Tor nodes)
iptables -A OUTPUT -p udp --dport 53 -m owner --uid-owner 0 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -m owner --uid-owner 0 -j ACCEPT

# === NAT правила для transparent proxy ===
# Перенаправление DNS запросов на Tor DNSPort
iptables -t nat -A PREROUTING -s $TOR_NET -p udp --dport 53 -j REDIRECT --to-ports $DNS_PORT
iptables -t nat -A PREROUTING -s $TOR_NET -p tcp --dport 53 -j REDIRECT --to-ports $DNS_PORT

# Перенаправление TCP трафика на Tor TransPort - DISABLED to avoid loops
# iptables -t nat -A PREROUTING -s $TOR_NET -p tcp --syn -j REDIRECT --to-ports $TRANS_PORT

# Исключения для локального трафика
iptables -t nat -A PREROUTING -s $TOR_NET -d 127.0.0.0/8 -j RETURN
iptables -t nat -A PREROUTING -s $TOR_NET -d 10.0.0.0/8 -j RETURN
iptables -t nat -A PREROUTING -s $TOR_NET -d 172.16.0.0/12 -j RETURN
iptables -t nat -A PREROUTING -s $TOR_NET -d 192.168.0.0/16 -j RETURN

# === Защита от утечек ===
# Блокировать любые прямие соединения не от Tor
iptables -A OUTPUT -m owner ! --uid-owner $TOR_UID -m conntrack --ctstate NEW -j REJECT

# Логирование заблокированных пакетов (опционально)
# iptables -A INPUT -j LOG --log-prefix "INPUT-DROP: " --log-level 4
# iptables -A OUTPUT -j LOG --log-prefix "OUTPUT-DROP: " --log-level 4

echo "iptables rules applied successfully!"