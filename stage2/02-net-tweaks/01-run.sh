#!/bin/bash -e

install -v -d						${ROOTFS_DIR}/etc/systemd/system/dhcpcd.service.d
install -v -m 644 files/wait.conf			${ROOTFS_DIR}/etc/systemd/system/dhcpcd.service.d/

install -v -d                                           ${ROOTFS_DIR}/etc/wpa_supplicant
install -v -m 600 files/wpa_supplicant.conf             ${ROOTFS_DIR}/etc/wpa_supplicant/

install -v -d						${ROOTFS_DIR}/opt/captivePortal
install -v -m 644 files/captivePortalRSN.tar.gz		${ROOTFS_DIR}/opt/captivePortal/
install -v -m 544 files/ScanAndConnect.sh		${ROOTFS_DIR}/opt/captivePortal/
install -v -m 644 files/ScanAndConnect.service		${ROOTFS_DIR}/etc/systemd/system/
install -v -m 644 files/dhcpServer.service		${ROOTFS_DIR}/etc/systemd/system/
install -v -m 644 files/webServer.service		${ROOTFS_DIR}/etc/systemd/system/

on_chroot << EOF
systemctl enable ScanAndConnect.service
systemctl enable dhcpServer.service
systemctl enable webServer.service
systemctl enable getty@ttyGS0.service
EOF

on_chroot << EOF
cd /opt/captivePortal
tar -zxvf /opt/captivePortal/captivePortalRSN.tar.gz
rm -f captivePortalRSN.tar.gz
npm install
sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.d/99-sysctl.conf
# apt-get -y remove --purge build-essential
apt-get -y autoremove --purge 
EOF
