#!/usr/bin/env bash
# Bring up a two-router eBGP topology (ns1 <-> ns2) with real FRR zebra+bgpd.
# Idempotent-ish; re-run frr-down.sh first for a clean slate.
set -uo pipefail
[ "$(id -u)" = 0 ] || exec sudo -E bash "$0" "$@"
FRR=/usr/local/frr
ip netns add ns1 2>/dev/null || true
ip netns add ns2 2>/dev/null || true
ip link add veth1 type veth peer name veth2 2>/dev/null || true
ip link set veth1 netns ns1 2>/dev/null || true
ip link set veth2 netns ns2 2>/dev/null || true
ip netns exec ns1 ip addr add 10.0.0.1/30 dev veth1 2>/dev/null || true
ip netns exec ns1 ip link set veth1 up; ip netns exec ns1 ip link set lo up
ip netns exec ns1 ip addr add 172.16.1.1/24 dev lo 2>/dev/null || true
ip netns exec ns2 ip addr add 10.0.0.2/30 dev veth2 2>/dev/null || true
ip netns exec ns2 ip link set veth2 up; ip netns exec ns2 ip link set lo up
ip netns exec ns2 ip addr add 172.16.2.1/24 dev lo 2>/dev/null || true
mkdir -p /etc/frr/ns1 /etc/frr/ns2 /var/run/frr/ns1 /var/run/frr/ns2
cat > /etc/frr/ns1/bgpd.conf <<CFG
log stdout
router bgp 65001
 bgp router-id 1.1.1.1
 no bgp ebgp-requires-policy
 neighbor 10.0.0.2 remote-as 65002
 address-family ipv4 unicast
  network 172.16.1.0/24
  neighbor 10.0.0.2 activate
 exit-address-family
CFG
cat > /etc/frr/ns2/bgpd.conf <<CFG
log stdout
router bgp 65002
 bgp router-id 2.2.2.2
 no bgp ebgp-requires-policy
 neighbor 10.0.0.1 remote-as 65001
 address-family ipv4 unicast
  network 172.16.2.0/24
  neighbor 10.0.0.1 activate
 exit-address-family
CFG
chown -R frr:frr /etc/frr /var/run/frr
start_ns() { local NS=$1 PORT=$2
  ip netns exec $NS $FRR/sbin/zebra -d -N $NS -i /var/run/frr/$NS/zebra.pid -z /var/run/frr/$NS/zserv.api 2>/dev/null || true
  sleep 1
  ip netns exec $NS $FRR/sbin/bgpd -d -N $NS -i /var/run/frr/$NS/bgpd.pid -z /var/run/frr/$NS/zserv.api -f /etc/frr/$NS/bgpd.conf --vty_port $PORT 2>/dev/null || true
}
start_ns ns1 2605; start_ns ns2 2606
sleep 8
echo "=== bgpd processes ==="; pgrep -a bgpd | sed 's/^/  /'
echo "=== ns2 BGP summary (session should be Established) ==="
$FRR/bin/vtysh -N ns2 -c "show bgp summary" 2>/dev/null | grep -A3 Neighbor | head -4
echo "ns2 bgpd pid: $(cat /var/run/frr/ns2/bgpd.pid 2>/dev/null)"
