#!/bin/sh
#
# Support parameters (via command line or kernel parameter):
# ------------------------------------------------------------------------------
# overlay.mount=<source_device>

# -----------------------------------------------------------------------------
# config
PATH=/sbin:/bin:/usr/sbin:/usr/bin 
INIT="/sbin/init"
ROOT_RO="/"
ROOT_RW="/mnt/data"
ROOT_RW_UPPER="$ROOT_RW/upper"
ROOT_RW_WORK="$ROOT_RW/work"
rootmnt="/mnt/root"

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
  grep -w "/dev" /proc/mounts >/dev/null || mount -t devtmpfs none /dev
}
setup

# -----------------------------------------------------------------------------
# parse kernel boot command line
parse_args() {
  OVERLAY_MOUNT=
  FACTORY_DEFAULT="/sbin/factory-default"
  for CMD_PARAM in $(cat /proc/cmdline); do
      case ${CMD_PARAM} in
          overlay.mount=*)
            OVERLAY_MOUNT="${CMD_PARAM#overlay.mount=}"
            ;;
          overlay.factorydefault=*)
            FACTORY_DEFAULT="${CMD_PARAM#overlay.factorydefault=}"
            ;;
      esac
  done

  log "overlay.mount='$OVERLAY_MOUNT'"
  log "overlay.factorydefault='$FACTORY_DEFAULT'"
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
    exit 0
fi

modprobe -qb fuse
if [ $? -ne 0 ]; then
    log "ERROR: missing kernel module fuse"
    exit 0
fi

log "mount read/write partition"
mount -t tmpfs none /mnt
mkdir -p $rootmnt $ROOT_RW
mount $OVERLAY_MOUNT $ROOT_RW

log "mount overlayfs"
mkdir -p $ROOT_RW_UPPER $ROOT_RW_WORK
mount -t overlay -o lowerdir=$ROOT_RO,upperdir=$ROOT_RW_UPPER,workdir=$ROOT_RW_WORK overlay $rootmnt

log "mount persistent overlay partition"
mkdir -p $rootmnt/mnt/root-upper
mount $OVERLAY_MOUNT $rootmnt/mnt/root-upper
umount $ROOT_RW

log "change root to $rootmnt"
mkdir -p $rootmnt/mnt/root-lower
cd $rootmnt
pivot_root . $rootmnt/mnt/root-lower

# new root is set, clear or move unused mounts
umount /mnt/root-lower/mnt
mount -n --move /mnt/root-lower/proc /proc
mount -n --move /mnt/root-lower/dev /dev
mount -n --move /mnt/root-lower/sys /sys

log "execute $INIT"
exec $INIT
log "Error: reinit: exec $INIT failed"
fatal
