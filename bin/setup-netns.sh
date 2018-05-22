#!/bin/bash

set -e
set -u

ip netns delete perlbot >& /dev/null && echo "Removed old perlbot namespace" || echo "No perlbot namespace yet"
ip link delete perlbot-public type veth >& /dev/null && echo "Removed old perlbot veth device" || echo "No perlbot veth device yet"

ip netns add perlbot
ip link add perlbot-private type veth peer name perlbot-public
ip link set perlbot-private netns perlbot

sleep 1

ip addr add 192.168.196.1/24 dev perlbot-public
ip link set perlbot-public up 

ip netns exec perlbot ip link set dev lo up
ip netns exec perlbot ip addr add 192.168.196.2/24 dev perlbot-private 
ip netns exec perlbot ip link set perlbot-private up 
ip netns exec perlbot ip route add default via 192.168.196.1

iptables -N PERLBOT-FORWARD || iptables -F PERLBOT-FORWARD
iptables -t nat -N PERLBOT-POST || iptables -t nat -F PERLBOT-POST

iptables -A PERLBOT-FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT 
iptables -A PERLBOT-FORWARD -i perlbot-public -d 192.168.32.1 -j ACCEPT
iptables -A PERLBOT-FORWARD -i perlbot-public -d 192.168.196.0/24 -j ACCEPT
iptables -A PERLBOT-FORWARD -i perlbot-public -d 192.168.0.0/16 -j REJECT
iptables -A PERLBOT-FORWARD -i perlbot-public -d 10.0.0.0/8 -j REJECT
#iptables -t nat -A PERLBOT-POST -s 192.168.196.0/24 -d 192.168.196.0/24 -j ACCEPT
#iptables -t nat -A PERLBOT-POST -s 192.168.196.0/24 -o perlbot-public -j MASQUERADE

iptables -t filter -D FORWARD -j PERLBOT-FORWARD || echo "No filter chain loaded"
#iptables -t nat -D POSTROUTING -j PERLBOT-POST || echo "No nat chain loaded"
#iptables -t nat -A POSTROUTING -j PERLBOT-POST
iptables -t filter -I FORWARD 1 -j PERLBOT-FORWARD 
