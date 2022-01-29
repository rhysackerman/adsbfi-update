#!/bin/bash
set -e
trap 'echo "[ERROR] Error in line $LINENO when executing: $BASH_COMMAND"' ERR

if [[ "$(id -u)" != "0" ]]; then
    exec sudo bash "$BASH_SOURCE"
fi


restartIfEnabled() {
    # check if enabled
    if systemctl is-enabled "$1" &>/dev/null; then
            systemctl restart "$1"
    fi
}

function aptInstall() {
    if ! apt install -y --no-install-recommends --no-install-suggests "$@"; then
        apt update
        apt install -y --no-install-recommends --no-install-suggests "$@"
    fi
}

packages="git make gcc libusb-1.0-0-dev librtlsdr-dev libncurses5-dev zlib1g-dev python3-dev python3-venv"
aptInstall $packages

echo '########################################'
echo 'FULL LOG ........'
echo 'located at /tmp/adsbx_update_log .......'
echo '########################################'
echo '..'
echo 'cloning to decoder /tmp .......'
cd /tmp
rm -f -R /tmp/readsb
git clone --quiet --depth 1 https://github.com/adsbxchange/readsb.git > /tmp/adsbx_update_log

echo 'compiling readsb (this can take a while) .......'
cd readsb
#make -j3 AIRCRAFT_HASH_BITS=12 RTLSDR=yes
make -j3 AIRCRAFT_HASH_BITS=12 RTLSDR=yes OPTIMIZE="-mcpu=arm1176jzf-s -mfpu=vfp"  >> /tmp/adsbx_update_log


echo 'copying new readsb binaries ......'
cp -f readsb /usr/bin/adsbxfeeder
cp -f readsb /usr/bin/adsbx-978
cp -f readsb /usr/bin/readsb
cp -f viewadsb /usr/bin/viewadsb


echo 'make sure unprivileged users exist (readsb / adsbexchange) ......'
USER=adsbexchange
if ! id -u "${USER}" &>/dev/null
then
    adduser --system --home "/usr/local/share/$USER" --no-create-home --quiet "$USER"
fi

RUNAS=readsb
if ! getent passwd "$RUNAS" >/dev/null
then
    adduser --system --home /usr/share/"$RUNAS" --no-create-home --quiet "$RUNAS"
fi
# plugdev required for bladeRF USB access
adduser "$RUNAS" plugdev
# dialout required for Mode-S Beast and GNS5894 ttyAMA0 access
adduser "$RUNAS" dialout

echo 'restarting services .......'
restartIfEnabled readsb
restartIfEnabled adsbexchange-feed
restartIfEnabled adsbexchange-978

echo 'cleaning up decoder .......'
cd /tmp
rm -f -R /tmp/readsb

echo 'updating adsbx stats .......'
wget --quiet -O /tmp/axstats.sh https://raw.githubusercontent.com/adsbxchange/adsbexchange-stats/master/stats.sh >> /tmp/adsbx_update_log
{ bash /tmp/axstats.sh; } >> /tmp/adsbx_update_log 2>&1

echo 'cleaming up stats /tmp .......'
rm -f /tmp/axstats.sh
rm -f -R /tmp/adsbexchange-stats-git

echo 'cloning to python virtual environment for mlat-client .......'
VENV=/usr/local/share/adsbexchange/venv/
if [[ -f /usr/local/share/adsbexchange/venv/bin/python3.7 ]] && command -v python3.9 &>/dev/null;
then
    rm -rf "$VENV"
fi
/usr/bin/python3 -m venv "$VENV"

echo 'cloning to mlat-client /tmp .......'
cd /tmp
rm -f -R /tmp/mlat-client
git clone --quiet --depth 1 --single-branch https://github.com/adsbxchange/mlat-client.git >> /tmp/adsbx_update_log

echo 'building and installing mlat-client to virtual-environment .......'
cd mlat-client
source /usr/local/share/adsbexchange/venv/bin/activate >> /tmp/adsbx_update_log
python3 setup.py build >> /tmp/adsbx_update_log
python3 setup.py install >> /tmp/adsbx_update_log

echo 'starting services .......'
restartIfEnabled adsbexchange-mlat

echo 'cleaning up mlat-client .......'
cd /tmp
rm -f -R /tmp/mlat-client
rm -f /usr/local/share/adsbexchange/venv/bin/fa-mlat-client

echo 'update uat ...'

cd /tmp
rm -f -R /tmp/uat2esnt
git clone https://github.com/adsbxchange/uat2esnt.git >> /tmp/adsbx_update_log
cd uat2esnt
make uat2esnt >> /tmp/adsbx_update_log
cp -T -f uat2esnt /usr/local/bin/uat2esnt
cd /tmp
rm -f -R /tmp/uat2esnt

echo 'restart uat services .......'
restartIfEnabled adsbexchange-978-convert

echo 'update tar1090 ...........'
bash -c "$(wget -nv -O - https://raw.githubusercontent.com/wiedehopf/tar1090/master/install.sh)"  >> /tmp/adsbx_update_log


# the following doesn't apply for chroot
if ischroot; then
    exit 0
fi

echo "#####################################"
cat /boot/adsbx-uuid
echo "#####################################"
sed -e 's$^$https://www.adsbexchange.com/api/feeders/?feed=$' /boot/adsbx-uuid
echo "#####################################"

echo '--------------------------------------------'
echo '--------------------------------------------'
echo '             UPDATE COMPLETE'
echo '      FULL LOG:  /tmp/adsbx_update_log'
echo '--------------------------------------------'
echo '--------------------------------------------'


