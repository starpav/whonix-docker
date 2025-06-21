#!/bin/bash
# Whonix-Docker Security Audit Script

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== WHONIX-DOCKER SECURITY AUDIT ===${NC}"
echo "Date: $(date)"
echo ""

# Results file
AUDIT_LOG="security-audit-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$AUDIT_LOG")
exec 2>&1

# Test results
PASSED=0
FAILED=0
WARNINGS=0

# Helper functions
check() {
    local test_name="$1"
    local command="$2"
    local expected="$3"
    
    echo -n "Checking $test_name... "
    
    if eval "$command" | grep -q "$expected"; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        ((FAILED++))
        return 1
    fi
}

warn() {
    echo -e "${YELLOW}⚠ WARNING: $1${NC}"
    ((WARNINGS++))
}

section() {
    echo ""
    echo -e "${BLUE}### $1 ###${NC}"
    echo ""
}

# 1. NETWORK ISOLATION
section "NETWORK ISOLATION"

check "Tor connectivity" \
    "docker exec whonix-workstation curl -s --socks5 10.152.152.10:9050 https://check.torproject.org/api/ip" \
    "\"IsTor\":true"

check "Direct internet blocked" \
    "docker exec whonix-workstation timeout 2 curl -s https://google.com 2>&1" \
    "Network is unreachable"

check "DNS through Tor only" \
    "docker exec whonix-workstation cat /etc/resolv.conf" \
    "10.152.152.10"

check "IPv6 disabled" \
    "docker exec whonix-workstation cat /proc/sys/net/ipv6/conf/all/disable_ipv6" \
    "1"

# 2. CONTAINER ISOLATION
section "CONTAINER ISOLATION"

check "No CAP_SYS_ADMIN" \
    "docker inspect whonix-workstation --format='{{.HostConfig.CapAdd}}'" \
    "^\[\]$|^$"

check "Read-only root filesystem" \
    "docker inspect whonix-workstation --format='{{.HostConfig.ReadonlyRootfs}}'" \
    "true"

# 3. METADATA LEAKS
section "METADATA LEAKS"

echo "Checking environment variables..."
LEAK_VARS=$(docker exec whonix-workstation env | grep -E "(HOSTNAME|HOST|DOCKER)" | wc -l)
if [ "$LEAK_VARS" -gt 0 ]; then
    warn "Found $LEAK_VARS potentially leaking environment variables"
fi

echo "Checking timezone..."
TZ=$(docker exec whonix-workstation date +%Z)
if [ "$TZ" != "UTC" ]; then
    warn "Timezone is $TZ, should be UTC"
fi

# 4. FIREWALL RULES
section "FIREWALL RULES"

check "iptables DROP policy" \
    "docker exec whonix-workstation sudo iptables -L OUTPUT | head -1" \
    "policy DROP"

RULES=$(docker exec whonix-workstation sudo iptables -L OUTPUT -n | grep -c "REJECT" || true)
if [ "$RULES" -gt 0 ]; then
    echo -e "${GREEN}✓ Found $RULES blocking rules${NC}"
    ((PASSED++))
else
    echo -e "${RED}✗ No blocking rules found${NC}"
    ((FAILED++))
fi

# 5. PROCESS ISOLATION
section "PROCESS ISOLATION"

echo "Checking running processes..."
SUSPICIOUS=$(docker exec whonix-workstation ps aux | grep -vE "(bash|sh|ps|grep)" | wc -l)
echo "Non-shell processes: $SUSPICIOUS"

# 6. FILE SYSTEM
section "FILE SYSTEM"

check "No access to Docker socket" \
    "docker exec whonix-workstation ls -la /var/run/docker.sock 2>&1" \
    "No such file"

check "Temp directories using tmpfs" \
    "docker exec whonix-workstation mount | grep '/tmp'" \
    "tmpfs"

# 7. DNS LEAKS
section "DNS LEAK TEST"

echo "Testing DNS resolution..."
docker exec whonix-workstation bash -c '
for domain in google.com cloudflare.com github.com; do
    echo -n "Resolving $domain: "
    dig +short $domain @10.152.152.10 -p 5353 >/dev/null 2>&1 && echo "✓" || echo "✗"
done
'

# 8. SPECIFIC VULNERABILITIES
section "KNOWN VULNERABILITIES"

echo "Checking for Node.js global packages..."
NPM_GLOBAL=$(docker exec whonix-workstation npm list -g --depth=0 2>/dev/null | grep -v "npm@" | wc -l || echo "0")
if [ "$NPM_GLOBAL" -gt 1 ]; then
    warn "Found $NPM_GLOBAL global npm packages that could leak data"
fi

# SUMMARY
section "AUDIT SUMMARY"

echo -e "Tests Passed:  ${GREEN}$PASSED${NC}"
echo -e "Tests Failed:  ${RED}$FAILED${NC}"
echo -e "Warnings:      ${YELLOW}$WARNINGS${NC}"
echo ""

if [ "$FAILED" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    echo -e "${GREEN}✅ All security checks passed!${NC}"
elif [ "$FAILED" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  Some warnings need attention${NC}"
else
    echo -e "${RED}❌ Critical security issues found!${NC}"
fi

echo ""
echo "Full audit log saved to: $AUDIT_LOG"