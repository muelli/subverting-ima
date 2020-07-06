#!/bin/bash -ex
# That's https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img
BASEIMAGE=${1:-~/.local/share/libvirt/images/focal-server-cloudimg-amd64.img}
BASEIMAGE=${1:-~/data/focal-server-cloudimg-amd64.img}
CLOUD_ISO=${2:-./cloudimageboot-ima-guest.iso}
IMAGE=${3:-~/.local/share/libvirt/images/ubuntu-20.04-ima-appraisal.img}
IMAGE=${3:-~/data/ima-appraisal-hack-tmm.img}

cp -ar --reflink=auto ${BASEIMAGE} ${IMAGE}
chattr +C ${IMAGE}  ||  echo  chattr seems to be not supported here
chmod u+rw ${IMAGE}
qemu-img resize ${IMAGE} +10G
# qemu-system-x86_64 -enable-kvm -no-reboot -m 1G -hda ${IMAGE}  -serial stdio
## hrm. virt-resize weirdly messes with the partitions, i.e. it doesn't boot after modification
# truncate -s 10G ${IMAGE}.bak
# virt-resize --expand /dev/sda1 --output-format raw ${IMAGE} ${IMAGE}.bak

## sfdisk also choked on that image. hrm.
#echo ", +" | sfdisk -N 0 ${IMAGE}
#guestfish -a ${IMAGE}  run : resize2fs /dev/sda2

# Maybe we can make use of a systemd-firstboot service instead.

#    : copy-in appendzeros.py        /usr/local/bin \
#    : copy-in appendzeros.service   /etc/systemd/system/ \
#    : chown 0 0 /usr/local/bin/appendzeros.py \
#    : chown 0 0 /etc/systemd/system/appendzeros.service \
#    : ln-s /etc/systemd/system/appendzeros.service  /etc/systemd/system/default.target.wants/appendzeros.service \
make check
guestfish -a ${IMAGE} -i --rw \
      chown 0 0 /usr/local/bin \
    : copy-in check                 /usr/local/bin \
    : copy-in check.sh              /usr/local/bin \
    : copy-in check.service         /etc/systemd/system/ \
    : copy-in imafix.service        /etc/systemd/system/ \
    : chown 0 0 /usr/local/bin/check \
    : chown 0 0 /usr/local/bin/check.sh \
    : chown 0 0 /etc/systemd/system/check.service \
    : chown 0 0 /etc/systemd/system/imafix.service \
    : command "systemctl enable check.service" \
    : command "systemctl disable snap.service" \
    : command "ln -s /dev/null  /etc/tmpfiles.d/systemd-nologin.conf" \
    : command "truncate --no-create --size 1G /usr/local/bin/check.sh" \

#    : command "useradd -m -p HIwyd0KZo65Jo ubuntu" \
#    : command "usermod -a -G sudo ubuntu" \
#    : command "usermod -a -G adm ubuntu" \


# ima_appraise_tcb is deprecated. Use ima_policy= instead. https://patchwork.kernel.org/patch/10886043/
virt-edit  -a ${IMAGE} --edit  "s/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"ima_policy=appraise_tcb ima_audit=1 ima_appraise=log loglevel=7\ ignore_loglevell\"/"  /etc/default/grub
virt-edit  -a ${IMAGE} --edit  "s/console=tty1 console=ttyS0/console=tty1 console=ttyS0 ima_policy=appraise_tcb ima_audit=1 ima_appraise=log loglevel=7 ignore_loglevell/g"  /boot/grub/grub.cfg

if [ -z "$DISPLAY" ];
then
    MONITOR="-monitor telnet:localhost:4321,server,nowait  -nographic"
else
    MONITOR=""
fi

echo Press Ctrl+Alt+2 to potentially speed up the machine
for i in 1 2; do
    # Don't know why it doesn't boot the first time...
    qemu-system-x86_64 -enable-kvm -m 2G -no-reboot -drive file=${IMAGE},if=virtio -net nic -net user  -cdrom ${CLOUD_ISO} -serial stdio ${MONITOR}
done


echo Now would be a good time to start the image with the cloud-image config to have the disk expand
echo I guess it also installs packages and fixes up the IMA hashes...
echo Meanwhile, you can enter the physical_offset and start address:
echo
echo
# https://unix.stackexchange.com/a/161927/71928
# https://superuser.com/a/644744/265964
guestfish -a ${IMAGE} -i --ro \
      command "filefrag -v /usr/local/bin/check.sh" \
    : command "cat /sys/block/sda/sda1/start"



read phyoffset
read vda1start
fileinimage=$((512*(${vda1start:-0} + ${phyoffset:-0}*8)))
echo your file may begin here: $((512*(${vda1start:-0} + ${phyoffset:-0}*8)))
echo dd if=${IMAGE} bs=1 skip=${fileinimage} count=100
echo


read


qemu-img convert -O raw  ${IMAGE} ${IMAGE}.bak
mv ${IMAGE}.bak ${IMAGE}







# instead of fix, one can do smth like
echo Run something like
echo     'sudo  find /  -path /proc -prune -o  -fstype ext4 -type f -uid 0 -exec evmctl ima_hash "{}" \;'
echo

# Now we need to run the image first, in order to get the cloud-init to change the password, install packages, and so on.


# Then, change ima_appraise=fix to ima_appraise=enforce and reboot
echo virt-edit  -a ${IMAGE} --edit  '"s/ima_appraise=log/ima_appraise=enforce/g"'  /boot/grub/grub.cfg

# it should boot normally.

# Then manipulate the check.sh or rather, find where in the file it is.
# God... grep is eating all the memory. but why?
# nice ionice grep --byte-offset --only-matching --text ${NEEDLE}  ${IMAGE}  |  awk '{printf ("0x%012x\n",$1)}'
./binsearch.py ${IMAGE} color=42 ${fileinimage}
echo sed -i 's/color=42/color=41/'  ${IMAGE}


echo ../../qemu-tmm/x86_64-softmmu/qemu-system-x86_64 -m 512M  -drive file=${IMAGE},if=virtio,snapshot  -serial telnet:localhost:4321,server,nowait -display sdl -enable-kvm

