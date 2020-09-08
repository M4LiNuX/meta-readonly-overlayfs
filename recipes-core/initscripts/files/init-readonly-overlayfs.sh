#!/bin/sh
#
# Support parameters (via command line or kernel parameter):
# ------------------------------------------------------------------------------
# overlay.mount=<source_device>

# -----------------------------------------------------------------------------
# config
PATH="/sbin:/bin:/usr/sbin:/usr/bin"
INIT="/sbin/init"
BASE="/mnt"
ROOT_RO="/"
ROOT_RO_NEW="$BASE/ro"
ROOT_RW="$BASE/rw"
ROOT_RW_UPPER="$ROOT_RW/upper"
ROOT_RW_WORK="$ROOT_RW/work"
ROOT_CONFIG="$BASE/share"
rootmnt="$BASE/root"

# -----------------------------------------------------------------------------
# functions
fatal() {
  log Error occurred, dropping to sh
  /bin/sh
  exit 1
}
trap fatal ERR

log() {
  echo "overlayfs: $@" > /dev/kmsg
}

run() {
  echo "exec: $@" > /dev/kmsg
  "$@"
}

setup() {
  mount -t proc proc /proc
  mount -t sysfs sysfs /sys
  mount -t tmpfs tmpfs /tmp
  grep -w "/dev" /proc/mounts >/dev/null || mount -t devtmpfs none /dev
}
setup

# -----------------------------------------------------------------------------
# parse kernel boot command line
parse_args() {
  OVERLAY_MOUNT=
  OVERLAY_TYPE=
  OVERLAY_MOUNT_OPTIONS=
  CONFIG_MOUNT=
  CONFIG_TYPE=
  CONFIG_MOUNT_OPTIONS=

  FACTORY_DEFAULT="/sbin/factory-default"
  for CMD_PARAM in $(cat /proc/cmdline); do
      case ${CMD_PARAM} in
          overlay.mount=*)
            OVERLAY_MOUNT="${CMD_PARAM#overlay.mount=}"
            ;;
          overlay.type=*)
            OVERLAY_TYPE="${CMD_PARAM#overlay.type=}"
            OVERLAY_MOUNT_OPTIONS="-t $OVERLAY_TYPE"
            ;;
          overlay.factorydefault=*)
            FACTORY_DEFAULT="${CMD_PARAM#overlay.factorydefault=}"
            ;;
          config.mount=*)
            CONFIG_MOUNT="${CMD_PARAM#config.mount=}"
            ;;
          config.type=*)
            CONFIG_TYPE="${CMD_PARAM#config.type=}"
            CONFIG_MOUNT_OPTIONS="-t $CONFIG_TYPE"
            ;;
      esac
  done

  log "overlay.mount='$OVERLAY_MOUNT'"
  log "overlay.type='$OVERLAY_TYPE'"
  log "overlay.factorydefault='$FACTORY_DEFAULT'"
  log "config.mount='$CONFIG_MOUNT'"
  log "config.type='$CONFIG_TYPE'"

  if [ -z "$OVERLAY_MOUNT" ]; then
      log "ERROR: mandatory options overlay.mount was not set"
      fatal
  fi
}

# -----------------------------------------------------------------------------
# main
log "INIT READONLY OVERLAYFS"
parse_args

if [ -f "$FACTORY_DEFAULT" ]; then
  . $FACTORY_DEFAULT
  factory_default $OVERLAY_MOUNT
else
  log "factory default script is not available"
fi

modprobe -qb overlay
if [ $? -ne 0 ]; then
    log "ERROR: missing kernel module overlay"
    fatal
fi

modprobe -qb fuse
if [ $? -ne 0 ]; then
    log "ERROR: missing kernel module fuse"
    fatal
fi

log "mount tmpfs on $BASE"
mount -t tmpfs none $BASE

log "mount read/write partition on $ROOT_RW"
mkdir -p $rootmnt $ROOT_RW
mount $OVERLAY_MOUNT_OPTIONS $OVERLAY_MOUNT $ROOT_RW

if [ ! -z "$CONFIG_MOUNT" ]; then 
    log "mount config partition on $ROOT_CONFIG"
    mkdir -p $ROOT_CONFIG
    mount $CONFIG_MOUNT_OPTIONS $CONFIG_MOUNT $ROOT_CONFIG
fi

# mount overlay filesystem
mkdir -p $ROOT_RW_UPPER $ROOT_RW_WORK
if [ ! -z "$CONFIG_MOUNT" ]; then
    log "mount overlayfs with config layer on $ROOT_CONFIG"
    mount -t overlay -o lowerdir=$ROOT_CONFIG:$ROOT_RO,upperdir=$ROOT_RW_UPPER,workdir=$ROOT_RW_WORK overlay $rootmnt
else
    log "mount overlayfs"
    mount -t overlay -o lowerdir=$ROOT_RO,upperdir=$ROOT_RW_UPPER,workdir=$ROOT_RW_WORK overlay $rootmnt
fi

log "umount $ROOT_RW and $ROOT_CONFIG"
umount $ROOT_RW
[ ! -z "$CONFIG_MOUNT" ] && umount $ROOT_CONFIG

log "change root to $rootmnt"
mkdir -p $rootmnt/$ROOT_RO_NEW
cd $rootmnt
pivot_root . $rootmnt/$ROOT_RO_NEW

log "new root is set, cleanup unsed mounts"
umount $ROOT_RO_NEW/mnt
mount -n --move $ROOT_RO_NEW/proc /proc
mount -n --move $ROOT_RO_NEW/dev /dev
mount -n --move $ROOT_RO_NEW/sys /sys
mount -n --move $ROOT_RO_NEW/tmp /tmp

log "remount $ROOT_RW"
mkdir -p $ROOT_RW
mount $OVERLAY_MOUNT_OPTIONS $OVERLAY_MOUNT $ROOT_RW
if [ ! -z "$CONFIG_MOUNT" ]; then
    log "remount $ROOT_CONFIG"
    mkdir -p $ROOT_CONFIG
    mount $CONFIG_MOUNT_OPTIONS $CONFIG_MOUNT $ROOT_CONFIG
fi
mount -o remount,r /

log "remove $OVERLAY_MOUNT from /etc/fstab"
sed -i "/$OVERLAY_MOUNT/d" /etc/fstab
if [ ! -z "$CONFIG_MOUNT" ]; then
    log "remove $CONFIG_MOUNT from /etc/fstab"
    sed -i "/$CONFIG_MOUNT/d" /etc/fstab
fi

log "execute $INIT"
exec $INIT
log "Error: reinit: exec $INIT failed"
fatal
