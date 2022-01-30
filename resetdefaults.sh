#! /bin/bash


if [ $(id -u) -ne 0 ]; then
  echo -e "This script must be run as root. \n"
  exit 1
fi

echo -e "\n\n  APT clean"
apt autoremove -y
apt clean -y

echo -e "\n\n RESET UUID"
rm -f /boot/adsbx-uuid

echo -e "\n\n RESET ZT"
rm -f /var/lib/zerotier-one/identity.*
rm -f /var/lib/zerotier-one/authtoken.secret

echo -e "\n RESET SSH"
rm /etc/ssh/ssh_host_*

echo -e "\n REMOVE BASH HISTORY"
rm /home/pi/.bash_history

echo -e "\n RESET WPA_SUPPLICANT CONF"
rm -f /etc/wpa_supplicant/wpa_supplicant.conf

pushd /adsbexchange/boot-configs
for file in *; do
    echo -e "\n RESET /boot/$file"
    cp --remove-destination -f -T "$file" "/boot/$file"
done
popd

echo -e "\n RESET PI PASSWORD TO DEFAULT"
echo "pi:adsb123" | chpasswd

echo -e "\n UNLOCKING UNIT UNTIL FIRST CONFIG"
touch /boot/unlock

exit 0
