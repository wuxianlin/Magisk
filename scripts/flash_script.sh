#MAGISK
##########################################################################################
#
# Magisk Flash Script (updater-script)
# by topjohnwu
#
# This script will detect, construct the environment for Magisk
# It will then call boot_patch.sh to patch the boot image
#
##########################################################################################

##########################################################################################
# Preparation
##########################################################################################

COMMONDIR=$INSTALLER/common
APK=$COMMONDIR/magisk.apk
CHROMEDIR=$INSTALLER/chromeos
AVBTOOL=$INSTALLER/avbtool-arm

# Default permissions
umask 022

OUTFD=$2
ZIP=$3

if [ ! -f $COMMONDIR/util_functions.sh ]; then
  echo "! Unable to extract zip file!"
  exit 1
fi

# Load utility fuctions
. $COMMONDIR/util_functions.sh

setup_flashable

##########################################################################################
# Detection
##########################################################################################

ui_print "************************"
ui_print "* Magisk v$MAGISK_VER Installer"
ui_print "************************"

is_mounted /data || mount /data || is_mounted /cache || mount /cache
mount_partitions
check_data
get_flags
find_boot_image

[ -z $BOOTIMAGE ] && abort "! Unable to detect target image"
ui_print "- Target image: $BOOTIMAGE"

# Detect version and architecture
api_level_arch_detect

[ $API -lt 17 ] && abort "! Magisk is only for Android 4.2 and above"

ui_print "- Device platform: $ARCH"

BINDIR=$INSTALLER/$ARCH32
chmod -R 755 $CHROMEDIR $BINDIR

# Check if system root is installed and remove
remove_system_su

##########################################################################################
# Environment
##########################################################################################

ui_print "- Constructing environment"

# Copy required files
rm -rf $MAGISKBIN/* 2>/dev/null
mkdir -p $MAGISKBIN 2>/dev/null
cp -af $BINDIR/. $COMMONDIR/. $CHROMEDIR $AVBTOOL $BBDIR/busybox $MAGISKBIN
chmod -R 755 $MAGISKBIN

# addon.d
if [ -d /system/addon.d ]; then
  ui_print "- Adding addon.d survival script"
  mount -o rw,remount /system
  ADDOND=/system/addon.d/99-magisk.sh
  cat <<EOF > $ADDOND
#!/sbin/sh
# ADDOND_VERSION=2

if [ -f /data/adb/magisk/addon.d.sh ]; then
  exec sh /data/adb/magisk/addon.d.sh "\$@"
else
  OUTFD=\$(ps | grep -v 'grep' | grep -oE 'update(.*)' | cut -d" " -f3)
  ui_print() { echo -e "ui_print \$1\nui_print" >> /proc/self/fd/\$OUTFD; }

  ui_print "************************"
  ui_print "* Magisk addon.d failed"
  ui_print "************************"
  ui_print "! Cannot find Magisk binaries - was data wiped or not decrypted?"
  ui_print "! Reflash OTA from decrypted recovery or reflash Magisk"
fi
EOF
  chmod 755 $ADDOND
fi

$BOOTMODE || recovery_actions

##########################################################################################
# Boot/DTBO Patching
##########################################################################################

patch_boot_image

cd /
# Cleanups
$BOOTMODE || recovery_cleanup
rm -rf $TMPDIR

ui_print "- Done"
exit 0
