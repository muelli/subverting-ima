#!/bin/bash -ex
# That's https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img
BASEIMAGE=${1:-~/.local/share/libvirt/images/focal-server-cloudimg-amd64.img}
BASEIMAGE=${1:-~/data/focal-server-cloudimg-amd64.img}
CLOUD_ISO=${2:-~/vcs/Cloud-Init-ISO/cloudimageboot-ima-guest.iso}
CLOUD_ISO=${2:-./cloudimageboot-ima-guest.iso}
IMAGE=${3:-~/.local/share/libvirt/images/ubuntu-20.04-ima-appraisal.img}
IMAGE=${3:-~/data/ima-appraisal-hack-tcb-tmm.img}
FAT_IMAGE="${IMAGE}-fat_image.raw"

_MAKEIMAGE_STEP=${MAKEIMAGE_STEP:-prepare}
_MAKEIMAGE_STEP=${MAKEIMAGE_STEP:-modify}

_PREPIMAGE=${PREPIMAGE:-${IMAGE}-prepared}

if [ ${_MAKEIMAGE_STEP:-} == "" ] || [ ${_MAKEIMAGE_STEP:-} == "prepare" ] ; then

cp -ar --reflink=auto ${BASEIMAGE} ${_PREPIMAGE}
chattr +C ${_PREPIMAGE}  ||  echo  chattr seems to be not supported here
chmod u+rw ${_PREPIMAGE}
qemu-img resize ${_PREPIMAGE} +10G

# ima_appraise_tcb is deprecated. Use ima_policy= instead. https://patchwork.kernel.org/patch/10886043/
# ignore_loglevel in combination with ima logging is very annoying when debugging a running system
virt-edit  -a ${_PREPIMAGE} --edit  "s/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"ima_policy=appraise_tcb ima_audit=1 ima_appraise=log loglevel=7 ignore_loglevell\"/"  /etc/default/grub
virt-edit  -a ${_PREPIMAGE} --edit  "s/console=tty1 console=ttyS0/console=tty1 console=ttyS0 ima_policy=appraise_tcb ima_audit=1 ima_appraise=log loglevel=7 ignore_loglevell/g"  /boot/grub/grub.cfg

# Hrm. We don't get to have xattrs on FAT, do we?
virt-edit  -a ${_PREPIMAGE} --edit  "s/ima_policy=appraise_tcb/ima_policy=tcb/g"  /boot/grub/grub.cfg


if [ -z "$DISPLAY" ];
then
    MONITOR="-monitor telnet:localhost:43210,server,nowait  -nographic"
else
    MONITOR=""
fi
echo Press Ctrl+Alt+2 to potentially speed up the machine
for i in 1 2; do
    # Don't know why it doesn't boot the first time...
    qemu-system-x86_64 -enable-kvm -m 2G -no-reboot -drive file=${_PREPIMAGE},if=virtio -net nic -net user  -cdrom ${CLOUD_ISO} -serial stdio ${MONITOR}
done
fi  # endif prepare

if [ ${_MAKEIMAGE_STEP:-} == "prepare" ]; then
    echo Finishing preparing images. Continue with
    echo env 'MAKEIMAGE_STEP=modify'  $0 "$@"
    exit 0
fi

cp -ar --reflink=auto ${_PREPIMAGE} ${IMAGE}

rm -f "${FAT_IMAGE}"
truncate --size 1000000000 ${FAT_IMAGE}
mkfs.fat ${FAT_IMAGE}

_MANIPULATE_MEGABYTES=${MANIPULATE_MEGABYTES:-256}
QEMU_MANIPULATE_SIZE=$(( 1024*1024*${_MANIPULATE_MEGABYTES:-256} ))
make -B  QEMU_MANIPULATE_SIZE=$QEMU_MANIPULATE_SIZE test-ima-cache-evict
rm test-ima-cache-evict.h



# That's the offset of the "foo" array
# hm. except it's 0x20000 too large :-/
FOO_MEM_ADDR=$(nm --print-size --size-sort --radix=x test-ima-cache-evict | grep ' foo$' | awk '{$1=strtonum("0x" $1)} {print $1}')
# That's the size of the foo object
nm --print-size --size-sort --radix=x test-ima-cache-evict | grep ' foo$' | awk '{$2=strtonum("0x" $2)} {print $2}'

# Is "foo" in .text or .data?
FOO_IN_TEXT_OR_DATA=$(objdump -x test-ima-cache-evict | grep " foo$" | awk '{print $4}')
if [ ${FOO_IN_TEXT_OR_DATA} == ".text" ]; then
    # This is the "logical memory address" of the data section
    TEXT_SEC_ADDR=$(objdump -x test-ima-cache-evict | grep " .text      " |  awk '{$4=strtonum("0x" $4)} {print $4}')
    # This is the offset of the data section in the file
    TEXT_SEC_OFFSET=$(objdump -x test-ima-cache-evict | grep " .text      " |  awk '{$6=strtonum("0x" $6)} {print $6}')

    FOO_FILE_ADDR=$(( $FOO_MEM_ADDR - $TEXT_SEC_ADDR + $TEXT_SEC_OFFSET ))

else if [ ${FOO_IN_TEXT_OR_DATA} == ".data" ]; then
    # This is the "logical memory address" of the data section
    DATA_SEC_ADDR=$(objdump -x test-ima-cache-evict | grep " .data      " |  awk '{$4=strtonum("0x" $4)} {print $4}')
    # This is the offset of the data section in the file
    DATA_SEC_OFFSET=$(objdump -x test-ima-cache-evict | grep " .data      " |  awk '{$6=strtonum("0x" $6)} {print $6}')

    FOO_FILE_ADDR=$(( $FOO_MEM_ADDR - $DATA_SEC_ADDR + $DATA_SEC_OFFSET ))
else
    echo Where is foo?
    exit 2
fi
fi


# This is hard-coded in QEMU code
QEMU_FIXED_ADDR=8256
#QEMU_FIXED_ADDR=2112
if ! [ ${FOO_FILE_ADDR} == ${QEMU_FIXED_ADDR} ]; then
    echo Hrm. It seems the data section offest has changed. Expected ${QEMU_FIXED_ADDR}, got ${FOO_FILE_ADDR}.
    exit 1
fi


guestfish -a ${IMAGE} -a ${FAT_IMAGE} -i --rw \
      chown 0 0 /usr/local/bin \
    : mount /dev/sdb /usr/local \
    : mkdir /usr/local/bin  \
    : copy-in test-ima-cache-evict                 /usr/local/bin \
    : chown 0 0 /usr/local/bin/test-ima-cache-evict \
    : command "bash -c 'echo /dev/sda /usr/local                 vfat       iversion 0 0 >> /etc/fstab'" \
    : copy-in test-ima-cache-evict.service        /etc/systemd/system/ \
    : copy-in test-ima-cache-evict-master.service /etc/systemd/system/ \
    : copy-in test-ima-cache-evict.timer          /etc/systemd/system/ \
    : copy-in stress-ng.service                   /etc/systemd/system/ \
    : copy-in stress-ng.timer                     /etc/systemd/system/ \
    : command "ln -s /dev/null /etc/tmpfiles.d/systemd-nologin.conf" \
    : command "systemctl enable test-ima-cache-evict.timer" \

#    : command "systemctl enable stress-ng.timer" \
#    : copy-in imafix.service                      /etc/systemd/system/ \

_STRESS_MEGABYTES=${STRESS_MEGABYTES:-128}
virt-edit  -a ${IMAGE} --edit  "s/STRESS_MEMORY_SIZE=300/STRESS_MEMORY_SIZE=${_STRESS_MEGABYTES}/"   /etc/systemd/system/stress-ng.service


## TM: FIXME: how do we get the offset of the file?
#guestfish -a ${IMAGE} -a ${FAT_IMAGE} -i --ro \
#      mount /dev/sdb /usr/local \
#    : command "filefrag -v /usr/local/bin/test-ima-cache-evict" \
#    : ls /usr/local/bin


# TM: Just temporarily disable IMA, because I think we don't need it to test for manipulated bytes by the hdd driver.
# virt-edit  -a ${IMAGE} --edit  "s/ima_policy=/ima_policy_disabled=/g"  /boot/grub/grub.cfg

qemu-img snapshot -c before-run ${IMAGE}

echo env LOGPREFIX="" ./run-measurement.sh ${IMAGE} ${_MANIPULATE_MEGABYTES} ${_STRESS_MEGABYTES}
