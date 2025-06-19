FROM ubuntu:22.04

# Отключение интерактивных запросов при установке пакетов
ENV DEBIAN_FRONTEND=noninteractive

# Установка базовых инструментов и инструментов разработки
RUN apt-get update && apt-get install -y \
    # Сетевые инструменты
    curl \
    wget \
    netcat-openbsd \
    net-tools \
    iputils-ping \
    dnsutils \
    traceroute \
    tcpdump \
    nmap \
    # Инструменты разработки
    git \
    vim \
    nano \
    build-essential \
    python3 \
    python3-pip \
    nodejs \
    npm \
    # Системные утилиты
    sudo \
    bash \
    ca-certificates \
    gnupg \
    lsb-release \
    htop \
    tmux \
    # Безопасность
    iptables \
    && rm -rf /var/lib/apt/lists/*

# Создание пользователя для работы
RUN useradd -m -s /bin/bash -u 1000 user && \
    echo "user ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Копирование конфигураций
COPY resolv.conf /etc/resolv.conf.tor
COPY routing.sh /usr/local/bin/routing.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

# Установка прав
RUN chmod 644 /etc/resolv.conf.tor && \
    chmod 755 /usr/local/bin/routing.sh && \
    chmod 755 /usr/local/bin/entrypoint.sh

# Создание рабочей директории
RUN mkdir -p /workspace && chown user:user /workspace

# Переключение на пользователя
USER user
WORKDIR /workspace

# Установка переменных окружения
ENV PATH="/home/user/.local/bin:${PATH}"
ENV NO_PROXY="localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16"

# Порты для разработки (опционально)
EXPOSE 3000 8000 8080

# Точка входа
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]