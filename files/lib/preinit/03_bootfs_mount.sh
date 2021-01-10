#!/bin/sh
#
# Problems? Sugestions? Contact me here: https://github.com/NoTengoBattery/openwrt/issues
#
# This script runs before mouting the overlay root file system, and it exist to
# create the node for the "syscfg" partition (so it can be used as overlay).

. /lib/functions.sh

bootfs_mount() {
  exec &>/dev/null
  printf "extroot-attach: running bootfs attach pre-init script..." > /dev/kmsg

  mknod_dev() {
    rm -f $1
    mknod -m 600 $1 $2 $MAJOR $MINOR
  }

  BOOTFS=/bootfs
  BOOTFS_TARZ=${BOOTFS}/sysupgrade.tgz
  BOOTFS_TRIG=${BOOTFS}/.sysupgrade_trigger
  ETC_CONFIG=/etc/config
  ETC_CONFIG_UPPER=/upper${ETC_CONFIG}
  ETC_CONFIG_BOOT=${BOOTFS}${ETC_CONFIG_UPPER}
  OVERLAYFS=/overlayfs
  ETC_CONFIG_OVERLAY=${OVERLAYFS}${ETC_CONFIG_UPPER}

  case $(board_name) in
  ezviz,cs-w3-wd1200g-eup)
    return
   ;;
   glinet,gl-s1300)
    BOOTFS_NODE_TYPE=b
    BOOTFS_OPTIONS='relatime'
    BOOTFS_TYPE=jffs2
    BOOTFS_UEVENT=/sys/block/mtdblock11/uevent
    OVERLAY_NODE_TYPE=b
    OVERLAY_OPTIONS='relatime'
    OVERLAY_UEVENT=/sys/block/mmcblk0/mmcblk0p4/uevent
   ;;
   linksys,ea6350v3|\
   linksys,ea8300|\
   linksys,mr8300)
    BOOTFS_NODE_TYPE=c
    BOOTFS_OPTIONS='relatime,bulk_read,compr=zstd'
    BOOTFS_TYPE=ubifs
    BOOTFS_UEVENT=/sys/class/ubi/ubi0_1/uevent
    OVERLAY_NODE_TYPE=c
    OVERLAY_OPTIONS='relatime,bulk_read,compr=zstd'
    OVERLAY_TYPE=ubifs
    OVERLAY_UEVENT=/sys/class/ubi/ubi15_0/uevent
    UBI_SYSCFG=15
    ubiattach -m $UBI_SYSCFG -d $UBI_SYSCFG
   ;;
   zbtlink,zbt-wg3526-16m|\
   zbtlink,zbt-wg3526-32m)
    BOOTFS_NODE_TYPE=b
    BOOTFS_OPTIONS='relatime'
    BOOTFS_TYPE=jffs2
    BOOTFS_UEVENT=/sys/block/mtdblock6/uevent
    OVERLAY_NODE_TYPE=b
    OVERLAY_OPTIONS='relatime'
    OVERLAY_UEVENT=/sys/block/mmcblk0/mmcblk0p1/uevent
   ;;
   esac

  eval "$(cat $BOOTFS_UEVENT)"
  BOOTFS_DEVICE=/dev/$DEVNAME
  mknod_dev $BOOTFS_DEVICE $BOOTFS_NODE_TYPE
  mount -t $BOOTFS_TYPE -o "$BOOTFS_OPTIONS" $BOOTFS_DEVICE $BOOTFS
  if [ $? -eq 0 ]; then
    printf "extroot-attach: successfully mounted the boot file system" > /dev/kmsg
    eval "$(cat $OVERLAY_UEVENT)"
    OVERLAY_DEVICE=/dev/$DEVNAME
    mknod_dev $OVERLAY_DEVICE $OVERLAY_NODE_TYPE
    if [ ! -f "$BOOTFS_TRIG" ]; then
      printf "extroot-attach: moving backup to overlay file system" > /dev/kmsg
      if [ "x$OVERLAY_TYPE" = "x" ]; then
        mount -o "$OVERLAY_OPTIONS" $OVERLAY_DEVICE $OVERLAYFS
      else
        mount -t $OVERLAY_TYPE -o "$OVERLAY_OPTIONS" $OVERLAY_DEVICE $OVERLAYFS
      fi
      if [ $? -eq 0 ]; then
        printf "extroot-attach: successfully mounted the new overlay" > /dev/kmsg
        rm -rf $OVERLAYFS
        if [ -f "$BOOTFS_TARZ" ]; then
          printf "extroot-attach: found the sysupgrade backup file!" > /dev/kmsg
          cp -ar $BOOTFS_TARZ $OVERLAYFS
        else
          printf "extroot-attach: sysupgrade backup file not found!" > /dev/kmsg
        fi
        rm -rf $BOOTFS
        printf "extroot-attach: configuring the default extroot" > /dev/kmsg
        mkdir -p $ETC_CONFIG_BOOT $ETC_CONFIG_OVERLAY
        cp -af ${ETC_CONFIG}/fstab $ETC_CONFIG_BOOT
        uci -c $ETC_CONFIG_BOOT set fstab.@mount[0].device="$OVERLAY_DEVICE"
        uci -c $ETC_CONFIG_BOOT set fstab.@mount[0].options="$OVERLAY_OPTIONS"
        uci -c $ETC_CONFIG_BOOT set fstab.@mount[1].device="$BOOTFS_DEVICE"
        uci -c $ETC_CONFIG_BOOT set fstab.@mount[1].options="$BOOTFS_OPTIONS"
        uci -c $ETC_CONFIG_BOOT commit
        cp -af ${ETC_CONFIG_BOOT}/fstab ${ETC_CONFIG_OVERLAY}/fstab
      fi
      touch $BOOTFS_TRIG
    fi
  fi
  umount $BOOTFS
  umount $OVERLAYFS
  mount -t pstore pstore /sys/fs/pstore
  if [ $? -eq 0 ]; then
    printf "extroot-attach: successfully mounted pstore" > /dev/kmsg
  fi
}

boot_hook_add preinit_main bootfs_mount
boot_hook_add failsafe bootfs_mount
