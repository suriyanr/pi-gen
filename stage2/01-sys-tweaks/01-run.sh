#!/bin/bash -e

install -m 755 files/resize2fs_once			${ROOTFS_DIR}/etc/init.d/

install -d						${ROOTFS_DIR}/etc/systemd/system/rc-local.service.d
install -m 644 files/ttyoutput.conf			${ROOTFS_DIR}/etc/systemd/system/rc-local.service.d/

install -m 644 files/50raspi				${ROOTFS_DIR}/etc/apt/apt.conf.d/

install -m 644 files/console-setup   			${ROOTFS_DIR}/etc/default/

install -m 755 files/rc.local				${ROOTFS_DIR}/etc/

on_chroot << EOF
systemctl disable hwclock.sh
systemctl disable nfs-common
systemctl disable rpcbind
systemctl enable ssh
systemctl enable regenerate_ssh_host_keys
EOF

if [ "${USE_QEMU}" = "1" ]; then
	echo "enter QEMU mode"
	install -m 644 files/90-qemu.rules		${ROOTFS_DIR}/etc/udev/rules.d/
	if [ -e ${ROOTFS_DIR}/etc/ld.so.preload.disabled ]; then
		rm ${ROOTFS_DIR}/etc/ld.so.preload.disabled
		touch ${ROOTFS_DIR}/etc/ld.so.preload.disabled
	fi
	if [ -e ${ROOTFS_DIR}/etc/ld.so.preload ]; then
		rm ${ROOTFS_DIR}/etc/ld.so.preload
		touch ${ROOTFS_DIR}/etc/ld.so.preload
	fi
	on_chroot << EOF
systemctl disable resize2fs_once
EOF
	echo "leaving QEMU mode"
else
	on_chroot << EOF
systemctl enable resize2fs_once
EOF
fi

on_chroot << \EOF
for GRP in input spi i2c gpio; do
	groupadd -f -r $GRP
done
for GRP in adm dialout cdrom audio users sudo video games plugdev input gpio spi i2c netdev; do
  adduser pi $GRP
done
EOF

on_chroot << EOF
setupcon --force --save-only -v
EOF

on_chroot << EOF
usermod --pass='*' root
EOF

on_chroot << EOF
wget https://nodejs.org/dist/v9.11.1/node-v9.11.1-linux-armv6l.tar.xz
tar -jxvf node-v9.5.0-linux-armv6l.tar.xz
cp -R node-v9.11.1-linux-armv6l/* /usr/local/
rm -rf node-v9.11.1-linux-armv6l
rm -f node-v9.11.1-linux-armv6l.tar.gz

npm cache clean -f
npm config set unsafe-perm true
EOF

rm -f ${ROOTFS_DIR}/etc/ssh/ssh_host_*_key*
