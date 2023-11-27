#!/bin/bash

usage() {
   echo "setup.sh [OPTION] [VALUE]"
   echo "-addr|--ip-addr          Wireguard server IP address in CIDR; Default: 10.8.0.2/24"
   echo "   -a|--allowed-ips      allowed ip's for client; Default: 10.8.0.0/24"
   echo "   -c|--client-pubkey    public key of the client connecting to the server"
   echo "   -p|--port             port to run wireguard over; Default: 51820"
   echo "   -i|--iface            network interface which wireguard should listen on; Default: First interface in up state"
   echo "   -h|--help             display help info"

   exit 0
}

abnormal_exit() {
   printf "Error: $1\n"
   usage
   exit 1
}

parse_args() {

   while (($#))
   do
      case $1 in
         -addr|--ip-addr)
	    ADDR=$2
            shift 2
	    ;;
	 -a|--allowed-ips)
	    ALLOWED_IPS=$2
	    shift 2
	    ;;
	 -c|--client-pubkey)
	    CLIENT_PUBKEY=$2
	    shift 2
	    ;;
	 -p|--port)
	    PORT=$2
	    shift 2
	    ;;
	 -i|--iface)
	    IFACE=$2
	    shift 2
	    ;;
	 -h|--help)
	    usage
	    ;;
      esac
   done
}

set_defaults() {
   # If no arguments are passed then set default values
   [[ "$ADDR" = "" ]] && ADDR="10.8.0.1/24"
   [[ "$PORT" = "" ]] && PORT=51820
   [[ "$ALLOWED_IPS" = "" ]] && ALLOWED_IPS="10.8.0.0/24"
   [[ "$IFACE" = "" ]] && IFACE=$( ip -br a | grep -m 1 UP | grep -o "^[a-zA-Z]*[0-9]..")
   [[ "$CLIENT_PUBKEY" = "" ]] && abnormal_exit "No client public key given\nFrom the client run:
   umask 077; wg genkey | tee privatekey | wg pubkey > publickey\n"
}

install_pkgs() {
   dnf -y update
   dnf -y install wireguard-tools
}

create_keys() {
   umask 077; wg genkey | tee /etc/wireguard/privatekey | wg pubkey > /etc/wireguard/publickey
   PRIVATE_KEY=$(cat /etc/wireguard/privatekey)
   PUBLIC_KEY=$(cat /etc/wireguard/publickey)
}

create_config() {
   cat << EOF >> /etc/wireguard/wg0.conf
   [Interface]
   PrivateKey = $PRIVATE_KEY
   Address = $ADDR                 # ie: 10.8.0.1/24
   ListenPort = $PORT              # 51820 

   [Peer]
   PublicKey=$CLIENT_PUBKEY        #The Public Key of the Client
   AllowedIPs=$ALLOWED_IPS         # ie: 10.8.0.0/24
   PersistentKeepalive=25
EOF
}

#PostUp = firewall-cmd --zone=public --add-port 51820/udp && firewall-cmd --zone=public --add-masquerade
#PostDown = firewall-cmd --zone=public --remove-port 51820/udp && firewall-cmd --zone=public --remove-masquerade

#DNS = 9.9.9.9                   # Bypass local DNS and use the following DNS instead
#SaveConfig = true
#PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $IFACE -j MASQUERADE
#PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $IFACE -j MASQUERADE

add_firewall_rule() {
   firewall-cmd --permanent --add-port="$PORT/udp" --zone=public
   firewall-cmd --permanent --zone=public --add-masquerade
   firewall-cmd --reload
}

enable_service() {
   sysctl -w "net.ipv4.ip_forward=1"
   sysctl -p

   systemctl enable wg-quick@wg0
   systemctl start wg-quick@wg0
}

main() {
   parse_args $@
   set_defaults 
   install_pkgs
   create_keys
   create_config
   add_firewall_rule
   enable_service

   echo "Wireguard Server Setup Complete"
   echo "Public Key: $PUBLIC_KEY"

   # Clear bash history
   history -c
}

main $@
