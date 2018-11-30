#!/bin/bash

set -e
set -u

ip netns delete evalserver >& /dev/null && echo "Removed old evalserver namespace" || echo "No evalserver namespace yet"
ip link delete evalserver-public type veth >& /dev/null && echo "Removed old evalserver veth device" || echo "No evalserver veth device yet"

ip netns add evalserver
ip link add evalserver-private type veth peer name evalserver-public
ip link set evalserver-private netns evalserver

sleep 1

ip addr add 192.168.197.1/24 dev evalserver-public
ip link set evalserver-public up 

ip netns exec evalserver ip link set dev lo up
ip netns exec evalserver ip addr add 192.168.197.2/24 dev evalserver-private 
ip netns exec evalserver ip link set evalserver-private up 
ip netns exec evalserver ip route add default via 192.168.197.1

iptables -N EVALSERVER-FORWARD || iptables -F EVALSERVER-FORWARD
iptables -t nat -N EVALSERVER-POST || iptables -t nat -F EVALSERVER-POST

iptables -A EVALSERVER-FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT 
iptables -A EVALSERVER-FORWARD -i evalserver-public -d 192.168.32.1 -j ACCEPT
iptables -A EVALSERVER-FORWARD -i evalserver-public -d 192.168.197.0/24 -j ACCEPT
iptables -A EVALSERVER-FORWARD -i evalserver-public -d 192.168.0.0/16 -j REJECT
iptables -A EVALSERVER-FORWARD -i evalserver-public -d 10.0.0.0/8 -j REJECT
#iptables -t nat -A EVALSERVER-POST -s 192.168.196.0/24 -d 192.168.196.0/24 -j ACCEPT
#iptables -t nat -A EVALSERVER-POST -s 192.168.196.0/24 -o evalserver-public -j MASQUERADE

iptables -t filter -D FORWARD -j EVALSERVER-FORWARD || echo "No filter chain loaded"
#iptables -t nat -D POSTROUTING -j EVALSERVER-POST || echo "No nat chain loaded"
#iptables -t nat -A POSTROUTING -j EVALSERVER-POST
iptables -t filter -I FORWARD 1 -j EVALSERVER-FORWARD 
