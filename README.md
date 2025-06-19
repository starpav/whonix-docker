# Whonix-Docker: Анонимная система разработки

Whonix-Docker предоставляет анонимную среду разработки на базе Docker с архитектурой, похожей на Whonix. Весь внешний трафик маршрутизируется через Tor, обеспечивая защиту от утечек IP и DNS.

## 🔒 Возможности

- **Полная анонимизация трафика** через Tor
- **Защита от утечек**: IP, DNS, WebRTC
- **Изолированная архитектура**: Gateway + Workstation
- **Режим разработки**: доступ к локальным Docker контейнерам
- **Легковесность**: ~100MB vs 2-4GB для VM
- **Кроссплатформенность**: Linux, macOS (Docker Desktop), Windows (WSL2)

## 📋 Требования

- Docker Engine 20.10+
- Docker Compose 2.0+
- 1GB свободной памяти
- Интернет соединение

## 🚀 Быстрый старт

### 1. Клонирование проекта
```bash
git clone https://github.com/yourusername/whonix-docker.git
cd whonix-docker
```

### 2. Запуск системы
```bash
# Обычный режим (полная изоляция)
docker-compose up -d

# Режим разработки (с доступом к локальным контейнерам)
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d
```

### 3. Подключение к Workstation
```bash
docker-compose exec workstation bash
```

### 4. Проверка анонимности
```bash
# Внутри workstation
/tests/check-leaks.sh
```

## 🏗️ Архитектура

### Компоненты

1. **Gateway (whonix-gateway)**
   - Alpine Linux с Tor
   - TransparentProxy для всего трафика
   - iptables блокирует non-Tor соединения
   - DNS резолвинг через Tor

2. **Workstation (whonix-workstation)**
   - Ubuntu 22.04 с инструментами разработки
   - Изолирован от внешней сети
   - Весь трафик через Gateway
   - Поддержка локальных Docker сетей (в dev режиме)

### Сетевая схема

```
Internet <---> Gateway (Tor) <---> Workstation
                                         |
                                         v
                                   Local Docker
                                   Containers
                                   (dev mode)
```

### Сети

- **external_net**: Только для Gateway, доступ в интернет
- **tor_net** (10.152.152.0/24): Между Gateway и Workstation
- **dev_net** (172.30.0.0/24): Для локальной разработки

## 🔧 Конфигурация

### Переменные окружения (.env)

```bash
TOR_CONTROL_PORT=9051    # Порт управления Tor
TOR_SOCKS_PORT=9050      # SOCKS порт
TOR_TRANS_PORT=9040      # Transparent proxy порт
TOR_DNS_PORT=5353        # DNS порт
GATEWAY_IP=10.152.152.10 # IP Gateway
WORKSTATION_IP=10.152.152.11 # IP Workstation
```

### Настройка Tor (gateway/torrc)

- Исключение стран: `ExcludeNodes {RU},{UA},{BY},{KZ},{CN}`
- Изоляция потоков для разных соединений
- Оптимизация для анонимности

## 💻 Использование

### Базовые команды

```bash
# Проверка IP
curl https://check.torproject.org/

# DNS резолвинг
dig example.com

# Git через Tor
git config --global http.proxy socks5://10.152.152.10:9050
git config --global https.proxy socks5://10.152.152.10:9050

# npm через Tor
npm config set proxy socks5://10.152.152.10:9050
npm config set https-proxy socks5://10.152.152.10:9050
```

### Разработка микросервисов

```bash
# Запуск в dev режиме
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# Запуск локальной БД
docker run -d --name postgres --network dev_net postgres

# В workstation можно подключиться
psql -h postgres -U postgres
```

### Тестирование

```bash
# Проверка на утечки
docker-compose exec workstation /tests/check-leaks.sh

# Тест связности
docker-compose exec workstation /tests/test-connectivity.sh

# Логи Gateway
docker-compose logs gateway

# Мониторинг трафика
docker-compose exec gateway watch -n 1 'netstat -tunl'
```

## 🛡️ Безопасность

### Защитные механизмы

1. **Блокировка утечек**:
   - iptables DROP политики
   - DNS только через Gateway
   - Блокировка IPv6
   - Защита от WebRTC

2. **Изоляция**:
   - Capabilities минимизированы
   - Read-only файловые системы
   - Seccomp профили
   - User namespaces

3. **Дополнительные меры**:
   - Временные файлы в tmpfs
   - Персистентность только для Tor данных
   - Автоматический healthcheck

### Ограничения vs Whonix VM

- Общее ядро с хостом (меньшая изоляция)
- Сетевой стек Docker (потенциальные side-channel атаки)
- Временные метки могут выдать часовой пояс

## 🚨 Решение проблем

### Gateway не запускается

```bash
# Проверка логов
docker-compose logs gateway

# Пересоздание контейнера
docker-compose down
docker-compose up -d --force-recreate gateway
```

### Медленное соединение

Это нормально для Tor. Советы:
- Используйте мосты если Tor заблокирован
- Перезапустите для получения новых цепочек
- Проверьте нагрузку: `docker stats`

### DNS не работает

```bash
# Проверка DNS в workstation
cat /etc/resolv.conf  # Должен показывать 10.152.152.10

# Тест DNS через Gateway
docker-compose exec workstation dig @10.152.152.10 -p 5353 example.com
```

## 📝 Продвинутое использование

### Кастомные мосты Tor

Отредактируйте `gateway/torrc`:
```
UseBridges 1
Bridge obfs4 IP:PORT FINGERPRINT
```

### Монтирование проектов

В `docker-compose.dev.yml`:
```yaml
volumes:
  - ./my-project:/workspace/my-project
```

### Использование с VS Code

```bash
# Установите Remote-Containers extension
# Подключитесь к workstation контейнеру
```

## ⚠️ Предупреждения

1. **Не для критичной анонимности** - используйте Whonix VM или Tails
2. **Не логируйтесь в личные аккаунты** через Tor
3. **Проверяйте сертификаты** - возможны MITM атаки на выходных узлах
4. **Регулярно обновляйте** Docker образы

## 🤝 Вклад

Приветствуются PR и issues! Особенно:
- Улучшения безопасности
- Поддержка других ОС
- Оптимизация производительности
- Документация

## 📄 Лицензия

MIT License - свободно используйте и модифицируйте!

---

**Помните**: Анонимность - это не только технология, но и поведение. Будьте осторожны!