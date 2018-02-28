#!/bin/bash

WIFI_INT=wlan0
WIFI_IP=192.168.3.32
WIFI_NETMASK=255.255.255.0
WIFI_GW=192.168.3.1

# Lets update dhcpcd.conf to get dhcpcd on its way.
WIFI_DHCPCD_CONF=/etc/dhcpcd.conf
grep -q 192.168.3.32 $WIFI_DHCPCD_CONF
if [[ $? -ne 0 ]]; then
  # This file needs an update
  echo "" >> $WIFI_DHCPCD_CONF
  echo "interface wlan0" >> $WIFI_DHCPCD_CONF
  echo "  static ip_address=192.168.3.32/24" >> $WIFI_DHCPCD_CONF
  echo "  static routers=192.168.3.1" >> $WIFI_DHCPCD_CONF
  echo "  static domain_name_servers=192.168.3.1" >> $WIFI_DHCPCD_CONF
fi

# Lets get the sid to connect to:
ip link set $WIFI_INT up
ESSID=""
while [[ "$ESSID" == "" ]]; do
  ESSID=`iwlist $WIFI_INT scanning | grep "ESSID:\"100-" | awk -F'"' '{print $2}'`
  if [[ "$ESSID" == "" ]]; then
    sleep 1
  fi
done

echo "ESSID: $ESSID"

# Below is for test env which has password set for wifi
# Comment below line or set it to "" if open wifi.
#WIFI_PASSWD="6507436826"

# Lets check on the /etc/wpa_supplicant.conf file if it needs modification.
WIFI_WPACONF="/etc/wpa_supplicant/wpa_supplicant.conf"
grep -q 100- $WIFI_WPACONF
if [[ $? -ne 0 ]]; then
  # This file needs an update
  echo "" >> $WIFI_WPACONF
  echo "network={" >> $WIFI_WPACONF
  echo "  ssid=\"$ESSID\"" >> $WIFI_WPACONF
  if [[ "$WIFI_PASSWD" != "" ]]; then
    # This is test env with a WIFI password
    echo "  psk=\"$WIFI_PASSWD\"" >> $WIFI_WPACONF
  else
    # No wifi password
    echo "  key_mgmt=NONE" >> $WIFI_WPACONF
  fi
  echo "}" >> $WIFI_WPACONF

  # We need to daemon reload as we have modified some conf files which are used
  # by dhcpcd.
  systemctl daemon-reload
  systemctl restart dhcpcd.service
fi
