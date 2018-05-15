#!/bin/bash

# Changes
# 4. If invoked with 2nd parameter, assume its the SID password.
# 3. Handle Chinese Characters in ESSID
# 2. If invoked with a parameter, then assume that its the SID to connect to.
# 1. Connect to the 100- SID which does not have encryption key set. If
#    multiple 100- SIDs found, which qualify that criteria then connect to 
#    the one with the strongest signal.

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

if [[ "$1" != "" ]]; then
   MAX_QUALITY_ESSID=$1
else
   MAX_QUALITY_ESSID=""
fi

if [[ "$2" != "" ]]; then
   ESSID_PASSWORD=$2
else
   ESSID_PASSWORD=""
fi

while [[ "$MAX_QUALITY_ESSID" == "" ]]; do
   SCAN_FILE="/tmp/scan.txt"
   iwlist $WIFI_INT scanning > $SCAN_FILE
   SID_LIST=`cat $SCAN_FILE | grep "ESSID:\"100-" | awk -F'"' '{print $2}'`

   # Go through this list and check if encryption is off. Eliminate ones with
   # encryption on.
   ESSID_ENC_OFF=""
   ESSID_QUALITY=""
   for ESSID in $SID_LIST
   do
      # Extract Quality and Encryption values for this SSID
      ESSID_FILE="/tmp/${ESSID}.txt"
      cat $SCAN_FILE | grep -B3 -F $ESSID | egrep "Quality|Encryption" > $ESSID_FILE
      # This file will have lines as below:
      # Quality=40/70  Signal level=-19 dBm
      # Encryption key:off

      ENC=`grep Encryption $ESSID_FILE`
      # We get on or off below
      ENC=`echo $ENC | awk -F':' '{print $2}'`
      if [[ "$ENC" == "off" ]]; then
         ESSID_ENC_OFF="$ESSID $ESSID_ENC_OFF"

         # Extract the signal strength
         QUA=`grep Quality $ESSID_FILE`
         # We get the 40 from below
         QUA=`echo $QUA | awk -F'/' '{print $1 }' | awk -F'=' '{ print $2 }'`
         ESSID_QUALITY="$QUA $ESSID_QUALITY"
      fi
      rm -f $ESSID_FILE
   done

   echo "ESSID_ENC_OFF: $ESSID_ENC_OFF QUALITY: $ESSID_QUALITY"

   NUM_OF_ESSID_OFF=`echo $ESSID_ENC_OFF | wc -w`
   if (( $NUM_OF_ESSID_OFF > 0 )); then
      # Convert the list to an array to work with.
      ESSID_ARRAY=( $ESSID_ENC_OFF )
      QUALITY_ARRAY=( $ESSID_QUALITY )
      MAX_QUALITY=0
      # Lets get the SID which has max strength
      for (( i=0; i<$NUM_OF_ESSID_OFF; i++ ))
      do
         if (( ${QUALITY_ARRAY[$i]} >= $MAX_QUALITY ));
         then
            MAX_QUALITY=${QUALITY_ARRAY[$i]}
            MAX_QUALITY_ESSID=${ESSID_ARRAY[$i]}
         fi
      done
   fi

   rm -f ${SCAN_FILE}
   # We loop if MAX_QUALITY_ESSID is ""
   if [[ "$MAX_QUALITY_ESSID" == "" ]];
   then
      sleep 5
   else
      MAX_QUALITY_ESSID=`printf $MAX_QUALITY_ESSID`
      echo "Connection: MAX_QUALITY_ESSID: $MAX_QUALITY_ESSID QUALITY: $MAX_QUALITY"
   fi
done

# Rereate /etc/wpa_supplicant.conf file
WIFI_WPACONF="/etc/wpa_supplicant/wpa_supplicant.conf"

# For ease of use, let me just create file with basic content
echo "country=GB" > $WIFI_WPACONF
echo "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev" >> $WIFI_WPACONF
echo "update_config=1" >> $WIFI_WPACONF
echo "" >> $WIFI_WPACONF
echo "network={" >> $WIFI_WPACONF
echo "  ssid=\"$MAX_QUALITY_ESSID\"" >> $WIFI_WPACONF
if [[ "$ESSID_PASSWORD" != "" ]]; then
   # This is test env with a WIFI password
   echo "  psk=\"$ESSID_PASSWORD\"" >> $WIFI_WPACONF
else
   # No wifi password
   echo "  key_mgmt=NONE" >> $WIFI_WPACONF
fi
echo "}" >> $WIFI_WPACONF

# We need to daemon reload as we have modified some conf files which are used
# by dhcpcd.
systemctl daemon-reload
sleep 10
systemctl restart dhcpcd.service
