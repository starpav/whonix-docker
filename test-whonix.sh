#!/bin/bash

# Скрипт для запуска тестов Whonix-Docker с хост-системы

echo "🔍 Running Whonix-Docker System Tests..."
echo ""

# Проверяем, что мы в правильной директории
if [ ! -f "docker-compose.yml" ]; then
    echo "❌ Error: docker-compose.yml not found!"
    echo "Please run this script from the whonix-docker directory"
    exit 1
fi

# Проверяем запущены ли контейнеры
if ! docker ps | grep -q whonix-gateway; then
    echo "⚠️  Gateway container not running. Starting containers..."
    docker-compose up -d
    echo "⏳ Waiting 10 seconds for containers to initialize..."
    sleep 10
fi

# Копируем тестовый скрипт в контейнер
echo "📋 Copying test runner to workstation..."
docker cp run-all-tests.sh whonix-workstation:/tmp/run-all-tests.sh
docker exec whonix-workstation chmod +x /tmp/run-all-tests.sh

# Запускаем тест
echo "🚀 Starting tests..."
echo ""
docker exec -it whonix-workstation /tmp/run-all-tests.sh

# Получаем лог файл
echo ""
echo "📥 Retrieving test log..."
LOG_FILE=$(docker exec whonix-workstation ls -t /tmp/whonix-test-*.log 2>/dev/null | head -1)

if [ -n "$LOG_FILE" ]; then
    LOCAL_LOG="whonix-test-$(date +%Y%m%d_%H%M%S).log"
    docker cp "whonix-workstation:$LOG_FILE" "./$LOCAL_LOG"
    echo "✅ Log saved to: $LOCAL_LOG"
else
    echo "⚠️  Could not retrieve log file"
fi

echo ""
echo "Test completed!"