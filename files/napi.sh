#!/bin/bash

# set -ex

COMMAND=$1
TOKEN='5d18b60c52b868e4eb3cee108e9677ddaef39ca1'
DATE=$(date)
NETBOX_HOSTNAME=netbox.xentaurs.com
LOGFILE=/tmp/kea-hook-runscript-debug.log
DEBUG=0

check-ip() {
  IP="$KEA_LEASE4_ADDRESS/$KEA_SUBNET4_PREFIXLEN"
  IP_ADDRESSES_URL="http://$NETBOX_HOSTNAME/api/ipam/ip-addresses/"

  while [ $IP_ADDRESSES_URL != null ]; do
    IP_ADDRESSES=$(get-ips $IP_ADDRESSES_URL)
    for row in $(echo $IP_ADDRESSES | jq -r '.results[] | @base64'); do
      CURRENT_IP=$(echo $row | base64 --decode | jq -r ".address" | cut -d '/' -f 1)
      CURRENT_ID=$(echo $row | base64 --decode | jq -r ".id")
      if [ "$CURRENT_IP" = "$KEA_LEASE4_ADDRESS" ]; then echo -n $CURRENT_ID; return 0; fi
    done
    IP_ADDRESSES_URL=$(echo $IP_ADDRESSES | jq '.next' | sed s/\"//g | sed s/localhost/$NETBOX_HOSTNAME/)
  done
  echo -n
  return 1
}

create-ip() {
  curl -X POST "http://$NETBOX_HOSTNAME/api/ipam/ip-addresses/" \
    -H "Content-Type: application/json" \
    -H "Authorization: Token $TOKEN" \
    -H "Accept: application/json; indent=4" \
    -H "X-Session-Key: $KEY" \
    -d "{ \"address\": \"$KEA_LEASE4_ADDRESS/$KEA_SUBNET4_PREFIXLEN\", \"status\": 5, \"description\": \"$KEA_LEASE4_HOSTNAME\" }"
}

delete-ip() {
  ID=$1
  curl -X DELETE "http://$NETBOX_HOSTNAME/api/ipam/ip-addresses/$ID/" \
    -H "Content-Type: application/json" \
    -H "Authorization: Token $TOKEN" \
    -H "Accept: application/json; indent=4" \
    -H "X-Session-Key: $KEY"
}

get-ips() {
  URL=$1
  curl -s -X GET $URL \
    -H "Content-Type: application/json" \
    -H "Authorization: Token $TOKEN" \
    -H "Accept: application/json; indent=4" \
    -H "X-Session-Key: $KEY"
}

get-session-key() {
  curl -s -X POST "http://$NETBOX_HOSTNAME/api/secrets/get-session-key/" \
    -H "Authorization: Token $TOKEN" \
    -H "Accept: application/json; indent=4" \
    --data-urlencode "private_key@id_rsa" | jq '.session_key'
}

logger() {
  echo "$DATE $COMMAND: $KEA_LEASE4_ADDRESS" >> $LOGFILE
}

update-ip() {
  ID=$1
  IP="$KEA_LEASE4_ADDRESS/$KEA_SUBNET4_PREFIXLEN"
  curl -X PUT "http://$NETBOX_HOSTNAME/api/ipam/ip-addresses/$ID/" \
    -H "Content-Type: application/json" \
    -H "Authorization: Token $TOKEN" \
    -H "Accept: application/json; indent=4" \
    -H "X-Session-Key: $KEY" \
    -d "{ \"address\": \"$IP\", \"description\": \"$KEA_LEASE4_HOSTNAME\" }"
}

if [ "$DEBUG" -eq 1 ]; then
    echo $COMMAND >> $LOGFILE
    echo $DATE >> $LOGFILE
    env >> $LOGFILE
    echo >> $LOGFILE
    echo >> $LOGFILE
fi

case "$COMMAND" in
"lease4_select" | "lease4_renew" )
  KEY=$(get-session-key)
  ID=$(check-ip)
  logger
  if [ "$ID" == "" ]; then
    create-ip
  else
    update-ip $ID
  fi
;;

"lease4_expire" )
  KEY=$(get-session-key)
  ID=$(check-ip)
  logger
  delete-ip $ID
;;

esac
