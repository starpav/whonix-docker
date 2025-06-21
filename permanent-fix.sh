#!/bin/bash
# Permanent security fix for Whonix-Docker

echo "Applying permanent security fix..."

# Stop containers
docker-compose down

# Use secure configuration
docker-compose -f docker-compose.yml -f docker-compose.secure.yml up -d

echo "Waiting for containers to start..."
sleep 15

# Apply secure routing
docker exec -u root whonix-workstation /usr/local/bin/routing-secure.sh

echo "✅ Permanent fix applied!"
echo "Test with: docker exec whonix-workstation timeout 3 curl -s http://1.1.1.1 && echo 'LEAK!' || echo 'SECURE'"
