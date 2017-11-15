#!/bin/bash

# set -ex

COMMAND=$1
TOKEN='5d18b60c52b868e4eb3cee108e9677ddaef39ca1'
DATE=$(date)

LOGFILE=/tmp/kea-hook-runscript-debug.log
DEBUG=0

create-ip() {
  KEY=$(get-session-key)
  IP="$KEA_LEASE4_ADDRESS/$KEA_SUBNET4_PREFIXLEN"
  ALL_IPS=$(get-all-ips)
  COUNT=$(echo $ALL_IPS | jq '.count')

  for ((i=0;i<$COUNT;i++)); do
    CURRENT_IP=$(echo $ALL_IPS | jq ".results[$i]" | jq ".address" | sed 's/\"//g')
    ID=$(echo $ALL_IPS | jq ".results[$i]" | jq ".id")
    if [ "$CURRENT_IP" = "$IP" ]; then
      curl -X PUT "http://netbox.xentaurs.com/api/ipam/ip-addresses/$ID/" \
        -H "Content-Type: application/json" \
        -H "Authorization: Token $TOKEN" \
        -H "Accept: application/json; indent=4" \
        -H "X-Session-Key: $KEY" \
        -d "{ \"address\": \"$IP\", \"description\": \"$KEA_LEASE4_HOSTNAME\" }"
      return
    fi
  done

  curl -X POST "http://netbox.xentaurs.com/api/ipam/ip-addresses/" \
    -H "Content-Type: application/json" \
    -H "Authorization: Token $TOKEN" \
    -H "Accept: application/json; indent=4" \
    -H "X-Session-Key: $KEY" \
    -d "{ \"address\": \"$KEA_LEASE4_ADDRESS/$KEA_SUBNET4_PREFIXLEN\", \"status\": 5, \"description\": \"$KEA_LEASE4_HOSTNAME\" }"
}

delete-ip() {
  KEY=$(get-session-key)
  IP="$KEA_LEASE4_ADDRESS/$KEA_SUBNET4_PREFIXLEN"
  ALL_IPS=$(get-all-ips)
  COUNT=$(echo $ALL_IPS | jq '.count')

  for ((i=0;i<$COUNT;i++)); do
    CURRENT_IP=$(echo $ALL_IPS | jq ".results[$i]" | jq ".address" | sed 's/\"//g')
    if [ "$CURRENT_IP" = "$IP" ]; then
      ID=$(echo $ALL_IPS | jq ".results[$i]" | jq ".id")
      curl -X DELETE "http://netbox.xentaurs.com/api/ipam/ip-addresses/$ID/" \
        -H "Content-Type: application/json" \
        -H "Authorization: Token $TOKEN" \
        -H "Accept: application/json; indent=4" \
        -H "X-Session-Key: $KEY"
      return
    fi
  done
}

get-all-ips() {
  KEY=$(get-session-key)
  curl -s "http://netbox.xentaurs.com/api/ipam/ip-addresses/?limit=0&offset=0" \
    -H "Content-Type: application/json" \
    -H "Authorization: Token $TOKEN" \
    -H "Accept: application/json; indent=4" \
    -H "X-Session-Key: $KEY"
}

get-session-key() {
  curl -s -X POST "http://netbox.xentaurs.com/api/secrets/get-session-key/" \
    -H "Authorization: Token $TOKEN" \
    -H "Accept: application/json; indent=4" \
    --data-urlencode "private_key@id_rsa" | jq '.session_key'
}

logger() {
  echo "$DATE $COMMAND: $KEA_LEASE4_ADDRESS" >> $LOGFILE
}

if [ "$DEBUG" -eq 1 ]; then
    echo $COMMAND >> $LOGFILE
    echo $DATE >> $LOGFILE
    env >> $LOGFILE
    echo >> $LOGFILE
    echo >> $LOGFILE
fi

case "$COMMAND" in
"lease4_select" )
  logger
  create-ip
;;

"lease4_renew" )
  logger
  create-ip
;;

"lease4_expire" )
  logger
  delete-ip
;;

esac
