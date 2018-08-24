#!/bin/sh
# Store the arguments in variables
SLUG=$(uci get hopcloud.credentials.slug) # $1
LOCATION=$(uci get hopcloud.credentials.location) # $2

# Decide wheter to use curl or wget .. default is curl

# Get the latest hopcloud version
if [ -e "/etc/config/hopcloud" ]
then
        mv /etc/config/hopcloud /etc/config/hopcloud.bak
fi
cd /etc/config
curl -k -O https://raw.githubusercontent.com/Hopbox/telemetry/master/hopcloud

if [ -d "/etc/config/telemetry" ]
then
        rm -r /etc/config/telemetry
fi
mkdir /etc/config/telemetry
cd /etc/config/telemetry
curl -k -O https://raw.githubusercontent.com/Hopbox/telemetry/master/telemetry.sh
chmod +x telemetry.sh

echo "* * * * * /etc/config/telemetry/telemetry.sh" >> /etc/crontabs/root
sort /etc/crontabs/root  | uniq >> /etc/crontabs/root.new
mv /etc/crontabs/root.new /etc/crontabs/root

echo $SLUG
uci set hopcloud.credentials.slug=$SLUG
echo $LOCATION
uci set hopcloud.credentials.location=$LOCATION
uci commit
uci show hopcloud.credentials

TUNINTERFACES=$(uci show network | grep interface | grep -v lan | grep -v self | grep -v hopcloud | grep -v loopback | awk -F'.' '{print $2}' | awk -F'=' '{print $1}' | grep tun)
echo "got tunnels $TUNINTERFACES"
WANINTERFACES=$(uci show network | grep interface | grep -v lan | grep -v self | grep -v hopcloud | grep -v loopback | awk -F'.' '{print $2}' | awk -F'=' '{print $1}' | grep -v tun)
echo "get wanlink $WANINTERFACES"

echo "delete existing interfaces"
uci delete hopcloud.statistics.wan
for waninterface in $WANINTERFACES
do
    echo $waninterface
    uci add_list hopcloud.statistics.wan=$waninterface
done

uci delete hopcloud.statistics.ovpn
for tuninterface in $TUNINTERFACES
do
    echo $tuninterface
    uci add_list hopcloud.statistics.ovpn=$tuninterface
done
uci commit
sync
