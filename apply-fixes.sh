#!/bin/bash

echo "🔧 Applying all Whonix-Docker fixes..."
echo ""

# 1. Создаем backup
echo "1. Creating backups..."
cp workstation/Dockerfile workstation/Dockerfile.backup 2>/dev/null || true
cp workstation/routing.sh workstation/routing.sh.backup 2>/dev/null || true
cp workstation/entrypoint.sh workstation/entrypoint.sh.backup 2>/dev/null || true
cp gateway/Dockerfile gateway/Dockerfile.backup 2>/dev/null || true
echo "✓ Backups created"

# 2. Проверка, что вы скопировали новые файлы
echo ""
echo "2. Please ensure you have saved all the fixed files:"
echo "   - workstation/Dockerfile (fixed COPY paths)"
echo "   - workstation/routing.sh (fixed iptables rules)"
echo "   - workstation/entrypoint.sh (added emergency firewall)"
echo "   - gateway/Dockerfile (added healthcheck.sh)"
echo "   - gateway/healthcheck.sh (NEW FILE)"
echo ""
read -p "Have you saved all files? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Please save all files first!"
    exit 1
fi

# 3. Проверка новых файлов
echo ""
echo "3. Checking files..."
if [ ! -f "gateway/healthcheck.sh" ]; then
    echo "❌ gateway/healthcheck.sh not found!"
    echo "Please create it with the content from the artifact"
    exit 1
fi
chmod +x gateway/healthcheck.sh
echo "✓ All files present"

# 4. Остановка старых контейнеров
echo ""
echo "4. Stopping old containers..."
docker-compose down
echo "✓ Containers stopped"

# 5. Очистка старых образов
echo ""
echo "5. Cleaning old images..."
docker rmi whonix-docker-gateway whonix-docker-workstation 2>/dev/null || true
echo "✓ Old images removed"

# 6. Сборка новых образов
echo ""
echo "6. Building new images..."
docker-compose build --no-cache

# 7. Запуск контейнеров
echo ""
echo "7. Starting containers..."
docker-compose up -d

# 8. Ожидание инициализации
echo ""
echo "8. Waiting for initialization..."
sleep 15

# 9. Проверка статуса
echo ""
echo "9. Checking status..."
docker ps --format "table {{.Names}}\t{{.Status}}" | grep whonix

# 10. Быстрый тест безопасности
echo ""
echo "10. Running security test..."
echo ""
echo "=== FIREWALL CHECK ==="
docker exec -u root whonix-workstation iptables -L OUTPUT | head -3

echo ""
echo "=== TOR CONNECTION ==="
docker exec whonix-workstation curl -s --socks5 10.152.152.10:9050 --max-time 10 https://check.torproject.org/ | grep -o "Congratulations\|Sorry" || echo "Connection test failed"

echo ""
echo "=== LEAK TEST ==="
docker exec whonix-workstation timeout 2 curl -s http://8.8.8.8 2>&1 && echo "❌ LEAK DETECTED!" || echo "✅ No leaks - direct access blocked"

echo ""
echo "===================================="
echo "✅ All fixes applied!"
echo ""
echo "Run ./simple-test.sh for a complete test"