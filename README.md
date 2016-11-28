# vagrant_mplab/bootstrap.sh

PICマイコンの開発環境を用意するスクリプト。
VirtualBox使います。

## ホスト

* Windows

## ゲスト

* Linux

## 使ってるソフト

* Vagrant
* VirtualBox
* MSYS2
* VcXsrv

## Vagrantで使ってるプラグイン

* vagrant-vbguest

## Vagrantで使ってるBOX

* ubuntu/xenial32

## 使い方

```bash
cd workspace
mkdir -p vagrant
cd vagrant

mkdir -p Downloads
cd Downloads
curl -LO 'http://ww1.microchip.com/downloads/en/DeviceDoc/MPLABX-v3.45-linux-installer.tar'
curl -LO 'http://ww1.microchip.com/downloads/en/DeviceDoc/xc32-v1.42-full-install-linux-installer.run'
curl -LO 'http://ww1.microchip.com/downloads/en/DeviceDoc/xc32-v1.42-part-support-linux-installer.run'
curl -o 'PIC32 Legacy Peripheral Libraries Linux.tar' -L 'http://www.microchip.com/mymicrochip/filehandler.aspx?ddocname=en574264'
curl -LO 'http://ww1.microchip.com/downloads/en/DeviceDoc/xc16-v1.26-full-install-linux-installer.run'
curl -LO 'http://ww1.microchip.com/downloads/en/DeviceDoc/xc16-v1.26-part-support-linux-installer.run'
curl -o 'peripheral-libraries-for-pic24-and-dspic-v2.00-linux-installer.run' -L 'http://www.microchip.com/mymicrochip/filehandler.aspx?ddocname=en574961'
curl -LO 'http://ww1.microchip.com/downloads/en/DeviceDoc/xc8-v1.38-full-install-linux-installer.run'
curl -LO 'http://ww1.microchip.com/downloads/en/DeviceDoc/xc8-v1.38-part-support-linux-installer.run'
curl -o 'peripheral-libraries-for-pic18-v2.00rc3-linux-installer.run' -L 'http://www.microchip.com/mymicrochip/filehandler.aspx?ddocname=en574970'
curl -LO 'http://ww1.microchip.com/downloads/en/DeviceDoc/xc8-v1.34-full-install-linux-installer.run'
curl -LO 'http://ww1.microchip.com/downloads/en/DeviceDoc/xc8-v1.34-part-support-linux-installer.run'
curl -LO 'https://github.com/Manouchehri/Microchip-C18-Lite/raw/master/mplabc18-v3.47-linux-lite-installer.run'
curl -o 'harmony_v2_01b_linux_installer.run' -L 'https://www.microchip.com/mymicrochip/filehandler.aspx?ddocname=en588384'
curl -LO 'http://ww1.microchip.com/downloads/en/softwarelibrary/mla_v2016_11_07_linux_installer.run'
curl -LO 'https://github.com/bto-machida/vagrant_mplab/raw/master/checksums.md5'
md5sum --check checksums.md5
cd ..

mkdir -p mplab
cd mplab
curl -LO 'https://github.com/bto-machida/vagrant_mplab/raw/master/bootstrap.sh'
/bin/bash ./bootstrap.sh 2>&1 | tee bootstrap-$(date +%Y%m%d%H%M%S).log

vagrant up #or# vagrant snapshot restore initial

/bin/bash ./scripts/build_mla_cdc_basic.sh 2>&1 | tee build_mla_cdc_basic-$(date +%Y%m%d%H%M%S).log

/bin/bash ./scripts/build_harmony_cdc_msd_basic.sh 2>&1 | tee build_harmony_cdc_msd_basic-$(date +%Y%m%d%H%M%S).log

DISPLAY=127.0.0.1:0.0 vagrant ssh -- mplab_ide

DISPLAY=127.0.0.1:0.0 vagrant ssh -- '{
  prjdirX=~/workspace/microchip/harmony/v2_01b/apps/usb/host/cdc_basic/firmware/cdc_basic.X
  prjdir="${prjdirX}/../.."
  test $(stat -c "%u" "${prjdir}") -eq $(id -u) || sudo chown --recursive "$(id -un)" "${prjdir}"
  test -w "${prjdir}" || chmod --recursive "u+w" "${prjdir}"
  mplab_ide "${prjdirX}"
}'
```
