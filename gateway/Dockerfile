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

# Create a tor group and add the existing tor user to it
RUN addgroup -g 101 tor && \
    usermod -G tor tor

# Копирование конфигураций
COPY torrc /etc/tor/torrc
COPY iptables.sh /usr/local/bin/iptables.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY healthcheck.sh /usr/local/bin/healthcheck.sh

# Установка прав
RUN chmod 644 /etc/tor/torrc && \
    chmod 755 /usr/local/bin/iptables.sh && \
    chmod 755 /usr/local/bin/entrypoint.sh && \
    chmod 755 /usr/local/bin/healthcheck.sh && \
    chown -R tor:tor /etc/tor

# Создание необходимых директорий
RUN mkdir -p /var/lib/tor /var/lib/tor-persistent /var/run/tor && \
    chown -R tor:tor /var/lib/tor /var/lib/tor-persistent /var/run/tor

# Порты
# 9050 - SOCKS
# 9040 - TransPort
# 5353 - DNSPort
EXPOSE 9050 9040 5353

# Healthcheck - упрощенный вариант
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD /usr/local/bin/healthcheck.sh

# Запуск через tini для правильной обработки сигналов
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/usr/local/bin/entrypoint.sh"]