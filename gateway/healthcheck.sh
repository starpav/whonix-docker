#!/bin/sh
# Simple healthcheck for Tor Gateway

# Check if Tor is running
if ! pgrep -x tor >/dev/null 2>&1; then
    echo "Tor process not running"
    exit 1
fi

# Check if SOCKS port is listening
if ! nc -z 127.0.0.1 9050 2>/dev/null; then
    echo "SOCKS port not accessible"
    exit 1
fi

# Check if DNS port is listening
if ! nc -z 127.0.0.1 5353 2>/dev/null; then
    echo "DNS port not accessible"
    exit 1
fi

echo "Tor Gateway is healthy"
exit 0