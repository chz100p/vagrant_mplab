#!/bin/bash

# /bin/bash ./bootstrap.sh 2>&1 | tee bootstrap-$(date +%Y%m%d%H%M%S).log

set -euo pipefail

CONFIG__VM__VB__NAME=""
CONFIG__VM__VB__CPU="2"
CONFIG__VM__VB__MEMORY="1024"
CONFIG__VM__BASE_MAC=""
CONFIG__SSH__FORWARD_X11="true"

test -e Vagrantfile || cat >Vagrantfile <<===Vagrantfile===
# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  $( test "${CONFIG__VM__BASE_MAC}" != "" || echo -n \# )config.vm.base_mac = "${CONFIG__VM__BASE_MAC}"
  config.vm.box = "ubuntu/xenial32"
  $( test "${CONFIG__SSH__FORWARD_X11}" = "true" || echo -n \# )config.ssh.forward_agent = true
  $( test "${CONFIG__SSH__FORWARD_X11}" = "true" || echo -n \# )config.ssh.forward_x11 = true
  config.vm.synced_folder '.', '/vagrant', type: "virtualbox", disabled: false, mount_options: ['dmode=775','fmode=775']
  config.vm.synced_folder "../Downloads", "/Downloads", type: "virtualbox", mount_options: ['dmode=555','fmode=555']
  config.vm.provider "virtualbox" do |vb|
    $( test "${CONFIG__VM__VB__NAME}" != "" || echo -n \# )vb.name = "${CONFIG__VM__VB__NAME}"
    $( test "${CONFIG__VM__VB__CPU}" != "" || echo -n \# )vb.cpus = "${CONFIG__VM__VB__CPU}"
    $( test "${CONFIG__VM__VB__MEMORY}" != "" || echo -n \# )vb.memory = "${CONFIG__VM__VB__MEMORY}"
    #vb.gui = true
    #vb.customize ["modifyvm", :id, "--vram", "128"]
    #vb.customize ["modifyvm", :id, "--accelerate3d", "on"]
    vagrant_root = File.dirname(File.expand_path(__FILE__))
    file_to_disk = File.join(vagrant_root, 'disk', 'disk1.vdi')
    unless File.exist?(file_to_disk)
      vb.customize ['createhd', '--filename', file_to_disk, '--size', 200 * 1024]
    end
    vb.customize ['storageattach', :id, '--storagectl', 'SCSI Controller', '--port', 2, '--device', 0, '--type', 'hdd', '--medium', file_to_disk]
  end
end
===Vagrantfile===

#
mkdir -p scripts

#
test -e scripts/setup_vm.sh || cat >scripts/setup_vm.sh <<===setup_vm.sh===
#!/bin/bash

# vagrant ssh -- 'sudo /bin/bash /vagrant/scripts/setup_vm.sh'

set -euo pipefail

timedatectl set-timezone Asia/Tokyo
cp /vagrant/Vagrantfile /Vagrantfile-\$(date +%Y%m%d%H%M%S)
grep -q "10.0.2.15" /etc/hosts || {
    cat >>/etc/hosts <<=-=-=-=-=
10.0.2.15 ubuntu-xenial
=-=-=-=-=
}
grep -q "LABEL=/opt" /etc/fstab || {
  parted -s -a optimal /dev/sdc -- mklabel msdos mkpart primary ext4 1 -1
  mkfs.ext4 /dev/sdc1
  e2label /dev/sdc1 /opt
  mkdir -p /opt
  mount -t ext4 /dev/sdc1 /mnt
  ( cd /opt && tar cf - . ) | ( cd /mnt && tar xpf - )
  umount /mnt
  #rm -fr /opt
  #mkdir -p /opt
  echo "LABEL=/opt /opt ext4 defaults 0 0" >> /etc/fstab
  mount /opt
  mkdir -p /opt/microchip
}
grep -q "/home/ubuntu/workspace/microchip" /etc/fstab || {
  sudo -u ubuntu -g ubuntu mkdir -p /home/ubuntu/workspace/{microchip,.microchip_upper,.microchip_work}
  echo "overlay /home/ubuntu/workspace/microchip overlay noauto,x-systemd.automount,lowerdir=/opt/microchip,upperdir=/home/ubuntu/workspace/.microchip_upper,workdir=/home/ubuntu/workspace/.microchip_work 0 0" >> /etc/fstab
}
===setup_vm.sh===

test -e scripts/install_mplab.sh || cat >scripts/install_mplab.sh <<===install_mplab.sh===
#!/bin/bash

# vagrant ssh -- 'sudo /bin/bash /vagrant/scripts/install_mplab.sh'

set -euo pipefail

mkdir -p /vagrant/tmp
test "\$(getconf LONG_BIT)" = "32" || apt install -y libc6:i386 libx11-6:i386 libxext6:i386 libstdc++6:i386 libexpat1:i386
apt install -y expect
for f_tar in /Downloads/MPLABX-*-linux-installer.tar; do
    test -e "\${f_tar}" || continue
    f_tar_base="\${f_tar##*/}"
    f_ver="\${f_tar_base#MPLABX-}" && f_ver="\${f_ver%-linux-installer.tar}"
    test -e "/opt/microchip/mplabx/\${f_ver}" && echo "// \${f_tar_base} is already installed." && continue
    f_sh="/vagrant/tmp/\${f_tar_base%.tar}.sh"
    if [ ! -e "\${f_sh}" ]; then
        ( cd /vagrant/tmp && tar xf "\${f_tar}" )
    fi
    echo "// \${f_tar}"
    expect -f - <<EOF
set timeout 120
spawn "\${f_sh}" --nox11
expect {
"Press \\\\\\\\\\\\[Enter\\\\\\\\\\\\] to continue:*" {
send "\\\\r"
exp_continue
}
"Do you accept this license? \\\\\\\\\\\\[y/n\\\\\\\\\\\\]:" {
send "y\\\\r"
exp_continue
}
"Installation Directory \\\\\\\\\\\\[/opt/microchip/mplabx/\${f_ver}\\\\\\\\\\\\]:" {
send "\\\\r"
exp_continue
}
"MPLAB X IDE (Integrated Development Environment) \\\\\\\\\\\\[Y/n\\\\\\\\\\\\]:" {
send "\\\\r"
exp_continue
}
"MPLAB IPE (Integrated Programming Environment) \\\\\\\\\\\\[Y/n\\\\\\\\\\\\]:" {
send "\\\\r"
exp_continue
}
"Do you want to continue? \\\\\\\\\\\\[Y/n\\\\\\\\\\\\]:" {
send "\\\\r"
exp_continue
}
"Go to www.microchip.com/MPLABxc to download a compiler or assembler \\\\\\\\\\\\[Y/n\\\\\\\\\\\\]:" {
send "n\\\\r"
exp_continue
}
"Go to www.microchip.com/Harmony to simplify 32 bit project development by downloading MPLAB Harmony Integrated Software Framework and its configurator (MHC) \\\\\\\\\\\\[Y/n\\\\\\\\\\\\]:" {
send "n\\\\r"
exp_continue
}
"Leaving the boxes checked will launch a browser pointing to the urls shown so you can perform the desired action. \\\\\\\\\\\\[Y/n\\\\\\\\\\\\]:" {
send "n\\\\r"
}
}
interact
EOF
done
for f_run in /Downloads/xc32-*-full-install-linux-installer.run; do
    test -e "\${f_run}" || continue
    f_run_base="\${f_run##*/}"
    f_ver="\${f_run_base#xc32-}" && f_ver="\${f_ver%-full-install-linux-installer.run}"
    test -e "/opt/microchip/xc32/\${f_ver}" && echo "// \${f_run_base} is already installed." && continue
    echo "// \${f_run}"
    "\${f_run}" --unattendedmodeui none --mode unattended --installer-language en --prefix /opt/microchip/xc32/\${f_ver} --netservername ''
    for p_run in /Downloads/xc32-\${f_ver}*-part-support-linux-installer.run; do
        test -e "\${p_run}" || continue
        echo "// \${p_run}"
        "\${p_run}" --unattendedmodeui none --mode unattended --installer-language en --prefix /opt/microchip/xc32/\${f_ver}
    done
    if test -e /Downloads/PIC32\\ Legacy\\ Peripheral\\ Libraries\\ Linux.tar; then
        if test ! -e /vagrant/tmp/PIC32\\ Legacy\\ Peripheral\\ Libraries.run; then
            ( cd /vagrant/tmp && tar xf /Downloads/pic32\\ legacy\\ peripheral\\ libraries\\ linux.tar )
        fi
        echo "// /Downloads/pic32\\ legacy\\ peripheral\\ libraries\\ linux.tar"
        /vagrant/tmp/PIC32\\ Legacy\\ Peripheral\\ Libraries.run --unattendedmodeui none --mode unattended --installer-language en --prefix /opt/microchip/xc32/\${f_ver}
    fi
done
for f_run in /Downloads/xc16-*-full-install-linux-installer.run; do
    test -e "\${f_run}" || continue
    f_run_base="\${f_run##*/}"
    f_ver="\${f_run_base#xc16-}" && f_ver="\${f_ver%-full-install-linux-installer.run}"
    test -e "/opt/microchip/xc16/\${f_ver}" && echo "// \${f_run_base} is already installed." && continue
    echo "// \${f_run}"
    "\${f_run}" --unattendedmodeui none --mode unattended --installer-language en --prefix /opt/microchip/xc16/\${f_ver} --netservername ''
    for p_run in /Downloads/xc16-\${f_ver}*-part-support-linux-installer.run; do
        test -e "\${p_run}" || continue
        echo "// \${p_run}"
        "\${p_run}" --unattendedmodeui none --mode unattended --installer-language en --prefix /opt/microchip/xc16/\${f_ver}
    done
    if test -e /Downloads/peripheral-libraries-for-pic24-and-dspic-v2.00-linux-installer.run; then
        echo "// /Downloads/peripheral-libraries-for-pic24-and-dspic-v2.00-linux-installer.run"
        /Downloads/peripheral-libraries-for-pic24-and-dspic-v2.00-linux-installer.run --unattendedmodeui none --mode unattended --installer-language en --prefix /opt/microchip/xc16/\${f_ver}
    fi
done
for f_run in /Downloads/xc8-*-full-install-linux-installer.run; do
    test -e "\${f_run}" || continue
    f_run_base="\${f_run##*/}"
    f_ver="\${f_run_base#xc8-}" && f_ver="\${f_ver%-full-install-linux-installer.run}"
    test -e "/opt/microchip/xc8/\${f_ver}" && echo "// \${f_run_base} is already installed." && continue
    echo "// \${f_run}"
    "\${f_run}" --unattendedmodeui none --mode unattended --installer-language en --prefix /opt/microchip/xc8/\${f_ver} --netservername ''
    for p_run in /Downloads/xc8-\${f_ver}*-part-support-linux-installer.run; do
        test -e "\${p_run}" || continue
        echo "// \${p_run}"
        "\${p_run}" --unattendedmodeui none --mode unattended --installer-language en --prefix /opt/microchip/xc8/\${f_ver}
    done
    if test -e /Downloads/peripheral-libraries-for-pic18-v2.00rc3-linux-installer.run; then
        echo "// /Downloads/peripheral-libraries-for-pic18-v2.00rc3-linux-installer.run"
        /Downloads/peripheral-libraries-for-pic18-v2.00rc3-linux-installer.run --unattendedmodeui none --mode unattended --installer-language en --prefix /opt/microchip/xc8/\${f_ver}
    fi
done
for f_run in /Downloads/mplabc18-v3.47-linux-lite-installer.run; do
    f_run_base="\${f_run##*/}"
    f_ver="\${f_run_base#mplabc18-}" && f_ver="\${f_ver%-linux-lite-installer.run}"
    test -e "/opt/microchip/mplabc18/\${f_ver}" && echo "// \${f_run_base} is already installed." && continue
    echo "// \${f_run}"
    "\${f_run}" --unattendedmodeui none --mode unattended --installer-language en --prefix /opt/microchip/mplabc18/\${f_ver}
done
for f_run in /Downloads/harmony_*_linux_installer.run; do
    test -e "\${f_run}" || continue
    f_run_base="\${f_run##*/}"
    f_ver="\${f_run_base#harmony_}" && f_ver="\${f_ver%_linux_installer.run}"
    test -e "/opt/microchip/harmony/\${f_ver}" && echo "// \${f_run_base} is already installed." && continue
    echo "// \${f_run}"
    "\${f_run}" --unattendedmodeui none --mode unattended --installer-language en --prefix /opt/microchip/harmony/\${f_ver}
done
for f_run in /Downloads/mla_*_linux_installer.run; do
    test -e "\${f_run}" || continue
    f_run_base="\${f_run##*/}"
    f_ver="\${f_run_base#mla_}" && f_ver="\${f_ver%_linux_installer.run}"
    test -e "/opt/microchip/mla/\${f_ver}" && echo "// \${f_run_base} is already installed." && continue
    echo "// \${f_run}"
    "\${f_run}" --unattendedmodeui none --mode unattended --installer-language en --prefix /opt/microchip/mla/\${f_ver}
done
hwaddrs="\$( ifconfig | tr '[:upper:]' '[:lower:]' | sed -n -e 's/^.*hwaddr\\s*\\([0-9a-f][0-9a-f]\\):\\([0-9a-f][0-9a-f]\\):\\([0-9a-f][0-9a-f]\\):\\([0-9a-f][0-9a-f]\\):\\([0-9a-f][0-9a-f]\\):\\([0-9a-f][0-9a-f]\\).*\$/\\1\\2\\3\\4\\5\\6/p' )"
for f_sh in /Downloads/*-xc{8,16,32}-demo.sh; do
    test -e "\${f_sh}" || continue
    f_sh_base="\${f_sh##*/}"
    f_hwaddr="\${f_sh_base:0:12}"
    ( echo "\${hwaddrs}" | grep -q "\${f_hwaddr}" ) || continue
    echo "// \${f_sh}"
    "\${f_sh}"
done
apt install -y fdupes
fdupes -frdN /opt/microchip/xclm/license/
ls -d1 /opt/microchip/*/*
===install_mplab.sh===

test -e scripts/rebuild-plib.sh || cat >scripts/rebuild-plib.sh <<===rebuild-plib.sh===
#!/bin/bash

# vagrant ssh -- 'bash /vagrant/scripts/rebuild-plib.sh'

set -euo pipefail

rm -fr /vagrant/tmp/objects
for d_xc8 in /opt/microchip/xc8/*; do
    f_ver="\${d_xc8##*/v}"
    f_veri="\${f_ver%%.*}"
    f_verf="\${f_ver##*.}00" && f_verf="\${f_verf:0:2}"
    test \$(( \${f_veri} )) -gt 1 -o \\( \$(( \${f_veri} )) -eq 1 -a \$(( \${f_verf} )) -ge 37 \\) || continue
    f_xc8="\${d_xc8}/bin/xc8"
    test -x "\${f_xc8}" || continue
    ( "\${f_xc8}" --chip=18F14K50 --mode=pro 2>&1 || true ) | grep -q -i '(PRO Mode)' || continue
    echo "// \${d_xc8}"
    rm -fr /vagrant/tmp/objects
    for c in 18F14K50 18F25K50; do
        echo "// \${d_xc8} - \${c}"
        mkdir -p /vagrant/tmp/objects
        f="\$( echo -n "pic18-plib-htc-\${c}.lpp" | tr '[:upper:]' '[:lower:]' )"
        ( cd "\${d_xc8}/sources/pic18/plib/" && "\${f_xc8}" */*.c --chip="\${c}" --outdir=/vagrant/tmp/objects --mode=pro --double=32 --float=32 --opt=default,+asm,-asmfile,+speed,-space,-debug --addrqual=ignore -I"../../../include" -I"../../../include/plib" --pass1 )
        ( cd /vagrant/tmp/objects && "\${f_xc8}" --chip="\${c}" -o"\${f}" --output=lpp --mode=pro --double=32 --float=32 *.p1 )
        ( cd /vagrant/tmp/objects && sudo install -o ubuntu -g root -m 644 -t "\${d_xc8}/lib" "\${f}" )
        rm -fr /vagrant/tmp/objects
    done
done
===rebuild-plib.sh===

test -e scripts/build_bitClock.sh || cat >scripts/build_bitClock.sh <<===build_bitClock.sh===
#!/bin/bash

# /bin/bash ./scripts/build_bitClock.sh 2>&1 | tee build_bitClock-\$(date +%Y%m%d%H%M%S).log

set -euo pipefail

bitClockdir=/d/workspace/bitClock/picFW.0914_20161117.src
wkdir=/vagrant/tmp/bitClock

if test -e "\${bitClockdir}/.git"; then
    h=\$( cd "\${bitClockdir}" && git stash create )
    if test "\${h}" = "" ; then h='HEAD' ; fi
    echo \${h}

    ( cd \${bitClockdir} && git archive --format=tar \${h} ) | vagrant ssh -- "rm -fr \${wkdir} && mkdir -p \${wkdir} && cd \${wkdir} && tar xmf -"
else
    ( cd \${bitClockdir} && tar cf - . ) | vagrant ssh -- "rm -fr \${wkdir} && mkdir -p \${wkdir} && cd \${wkdir} && tar xmf -"
fi

vagrant ssh <<EOF
set -euo pipefail
cd \${wkdir}
cd withBIOS.X
rm -fr dist build
#export PATH="/opt/microchip/mplabx/v3.30/mplab_ide/bin:/opt/microchip/mplabx/v3.30/sys/java/jre1.8.0_65/bin:\\\${PATH}"
prjMakefilesGenerator "\\\$(pwd)"
make -f "nbproject/Makefile-boot.mk" SUBPROJECTS= clean
make -f "nbproject/Makefile-boot.mk" SUBPROJECTS= .build-conf
EOF

find tmp/bitClock/withBIOS.X/dist

===build_bitClock.sh===

test -e scripts/build_mla_cdc_basic.sh || cat >scripts/build_mla_cdc_basic.sh <<===build_mla_cdc_basic.sh===
#!/bin/bash

# /bin/bash ./scripts/build_mla_cdc_basic.sh 2>&1 | tee build_mla_cdc_basic-\$(date +%Y%m%d%H%M%S).log

set -euo pipefail

vagrant ssh -- bash <<EOF
set -euo pipefail

mount | grep -q "\\\${HOME}/workspace/microchip" || {
     mkdir -p ~/workspace/{microchip,.microchip_upper,.microchip_work}
     sudo mount -t overlay -o lowerdir=/opt/microchip,upperdir=\\\${HOME}/workspace/.microchip_upper,workdir=\\\${HOME}/workspace/.microchip_work overlay \\\${HOME}/workspace/microchip
}

prjdirX=~/workspace/microchip/mla/v2016_11_07/apps/usb/device/cdc_basic/firmware/low_pin_count_usb_development_kit_pic18f14k50.x
prjdir="\\\${prjdirX}/../.."

test \\\$(stat -c '%u' "\\\${prjdir}") -eq \\\$(id -u) || sudo chown --recursive "\\\$(id -un)" "\\\${prjdir}"
test -w "\\\${prjdir}" || sudo chmod --recursive "u+w" "\\\${prjdir}"
cd "\\\${prjdirX}"
rm -fr dist build
prjMakefilesGenerator "\\\$(pwd)"
make -f "nbproject/Makefile-LPCUSBDK_18F14K50.mk" SUBPROJECTS= clean
make -f "nbproject/Makefile-LPCUSBDK_18F14K50.mk" SUBPROJECTS= .build-conf
find dist

# sudo umount \\\${HOME}/workspace/microchip

EOF

===build_mla_cdc_basic.sh===

test -e scripts/build_harmony_cdc_msd_basic.sh || cat >scripts/build_harmony_cdc_msd_basic.sh <<===build_harmony_cdc_msd_basic.sh===
#!/bin/bash

# /bin/bash ./scripts/build_harmony_cdc_msd_basic.sh 2>&1 | tee build_harmony_cdc_msd_basic-\$(date +%Y%m%d%H%M%S).log

set -euo pipefail

vagrant ssh -- bash <<EOF
set -euo pipefail

mount | grep -q "\\\${HOME}/workspace/microchip" || {
     mkdir -p ~/workspace/{microchip,.microchip_upper,.microchip_work}
     sudo mount -t overlay -o lowerdir=/opt/microchip,upperdir=\\\${HOME}/workspace/.microchip_upper,workdir=\\\${HOME}/workspace/.microchip_work overlay \\\${HOME}/workspace/microchip
}

prjdirX=~/workspace/microchip/harmony/v2_01b/apps/usb/device/cdc_msd_basic/firmware/cdc_msd_basic.X
prjdir="\\\${prjdir}/../.."

test \\\$(stat -c '%u' "\\\${prjdir}") -eq \\\$(id -u) || sudo chown --recursive "\\\$(id -un)" "\\\${prjdir}"
test -w "\\\${prjdir}" || sudo chmod --recursive "u+w" "\\\${prjdir}"
cd "\\\${prjdirX}"
rm -fr dist build
prjMakefilesGenerator "\\\$(pwd)"
make -f "nbproject/Makefile-pic32mx_usb_sk2_int_dyn.mk" SUBPROJECTS= clean
make -f "nbproject/Makefile-pic32mx_usb_sk2_int_dyn.mk" SUBPROJECTS= .build-conf
find dist

# sudo umount \\\${HOME}/workspace/microchip

EOF

===build_harmony_cdc_msd_basic.sh===

###

vagrant up
vagrant reload
vagrant ssh -- 'sudo /bin/bash /vagrant/scripts/setup_vm.sh'
vagrant ssh -- 'ifconfig'
vagrant ssh -- 'sudo /bin/bash /vagrant/scripts/install_mplab.sh'
vagrant ssh -- 'bash /vagrant/scripts/rebuild-plib.sh'
vagrant halt
vagrant snapshot save initial

# vagrant snapshot restore initial #or# vagrant up
# DISPLAY=127.0.0.1:0.0 vagrant ssh -- mplab_ide
