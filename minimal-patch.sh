#!/bin/bash

echo "🔧 Minimal patch for Whonix-Docker"
echo ""
echo "This will apply the minimum changes needed to fix the 'ip: command not found' error"
echo ""

# 1. Патч Dockerfile
echo "1. Patching workstation/Dockerfile..."
if grep -q "iproute2" workstation/Dockerfile; then
    echo "   ✓ iproute2 already in Dockerfile"
else
    # Добавляем iproute2 после net-tools
    sed -i '/net-tools \\/a\    iproute2 \\' workstation/Dockerfile
    echo "   ✓ Added iproute2 to Dockerfile"
fi

# 2. Патч docker-compose.yml для SYS_ADMIN
echo ""
echo "2. Patching docker-compose.yml..."
if grep -q "SYS_ADMIN" docker-compose.yml; then
    echo "   ✓ SYS_ADMIN already in docker-compose.yml"
else
    # Добавляем SYS_ADMIN после DAC_OVERRIDE
    sed -i '/DAC_OVERRIDE.*# для изменения файлов/a\      - SYS_ADMIN  # для sysctl' docker-compose.yml
    echo "   ✓ Added SYS_ADMIN capability"
fi

# 3. Добавляем no-new-privileges:false
if grep -q "no-new-privileges:false" docker-compose.yml; then
    echo "   ✓ no-new-privileges already set"
else
    sed -i '/apparmor:unconfined/a\      - no-new-privileges:false  # разрешаем sudo' docker-compose.yml
    echo "   ✓ Added no-new-privileges:false"
fi

# 4. Показываем изменения
echo ""
echo "3. Changes made:"
echo ""
echo "Dockerfile additions:"
grep -A1 -B1 "iproute2" workstation/Dockerfile | head -5

echo ""
echo "docker-compose.yml additions:"
grep -A1 -B1 "SYS_ADMIN" docker-compose.yml | head -5

# 5. Применяем изменения
echo ""
read -p "Apply changes and rebuild? (y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Stopping containers..."
    docker-compose down
    
    echo "Rebuilding..."
    docker-compose build --no-cache workstation
    
    echo "Starting..."
    docker-compose up -d
    
    echo ""
    echo "Waiting for initialization..."
    sleep 10
    
    echo ""
    echo "Testing..."
    docker exec whonix-workstation bash -c 'which ip && echo "✅ ip command found" || echo "❌ ip command NOT found"'
    docker exec whonix-workstation bash -c 'ip route | grep -q default && echo "✅ Routing configured" || echo "❌ Routing NOT configured"'
else
    echo "Patch applied to files. Run 'docker-compose build' when ready."
fi