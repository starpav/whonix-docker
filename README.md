# Whonix-Docker: Анонимная система разработки

Whonix-Docker предоставляет анонимную среду разработки на базе Docker с архитектурой, похожей на Whonix. Весь внешний трафик маршрутизируется через Tor, обеспечивая защиту от утечек IP и DNS.

## 🔒 Возможности

- **Полная анонимизация трафика** через Tor
- **Защита от утечек**: IP, DNS, WebRTC
- **Изолированная архитектура**: Gateway + Workstation
- **SOCKS proxy подход**: Надежная и стабильная маршрутизация
- **Режим разработки**: доступ к локальным Docker контейнерам
- **Легковесность**: ~200MB vs 2-4GB для VM
- **Кроссплатформенность**: Linux, macOS (Docker Desktop), Windows (WSL2)

## 📋 Требования

- Docker Engine 20.10+
- Docker Compose 2.0+
- 1GB свободной памяти
- Интернет соединение для начальной загрузки Tor

## 🚀 Быстрый старт

### 1. Клонирование проекта
```bash
git clone https://github.com/yourusername/whonix-docker.git
cd whonix-docker
```

### 2. Запуск системы
```bash
# Запуск системы
docker-compose up -d

# Проверка логов
docker-compose logs gateway
docker-compose logs workstation
```

### 3. Подключение к Workstation
```bash
docker-compose exec workstation bash
```

### 4. Проверка анонимности
```bash
# Внутри workstation
curl https://check.torproject.org/
curl https://api.ipify.org

# Запуск тестов безопасности
/tests/check-leaks.sh
```

## 🏗️ Архитектура

### Компоненты

1. **Gateway (whonix-gateway)**
   - Alpine Linux с Tor 0.4.8.14
   - SOCKS proxy (порт 9050) для всего трафика
   - DNS резолвинг через Tor (порт 5353)
   - iptables блокирует non-Tor соединения

2. **Workstation (whonix-workstation)**
   - Ubuntu 22.04 с инструментами разработки
   - Изолирован от внешней сети
   - Весь трафик через Gateway SOCKS proxy
   - Поддержка локальных Docker сетей (в dev режиме)

### Сетевая схема

```
Internet <---> Gateway (Tor SOCKS) <---> Workstation
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
TOR_CONTROL_PORT=9051    # Порт управления Tor (не используется)
TOR_SOCKS_PORT=9050      # SOCKS порт
TOR_TRANS_PORT=9040      # TransPort (отключен)
TOR_DNS_PORT=5353        # DNS порт
GATEWAY_IP=10.152.152.10 # IP Gateway
WORKSTATION_IP=10.152.152.11 # IP Workstation
```

### Настройка Tor (gateway/torrc)

```bash
# SOCKS порт для всех подключений
SocksPort 0.0.0.0:9050
SocksPolicy accept 127.0.0.0/8
SocksPolicy accept 10.152.152.0/24
SocksPolicy accept 172.30.0.0/24
SocksPolicy reject *

# DNS через Tor
DNSPort 0.0.0.0:5353

# Безопасность
ClientOnly 1
ExitPolicy reject *:*
ExcludeNodes {RU},{UA},{BY},{KZ},{CN}
ExcludeExitNodes {RU},{UA},{BY},{KZ},{CN}
StrictNodes 1
```

## 💻 Использование

### Базовые команды

```bash
# Проверка подключения через Tor
curl https://check.torproject.org/

# Получение внешнего IP
curl https://api.ipify.org

# Проверка работы SOCKS proxy
curl --socks5 10.152.152.10:9050 https://httpbin.org/ip

# DNS резолвинг через Tor
dig @10.152.152.10 -p 5353 example.com
```

### Настройка инструментов разработки

```bash
# Git через Tor
git config --global http.proxy socks5://10.152.152.10:9050
git config --global https.proxy socks5://10.152.152.10:9050

# npm через Tor
npm config set proxy socks5://10.152.152.10:9050
npm config set https-proxy socks5://10.152.152.10:9050

# wget через Tor
echo "use_proxy = yes" >> ~/.wgetrc
echo "http_proxy = socks5://10.152.152.10:9050" >> ~/.wgetrc
echo "https_proxy = socks5://10.152.152.10:9050" >> ~/.wgetrc

# pip через Tor
pip config set global.proxy socks5://10.152.152.10:9050
```

### Переменные окружения

Система автоматически настраивает proxy переменные:
```bash
export http_proxy="socks5://10.152.152.10:9050"
export https_proxy="socks5://10.152.152.10:9050"
export all_proxy="socks5://10.152.152.10:9050"
export NO_PROXY="localhost,127.0.0.1,10.152.152.0/24,172.30.0.0/24"
```

### Разработка микросервисов

```bash
# Запуск в dev режиме
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# Запуск локальной БД
docker run -d --name postgres --network whonix-docker_dev_net postgres

# В workstation можно подключиться локально
psql -h postgres -U postgres
```

### Тестирование

```bash
# Полная проверка на утечки
docker-compose exec workstation /tests/check-leaks.sh

# Тест связности
docker-compose exec workstation /tests/test-connectivity.sh

# Логи Gateway
docker-compose logs -f gateway

# Мониторинг соединений
docker-compose exec gateway netstat -tuln
```

## 🛡️ Безопасность

### Защитные механизмы

1. **Блокировка утечек**:
   - iptables DROP политики на Gateway
   - DNS только через Gateway (10.152.152.10:5353)
   - Блокировка IPv6 через sysctls
   - SOCKS Policy ограничивает доступ

2. **Изоляция**:
   - Capabilities минимизированы
   - Read-only файловые системы
   - User namespaces (tor user UID 100)
   - Temporary файлы в tmpfs

3. **Дополнительные меры**:
   - Персистентность только для Tor данных
   - Автоматический healthcheck Gateway
   - Строгие iptables правила

### Ограничения vs Whonix VM

- Общее ядро с хостом (меньшая изоляция)
- Сетевой стек Docker (потенциальные side-channel атаки)
- Временные метки могут выдать часовой пояс
- JavaScript включен (рекомендуется отключить в браузере)

## 🚨 Решение проблем

### Gateway не запускается

```bash
# Проверка логов
docker-compose logs gateway

# Пересоздание контейнера
docker-compose down
docker system prune -f
docker-compose up -d --force-recreate gateway
```

### SOCKS proxy не работает

```bash
# Проверка connectivity к gateway
docker-compose exec workstation nc -z 10.152.152.10 9050

# Проверка proxy переменных
docker-compose exec workstation env | grep -i proxy

# Тест прямого SOCKS подключения
docker-compose exec workstation curl --socks5 10.152.152.10:9050 https://httpbin.org/ip

# Проверка NO_PROXY (может блокировать)
docker-compose exec workstation bash -c 'unset NO_PROXY; curl https://check.torproject.org/'
```

### Медленное соединение

Это нормально для Tor. Советы:
- Используйте мосты если Tor заблокирован: добавьте `UseBridges 1` в torrc
- Перезапустите для получения новых цепочек: `docker-compose restart gateway`
- Проверьте нагрузку: `docker stats`

### DNS не работает

```bash
# Проверка DNS в workstation
docker-compose exec workstation cat /etc/resolv.conf
# Должен показывать: nameserver 10.152.152.10

# Тест DNS через Gateway
docker-compose exec workstation dig @10.152.152.10 -p 5353 example.com

# Проверка DNS редиректа в gateway
docker-compose exec gateway iptables -t nat -L -n | grep 5353
```

### Ошибки прав доступа

```bash
# Проверка capabilities
docker-compose exec workstation bash -c 'cat /proc/self/status | grep Cap'

# Проверка iptables правил
docker-compose exec workstation sudo iptables -L -n

# Если sudo не работает, проверьте capabilities в docker-compose.yml:
# SETUID, SETGID, NET_ADMIN должны быть добавлены
```

## 📝 Продвинутое использование

### Кастомные мосты Tor

Отредактируйте `gateway/torrc`:
```bash
UseBridges 1
ClientTransportPlugin obfs4 exec /usr/bin/obfs4proxy
Bridge obfs4 IP:PORT FINGERPRINT cert=CERT iat-mode=0
```

### Монтирование проектов

В `docker-compose.dev.yml`:
```yaml
services:
  workstation:
    volumes:
      - ./my-project:/workspace/my-project:rw
      - ./workspace:/workspace:rw
```

### Использование с VS Code

```bash
# Установите Remote-Containers extension
# Подключитесь к workstation контейнеру через Docker extension
# Или используйте VS Code Server внутри контейнера
```

### Onion сервисы

```bash
# Тест подключения к onion сайтам
curl --socks5 10.152.152.10:9050 https://duckduckgogg42xjoc72x3sjasowoarfbgcmvfimaftt6twagswzczad.onion

# Проверка, что .onion домены работают
curl --socks5 10.152.152.10:9050 https://3g2upl4pq6kufc4m.onion
```

## 🔧 Техническая информация

### Файловая структура

```
whonix-docker/
├── docker-compose.yml      # Основная конфигурация
├── docker-compose.dev.yml  # Режим разработки
├── .env                    # Переменные окружения
├── gateway/
│   ├── Dockerfile          # Alpine + Tor
│   ├── torrc              # Конфигурация Tor
│   ├── iptables.sh        # Правила iptables
│   └── entrypoint.sh      # Скрипт запуска
├── workstation/
│   ├── Dockerfile         # Ubuntu + инструменты
│   ├── resolv.conf        # DNS конфигурация
│   ├── routing.sh         # Настройка маршрутизации
│   └── entrypoint.sh      # Скрипт запуска
├── tests/
│   ├── check-leaks.sh     # Тест на утечки
│   └── test-connectivity.sh # Тест связности
└── workspace/             # Монтируемая директория
```

### Порты и сети

| Сервис | Порт | Назначение |
|--------|------|------------|
| Gateway:9050 | SOCKS | SOCKS5 proxy для всего трафика |
| Gateway:5353 | DNS | DNS резолвинг через Tor |
| Gateway:9040 | TransPort | Отключен (не используется) |

### Пользователи и права

- **Gateway**: запускается как root, Tor как user `tor` (UID 100)
- **Workstation**: запускается как user `user` (UID 1000)
- **Capabilities**: NET_ADMIN, SETUID, SETGID для необходимых операций

## ⚠️ Предупреждения

1. **Не для критичной анонимности** - используйте Whonix VM или Tails для максимальной безопасности
2. **Не логируйтесь в личные аккаунты** через Tor без необходимости
3. **Проверяйте сертификаты** - возможны MITM атаки на выходных узлах Tor
4. **Регулярно обновляйте** Docker образы и Tor
5. **Отключите JavaScript** в браузере для максимальной анонимности
6. **Не скачивайте файлы** через Tor без проверки на вирусы

## 🧪 Тестирование системы

### Проверка анонимности

```bash
# Основной тест
curl https://check.torproject.org/

# Проверка IP
curl https://api.ipify.org

# Проверка, что это Tor exit node
curl -s https://check.torproject.org/torbulkexitlist | grep $(curl -s https://api.ipify.org)

# Тест DNS утечек
/tests/check-leaks.sh
```

### Проверка производительности

```bash
# Скорость загрузки
time curl -o /dev/null https://www.google.com

# Latency
curl -w "@curl-format.txt" -o /dev/null -s https://www.google.com

# Где curl-format.txt содержит:
#     time_namelookup:  %{time_namelookup}\n
#     time_connect:     %{time_connect}\n
#     time_total:       %{time_total}\n
```

## 🤝 Вклад в проект

Приветствуются PR и issues! Особенно:
- Улучшения безопасности
- Поддержка других ОС
- Оптимизация производительности
- Документация
- Тесты

### Разработка

```bash
# Локальная разработка
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# Тестирование изменений
docker-compose down
docker-compose build --no-cache
docker-compose up -d

# Проверка безопасности
/tests/check-leaks.sh
```

## 📄 Лицензия

MIT License - свободно используйте и модифицируйте!

---

## 🆘 Получение помощи

**Система работает правильно, если:**
- `curl https://check.torproject.org/` возвращает "This browser is configured to use Tor"
- `curl https://api.ipify.org` показывает IP отличный от вашего реального
- `/tests/check-leaks.sh` проходит без ошибок
- DNS резолвинг работает: `dig @10.152.152.10 -p 5353 example.com`

**Если что-то не работает:**
1. Проверьте логи: `docker-compose logs gateway`
2. Проверьте connectivity: `nc -z 10.152.152.10 9050`
3. Проверьте proxy переменные: `env | grep -i proxy`
4. Запустите тесты: `/tests/check-leaks.sh`

**Помните**: Анонимность - это не только технология, но и поведение. Будьте осторожны!

---

*Последнее обновление: Июнь 2025*