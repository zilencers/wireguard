#!/bin/bash

usage() {
   echo "Usage: [OPTION] [VALUE]"
   echo "-a|--address         client ip; Default 10.8.0.2/24"
   echo "-e|--endpoint        Wireguard server public ip"
   echo "-s|--srv-pubkey      Wireguard server public key"

   exit 0
}

abnormal_exit() {
   echo "Error: $1"
   usage
   exit 1
}

create_config() {
   local privatekey=$(cat /etc/wireguard/privatekey)

   cat << EOF >> /etc/wireguard/client.conf
   [Interface]
   PrivateKey = $privatekey
   Address=$ADDR

   [Peer]
   PublicKey=$SERVER_PUBKEY
   Endpoint=$ENDPOINT:51820
   AllowedIPs = 0.0.0.0/0      # Forward all traffic to server
EOF
}

set_defaults() {
   echo "Setting defaults"
   [[ $ADDR = "" ]] && ADDR="10.8.0.2/24"
   [[ $ENDPOINT = "" ]] && abnormal_exit "missing argument -e|--endpoint"
   [[ $SERVER_PUBKEY = "" ]] && abnormal_exit "missing argument -s|--srv-pubkey"
}

install_pkgs() {
    echo "Checking for wireguard package ..."
    dnf -y install wireguard-tools
}

create_keys() {
   if [ ! -f /etc/wireguard/privatekey ]; then
      echo "Generating encryption keys ..."
      umask 077; wg genkey | tee /etc/wireguard/privatekey | wg pubkey > /etc/wireguard/publickey
      PUBLIC_KEY=$(cat /etc/wireguard/publickey)
   else
      echo "Encryption Keys already exist ...skipping"
   fi
}

parse_args() {
   while (($#))
   do
      case $1 in
         -a|--address)
	    ADDR=$2
	    shift 2
	    ;;
         -e|--endpoint)
	    ENDPOINT=$2
	    shift 2
	    ;;
	 -g|--genkey-only)
	    GENKEY_ONLY=1
	    shift 1
	    ;;
	 -s|--srv-pubkey)
	    SERVER_PUBKEY=$2
	    shift 2
	    ;;
	 -h|--help)
	    usage
	    ;;
      esac
   done
}

main() {
   parse_args $@
   
   if [[ $GENKEY_ONLY -eq 1 ]]; then
      install_pkgs
      create_keys      
      echo "Public Key: $PUBLIC_KEY"
      exit 0
   fi

   set_defaults
   install_pkgs
   create_keys
   create_config
}

main $@
