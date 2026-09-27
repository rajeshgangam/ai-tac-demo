#!/usr/bin/env bash
[ "$(id -u)" = 0 ] || exec sudo bash "$0" "$@"
for p in $(pgrep -x bgpd; pgrep -x zebra); do kill "$p" 2>/dev/null || true; done
ip netns del ns1 2>/dev/null || true; ip netns del ns2 2>/dev/null || true
echo "torn down"
