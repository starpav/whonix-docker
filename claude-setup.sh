#!/bin/bash

echo "🤖 ПРЯМАЯ УСТАНОВКА CLAUDE CODE"
echo "==============================="

# Выполняем установку напрямую в контейнере без -it
docker exec whonix-workstation bash -c '
# Переключаемся на пользователя user
su - user << "USER_INSTALL"

echo "📦 Установка Claude Code для пользователя user..."

# 1. Очищаем proxy переменные
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy

# 2. Настраиваем npm
npm config delete proxy 2>/dev/null || true
npm config delete https-proxy 2>/dev/null || true
npm config set registry https://registry.npmjs.org/

# 3. Временно устанавливаем proxy для установки
npm config set proxy socks5://10.152.152.10:9050
npm config set https-proxy socks5://10.152.152.10:9050

# 4. Удаляем старую версию
npm uninstall -g @anthropic-ai/claude-code 2>/dev/null || true

# 5. Устанавливаем Claude Code
echo "Установка Claude Code..."
npm install -g @anthropic-ai/claude-code

# 6. Очищаем npm proxy
npm config delete proxy
npm config delete https-proxy

# 7. Проверяем установку
if command -v claude >/dev/null 2>&1; then
    echo "✅ Claude Code установлен в: $(which claude)"
    
    # Пробуем запустить версию без proxy
    unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy
    
    echo "Тестируем Claude без proxy переменных..."
    claude --version 2>&1 || echo "Ошибка версии"
    
else
    echo "❌ Claude Code не установлен"
fi

# 8. Создаем простой wrapper
mkdir -p ~/bin

cat > ~/bin/claude-clean << "WRAPPER"
#!/bin/bash

# Простой wrapper для Claude без proxy переменных
echo "🤖 Запуск Claude (без proxy)..."

# Очищаем ВСЕ proxy переменные
unset http_proxy https_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY all_proxy
unset npm_config_proxy npm_config_https_proxy

# Показываем статус безопасности
echo "🔍 Проверка анонимности:"
TOR_IP=$(curl -s --socks5 10.152.152.10:9050 --max-time 5 https://api.ipify.org 2>/dev/null || echo "недоступно")
echo "   Tor IP: $TOR_IP"

LEAK_TEST=$(timeout 2 curl -s --max-time 1 http://1.1.1.1 >/dev/null 2>&1 && echo "❌ ЕСТЬ УТЕЧКИ!" || echo "✅ Безопасно")
echo "   Утечки: $LEAK_TEST"
echo ""

# Запускаем Claude
exec claude "$@"
WRAPPER

chmod +x ~/bin/claude-clean

# 9. Создаем альтернативный API wrapper
cat > ~/bin/claude-api << "API_WRAPPER"
#!/bin/bash

# API wrapper для прямого доступа к Claude через Tor

if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo "❌ Нужен API ключ:"
    echo "export ANTHROPIC_API_KEY=\"your-key-here\""
    exit 1
fi

PROMPT="$*"
if [ -z "$PROMPT" ]; then
    echo "Использование: claude-api \"ваш вопрос\""
    exit 1
fi

echo "🔒 Запрос через Tor к Claude API..."

# Проверяем Tor
TOR_IP=$(curl -s --socks5 10.152.152.10:9050 --max-time 5 https://api.ipify.org 2>/dev/null)
if [ -z "$TOR_IP" ]; then
    echo "❌ Tor недоступен!"
    exit 1
fi

echo "✅ Tor активен: $TOR_IP"

# Отправляем запрос
RESPONSE=$(curl -s --socks5 10.152.152.10:9050 \
  --max-time 30 \
  -H "Content-Type: application/json" \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -d "{
    \"model\": \"claude-3-sonnet-20240229\",
    \"max_tokens\": 1000,
    \"messages\": [{
      \"role\": \"user\", 
      \"content\": \"$PROMPT\"
    }]
  }" \
  https://api.anthropic.com/v1/messages 2>/dev/null)

if [ $? -eq 0 ] && [ -n "$RESPONSE" ]; then
    echo ""
    echo "📝 Ответ Claude:"
    echo "$RESPONSE" | jq -r ".content[0].text" 2>/dev/null || echo "$RESPONSE"
else
    echo "❌ Ошибка API запроса"
fi
API_WRAPPER

chmod +x ~/bin/claude-api

# 10. Обновляем PATH
if ! echo "$PATH" | grep -q "$HOME/bin"; then
    echo "export PATH=\"\$HOME/bin:\$PATH\"" >> ~/.bashrc
fi

# 11. Устанавливаем нужные пакеты
echo "Проверка дополнительных пакетов..."

# jq для JSON
if ! command -v jq >/dev/null 2>&1; then
    echo "Установка jq..."
    sudo apt-get update >/dev/null 2>&1
    sudo apt-get install -y jq >/dev/null 2>&1
fi

echo ""
echo "🎉 УСТАНОВКА ЗАВЕРШЕНА!"
echo ""
echo "Доступные команды:"
echo "1. claude-clean \"вопрос\"  - Claude без proxy"
echo "2. claude-api \"вопрос\"    - Прямой API через Tor"
echo "3. claude \"вопрос\"        - Оригинальный Claude"
echo ""

USER_INSTALL
'

# Проверяем результат установки
echo ""
echo "🧪 ПРОВЕРКА УСТАНОВКИ:"
echo "====================="

# Проверяем, что Claude установлен
CLAUDE_PATH=$(docker exec whonix-workstation su - user -c "which claude" 2>/dev/null)
if [ -n "$CLAUDE_PATH" ]; then
    echo "✅ Claude найден: $CLAUDE_PATH"
    
    # Пробуем версию
    CLAUDE_VERSION=$(docker exec whonix-workstation su - user -c "unset http_proxy https_proxy; claude --version" 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo "✅ Claude версия: $CLAUDE_VERSION"
    else
        echo "⚠️  Claude установлен, но есть проблемы с запуском"
    fi
else
    echo "❌ Claude не найден"
fi

# Проверяем wrappers
WRAPPERS=$(docker exec whonix-workstation su - user -c "ls -la ~/bin/claude-*" 2>/dev/null)
if [ -n "$WRAPPERS" ]; then
    echo "✅ Созданы wrapper scripts:"
    echo "$WRAPPERS"
else
    echo "⚠️  Wrapper scripts не созданы"
fi

echo ""
echo "🚀 ТЕСТИРОВАНИЕ:"
echo "==============="
echo ""
echo "Подключитесь к контейнеру:"
echo "docker exec -it whonix-workstation su - user"
echo ""
echo "Затем попробуйте:"
echo "claude-clean --version"
echo "claude-clean \"Привет! Покажи мой IP адрес\""
echo ""
echo "Или с API ключом:"
echo "export ANTHROPIC_API_KEY=\"your-key-here\""
echo "claude-api \"Привет Claude! Где я нахожусь?\""