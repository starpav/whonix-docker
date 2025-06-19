FROM alpine:3.19

# Установка необходимых пакетов
RUN apk add --no-cache \
    tor \
    iptables \
    ip6tables \
    curl \
    bash \
    ca-certificates \
    shadow \
    tini

# Создание пользователя tor
RUN addgroup -g 100 tor && \
    adduser -D -u 100 -G tor -s /sbin/nologin tor

# Копирование конфигураций
COPY torrc /etc/tor/torrc
COPY iptables.sh /usr/local/bin/iptables.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

# Установка прав
RUN chmod 644 /etc/tor/torrc && \
    chmod 755 /usr/local/bin/iptables.sh && \
    chmod 755 /usr/local/bin/entrypoint.sh && \
    chown -R tor:tor /etc/tor

# Создание необходимых директорий
RUN mkdir -p /var/lib/tor /var/lib/tor-persistent /var/run/tor && \
    chown -R tor:tor /var/lib/tor /var/lib/tor-persistent /var/run/tor

# Порты
# 9050 - SOCKS
# 9040 - TransPort
# 5353 - DNSPort
EXPOSE 9050 9040 5353

# Healthcheck
HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -x socks5://127.0.0.1:9050 -s https://check.torproject.org/api/ip | grep -q '"IsTor":true' || exit 1

# Запуск через tini для правильной обработки сигналов
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/usr/local/bin/entrypoint.sh"]