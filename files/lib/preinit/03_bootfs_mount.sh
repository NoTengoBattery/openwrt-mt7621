#!/bin/sh
#
# Problems? Sugestions? Contact me here: https://github.com/NoTengoBattery/openwrt/issues
#
# This script runs before mouting the overlay root file system, and it exist to
# create the node for the "syscfg" partition (so it can be used as overlay).

. /lib/functions.sh

bootfs_mount() {
  exec 2> /dev/null
  printf "preinit: running bootfs attach pre-init script..." > /dev/kmsg

  ubi_rebuild() {
    local UBI=$1
    ubiupdatevol "$UBI" -t
  }

  BOOTFS=/bootfs
  OVERLAYFS=/overlayfs
  BOOTFS_TRIG=${BOOTFS}/.sysupgrade_trigger
  BOOTFS_TARZ=${BOOTFS}/sysupgrade.tgz

  case $(board_name) in
  glinet,gl-s1300)
    BOOTFS_MTD=11
    BOOTFS_DEVICE=/dev/mtdblock${BOOTFS_MTD}
    BOOTFS_OPTIONS='relatime'
    BOOTFS_TYPE=jffs2
    MMC_OVERLAY_BLK=0
    MMC_OVERLAY_PART=4
    OVERLAY_DEVICE=/dev/mmcblk${MMC_OVERLAY_BLK}p${MMC_OVERLAY_PART}
    OVERLAY_OPTIONS='relatime'
    ;;
  linksys,ea6350v3|\
  linksys,ea8300|\
  linksys,mr8300)
    BOOTFS_UBI=0
    BOOTFS_PART=1
    BOOTFS_DEVICE=/dev/ubi${BOOTFS_UBI}_${BOOTFS_PART}
    BOOTFS_OPTIONS='relatime,bulk_read,compr=zstd'
    BOOTFS_TYPE=ubifs
    UBI_SYSCFG=15
    SYSCFG_UBI=/dev/ubi${UBI_SYSCFG}
    OVERLAY_PART=1
    OVERLAY_DEVICE=${SYSCFG_UBI}_${OVERLAY_PART}
    OVERLAY_NODE=1
    OVERLAY_OPTIONS='relatime,bulk_read,compr=zstd'
    OVERLAY_TYPE=ubifs
    ROOTFS_DATA_NODE=2
    SYSCFG_NODE=0

    ubiattach -m $UBI_SYSCFG -d $UBI_SYSCFG
    node=$(awk '/'"ubi$UBI_SYSCFG"'/{print $1}' /proc/devices)
    if [ "x$node" != "x" ]; then
      mknod -m 600 $SYSCFG_UBI c $node $SYSCFG_NODE
      mknod -m 600 $OVERLAY_DEVICE c $node $OVERLAY_NODE
    fi
    node=$(awk '/'"ubi$BOOTFS_UBI"'/{print $1}' /proc/devices)
    if [ "x$node" != "x" ]; then
      mknod -m 600 $BOOTFS_DEVICE c $node $ROOTFS_DATA_NODE
    fi
    ;;
  zbtlink,zbt-wg3526-16m|\
  zbtlink,zbt-wg3526-32m)
    BOOTFS_MTD=6
    BOOTFS_DEVICE=/dev/mtdblock${BOOTFS_MTD}
    BOOTFS_OPTIONS='relatime'
    BOOTFS_TYPE=jffs2
    MMC_OVERLAY_BLK=0
    MMC_OVERLAY_PART=1
    OVERLAY_DEVICE=/dev/mmcblk${MMC_OVERLAY_BLK}p${MMC_OVERLAY_PART}
    OVERLAY_OPTIONS='relatime'
    ;;
  esac
  mount -t $BOOTFS_TYPE -o "$BOOTFS_OPTIONS" $BOOTFS_DEVICE $BOOTFS
  if [ $? -eq 0 ]; then
    printf "preinit: successfully mounted the boot file system" > /dev/kmsg
    if [ ! -f "$BOOTFS_TRIG" ]; then
      printf "preinit: moving backup to overlay filesystem" > /dev/kmsg
      if [ "x$OVERLAY_TYPE" = "x" ]; then
        mount -o "$OVERLAY_OPTIONS" $OVERLAY_DEVICE $OVERLAYFS
      else
        mount -t $OVERLAY_TYPE -o "$OVERLAY_OPTIONS" $OVERLAY_DEVICE $OVERLAYFS
      fi
      rm -rf $OVERLAYFS
      cp -ar $BOOTFS_TARZ $OVERLAYFS
      rm -rf $BOOTFS
      printf "preinit: configuring the default extroot" > /dev/kmsg
      FSTAB=/etc/config/fstab
      UPPER_CONFIG=/upper/etc/config
      cp -af /rom${FSTAB} ${BOOTFS}/upper${FSTAB}
      uci -c ${BOOTFS}${UPPER_CONFIG} set fstab.@mount[0].device="$OVERLAY_DEVICE"
      uci -c ${BOOTFS}${UPPER_CONFIG} set fstab.@mount[0].options="$OVERLAY_OPTIONS"
      uci -c ${BOOTFS}${UPPER_CONFIG} commit
      touch $BOOTFS_TRIG
    fi
  fi
  mount -t pstore pstore /sys/fs/pstore
  if [ $? -eq 0 ]; then
    printf "preinit: successfully mounted pstore" > /dev/kmsg
  fi
}

boot_hook_add preinit_main bootfs_mount
boot_hook_add failsafe bootfs_mount
