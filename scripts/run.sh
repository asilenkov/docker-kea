#!/bin/bash

if [ ! -f /etc/kea/kea-dhcp4.conf ];
then
  cp -vf /etc/kea.orig/kea-dhcp4.conf /etc/kea/kea-dhcp4.conf
fi

echo -n "Wating 5 seconds for network up."
for i in {1..5}
do
   echo -n "."
   sleep 1
done
echo " done."

if [ -n "$FIX_UDP_CHECKSUM" ]
then
    echo "Add iptables rules for fix bad udp checksum on some interfaces driver.(requires docker RUN with --privileged)"
    iptables -t mangle -A POSTROUTING -p udp --dport 67 -j CHECKSUM --checksum-fill
    iptables -t mangle -A POSTROUTING -p udp --dport 68 -j CHECKSUM --checksum-fill
fi

/usr/sbin/kea-ctrl-agent -c /etc/kea/kea-ca.conf &

exec "$@"