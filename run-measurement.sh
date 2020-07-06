#!/bin/bash -ex
IMAGE=${1}
_MANIPULATE_MEGABYTES=${2}
_STRESS_MEGABYTES=${3}
TIMES=${4:-1}

FAT_IMAGE="${IMAGE}-fat_image.raw"
QEMU_MANIPULATE_SIZE=$(( 1024*1024*${_MANIPULATE_MEGABYTES:-256} ))

PORT=$(shuf -i 2000-65000 -n 1)
echo Port: ${PORT}
echo ============

for i in $(seq 1 ${TIMES}); do

qemu-img snapshot -a 1  ${IMAGE}
env QEMU_MANIPULATE_SIZE=$QEMU_MANIPULATE_SIZE  ../../qemu-tmm/x86_64-softmmu/qemu-system-x86_64 -m 512M  \
        -drive file=${IMAGE},if=none,id=disk1 -device virtio-blk-pci,drive=disk1,bootindex=1   \
        -drive file=${FAT_IMAGE},if=none,id=fatdisk,snapshot -device ide-hd,drive=fatdisk,bootindex=4   \
        -serial telnet:localhost:${PORT},server,nowait -enable-kvm -nographic

qemu-img snapshot -c after-run-manipulate-${_MANIPULATE_MEGABYTES}-stress-${_STRESS_MEGABYTES}   ${IMAGE}


rm -rf /tmp/journal.bak/
mkdir -p /tmp/journal
mv /tmp/journal/ /tmp/journal.bak
mkdir -p /tmp/journal
virt-copy-out  -a ${IMAGE}  /var/log/journal/  /tmp/journal/
_LOGPREFIX=${LOGPREFIX:-~/qemu-share/measurements/$(hostname)}
journalctl --directory=/tmp/journal/journal  --output=export --output-fields=MANIPULATED_BYTES_PCT  MESSAGE_ID=75017a97fdd044cf894e037a7fcabd78 | grep --text MANIPULATED_BYTES_PCT | tee -a ${_LOGPREFIX}/data-manipulate-${_MANIPULATE_MEGABYTES}-stress-${_STRESS_MEGABYTES}.txt

# journalctl --output=export --unit=test-ima-cache-evict.service MESSAGE_ID=75017a97fdd044cf894e037a7fcabd78 MESSAGE_ID=e363be7ee1db462b9fcf6492173fcc78 MESSAGE_ID=66143216050d45968af3ad6ea904bd74 | egrep  --text 'I=|ADDR=' 

done  # endfor
