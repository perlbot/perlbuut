#!/bin/bash

set -e
set -u
set -x

ip netns delete evalserver >& /dev/null && echo "Removed old evalserver namespace" || echo "No evalserver namespace yet"
ip link delete evals-public type veth >& /dev/null && echo "Removed old evalserver veth device" || echo "No evalserver veth device yet"

ip netns add evalserver
ip link add evals-private type veth peer name evals-public
ip link set evals-private netns evalserver

sleep 1

ip addr add 192.168.197.1/24 dev evals-public
ip link set evals-public up 

ip netns exec evalserver ip link set dev lo up
ip netns exec evalserver ip addr add 192.168.197.2/24 dev evals-private 
ip netns exec evalserver ip link set evals-private up 
ip netns exec evalserver ip route add default via 192.168.197.1

iptables -N EVALSERVER-FORWARD || iptables -F EVALSERVER-FORWARD
iptables -t nat -N EVALSERVER-POST || iptables -t nat -F EVALSERVER-POST
iptables -N EVALSERVER-OUTPUT || iptables -F EVALSERVER-OUTPUT
iptables -t nat -N EVALSERVER-OUTPUT || iptables -t nat -F EVALSERVER-OUTPUT

iptables -A EVALSERVER-FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT 
#iptables -A EVALSERVER-FORWARD -i evals-public -d 192.168.32.1 -j ACCEPT
iptables -A EVALSERVER-FORWARD -i evals-public -d 192.168.197.0/24 -j ACCEPT
iptables -A EVALSERVER-FORWARD -i evals-public -d 192.168.0.0/16 -j REJECT
iptables -A EVALSERVER-FORWARD -i evals-public -d 10.0.0.0/8 -j REJECT
#iptables -t nat -A EVALSERVER-POST -s 192.168.196.0/24 -d 192.168.196.0/24 -j ACCEPT
iptables -t nat -A EVALSERVER-POST -s 192.168.197.0/24 -o evals-public 
iptables -A EVALSERVER-OUTPUT -d 192.168.197.1/32 -p tcp -m tcp --dport 9040 --tcp-flags FIN,SYN,RST,ACK SYN -j ACCEPT
iptables -t nat -A EVALSERVER-OUTPUT -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -s 192.168.197.0/24 -d !192.168.197.0/24 --j REDIRECT --to-ports 9040


iptables -t filter -D FORWARD -j EVALSERVER-FORWARD || echo "No filter chain loaded"
#iptables -t nat -D POSTROUTING -j EVALSERVER-POST || echo "No nat chain loaded"
#iptables -t nat -A POSTROUTING -j EVALSERVER-POST
iptables -t filter -I FORWARD 1 -j EVALSERVER-FORWARD 
iptables -t filter -I OUTPUT 1 -j EVALSERVER-OUTPUT 
