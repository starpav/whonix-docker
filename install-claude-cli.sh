#!/bin/bash

echo "🤖 INSTALLING CLAUDE CODE CLI IN WHONIX-DOCKER"
echo "============================================="
echo ""

# Проверка контейнера
if ! docker ps | grep -q whonix-workstation; then
    echo "❌ Workstation not running!"
    exit 1
fi

echo "Setting up Claude Code CLI..."
echo ""

docker exec -it -u root whonix-workstation bash << 'EOF'
# Переход к пользователю
su - user << 'USEREOF'

# Проверка Node.js
echo "📦 Checking Node.js..."
if ! command -v node >/dev/null; then
    echo "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

echo "Node.js version: $(node -v)"
echo "NPM version: $(npm -v)"

# Настройка npm для Tor
echo ""
echo "🌐 Configuring npm for Tor..."
npm config set proxy socks5://10.152.152.10:9050
npm config set https-proxy socks5://10.152.152.10:9050
npm config set strict-ssl false

# Установка Claude CLI (имя пакета может измениться)
echo ""
echo "📥 Installing Claude Code CLI..."

# Попытка установить официальный пакет
if npm list -g @anthropic/claude-code >/dev/null 2>&1; then
    echo "Claude Code already installed!"
else
    echo "Installing Claude Code..."
    npm install -g @anthropic/claude-code || {
        echo ""
        echo "⚠️  Official package might not be available yet."
        echo "Claude Code is currently in research preview."
        echo ""
        echo "Creating alternative setup..."
        
        # Создаем скрипт-обертку для использования Claude API
        mkdir -p ~/bin
        cat > ~/bin/claude << 'CLAUDE_SCRIPT'
#!/usr/bin/env node

const https = require('https');
const fs = require('fs');
const path = require('path');
const readline = require('readline');
const { SocksProxyAgent } = require('socks-proxy-agent');

// Tor proxy configuration
const agent = new SocksProxyAgent('socks5://10.152.152.10:9050');

// Claude API configuration
const API_KEY = process.env.CLAUDE_API_KEY || '';
const API_URL = 'https://api.anthropic.com/v1/messages';

if (!API_KEY) {
    console.error('❌ Please set CLAUDE_API_KEY environment variable');
    console.error('Add to ~/.bashrc: export CLAUDE_API_KEY="your-key-here"');
    process.exit(1);
}

async function callClaude(prompt, context = '') {
    const payload = {
        model: 'claude-3-opus-20240229',
        max_tokens: 4000,
        messages: [{
            role: 'user',
            content: context ? `Context:\n${context}\n\nRequest: ${prompt}` : prompt
        }],
        temperature: 0.2
    };

    const options = {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'x-api-key': API_KEY,
            'anthropic-version': '2023-06-01'
        },
        agent: agent
    };

    return new Promise((resolve, reject) => {
        const req = https.request(API_URL, options, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                try {
                    const response = JSON.parse(data);
                    if (response.content && response.content[0]) {
                        resolve(response.content[0].text);
                    } else {
                        reject(new Error('Invalid response format'));
                    }
                } catch (e) {
                    reject(e);
                }
            });
        });

        req.on('error', reject);
        req.write(JSON.stringify(payload));
        req.end();
    });
}

async function main() {
    const args = process.argv.slice(2);
    
    if (args.length === 0) {
        console.log('Claude CLI - Anonymous AI Assistant via Tor');
        console.log('');
        console.log('Usage:');
        console.log('  claude <prompt>              - Ask Claude');
        console.log('  claude -f <file> <prompt>    - Include file context');
        console.log('  claude -i                    - Interactive mode');
        console.log('');
        console.log('Examples:');
        console.log('  claude "explain this code" -f app.js');
        console.log('  claude "write a Python function to calculate fibonacci"');
        return;
    }

    // Interactive mode
    if (args[0] === '-i') {
        console.log('🤖 Claude Interactive Mode (via Tor)');
        console.log('Type "exit" to quit');
        console.log('');

        const rl = readline.createInterface({
            input: process.stdin,
            output: process.stdout,
            prompt: 'You: '
        });

        rl.prompt();

        rl.on('line', async (line) => {
            if (line.toLowerCase() === 'exit') {
                rl.close();
                return;
            }

            console.log('Claude (thinking via Tor)...');
            try {
                const response = await callClaude(line);
                console.log('\nClaude:', response);
                console.log('');
            } catch (error) {
                console.error('Error:', error.message);
            }

            rl.prompt();
        });

        return;
    }

    // File context mode
    let prompt = args.join(' ');
    let context = '';

    if (args[0] === '-f' && args.length >= 3) {
        const filename = args[1];
        try {
            context = fs.readFileSync(filename, 'utf8');
            prompt = args.slice(2).join(' ');
        } catch (error) {
            console.error(`Error reading file ${filename}:`, error.message);
            process.exit(1);
        }
    }

    // Single prompt mode
    console.log('🌐 Sending request through Tor...');
    try {
        const response = await callClaude(prompt, context);
        console.log('\n' + response);
    } catch (error) {
        console.error('Error:', error.message);
    }
}

// Ensure socks-proxy-agent is installed
try {
    require('socks-proxy-agent');
} catch (e) {
    console.log('Installing required dependencies...');
    require('child_process').execSync('npm install socks-proxy-agent', { stdio: 'inherit' });
}

main().catch(console.error);
CLAUDE_SCRIPT

        chmod +x ~/bin/claude
        
        # Добавляем в PATH
        echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc
        
        # Устанавливаем зависимость
        cd ~
        npm install socks-proxy-agent
        
        echo ""
        echo "✅ Claude CLI wrapper created!"
    }
fi

# Создание конфигурации
echo ""
echo "📝 Creating configuration..."

# .clauderc для настроек
cat > ~/.clauderc << 'CONFIG'
{
  "model": "claude-3-opus-20240229",
  "temperature": 0.2,
  "max_tokens": 4000,
  "proxy": "socks5://10.152.152.10:9050",
  "anonymous": true
}
CONFIG

# Пример использования
cat > /workspace/claude-examples.md << 'EXAMPLES'
# Claude Code CLI Examples in Whonix-Docker

All Claude interactions go through Tor for complete anonymity!

## Setup

1. Add your API key to ~/.bashrc:
   ```bash
   echo 'export CLAUDE_API_KEY="sk-ant-..."' >> ~/.bashrc
   source ~/.bashrc
   ```

2. Test connection:
   ```bash
   claude "Hello, are you receiving this through Tor?"
   ```

## Usage Examples

### Basic queries:
```bash
# Ask about code
claude "explain what this Python decorator does" -f my_code.py

# Generate code
claude "write a bash script to monitor system resources"

# Debug help
claude "why is this function returning undefined?" -f buggy.js
```

### Interactive mode:
```bash
claude -i
# Now you can have a conversation
```

### Development workflow:
```bash
# 1. Write some code
vim app.js

# 2. Ask Claude to review it
claude "review this code for security issues" -f app.js

# 3. Ask for improvements
claude "how can I make this more efficient?" -f app.js

# 4. Generate tests
claude "write unit tests for this module" -f app.js > tests.js
```

### Advanced usage:
```bash
# Pipe output
cat error.log | claude "explain these errors"

# Chain commands
claude "generate a REST API in Express" > api.js && \
claude "add authentication to this API" -f api.js > api-auth.js

# Code review
git diff | claude "review these changes"
```

## Privacy Notes

- ✅ All API calls go through Tor
- ✅ Your IP is never exposed
- ✅ Claude doesn't know your real location
- ⚠️  API key is still linked to your account
- 💡 Consider using a separate API key for anonymous work

## Troubleshooting

If slow, it's normal - Tor adds latency. Be patient!

Check Tor connection:
```bash
curl --socks5 10.152.152.10:9050 https://check.torproject.org/api/ip
```
EXAMPLES

echo ""
echo "✅ Claude CLI setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Add your API key:"
echo "   echo 'export CLAUDE_API_KEY=\"your-key-here\"' >> ~/.bashrc"
echo "   source ~/.bashrc"
echo ""
echo "2. Test it:"
echo "   claude \"Hello Claude, am I anonymous?\""
echo ""
echo "3. See examples:"
echo "   cat /workspace/claude-examples.md"

# Обновляем текущую сессию
export PATH="$HOME/bin:$PATH"
USEREOF
EOF

echo ""
echo "🎉 SETUP COMPLETE!"
echo "=================="
echo ""
echo "Enter the container to start using Claude:"
echo "  docker exec -it whonix-workstation su - user"
echo ""
echo "Then set your API key and start coding with Claude!"
echo ""
echo "Example workflow:"
echo "  1. cd /workspace"
echo "  2. vim mycode.py"
echo "  3. claude \"help me improve this Python code\" -f mycode.py"
echo ""
echo "💡 Pro tip: All Claude requests go through Tor automatically!"