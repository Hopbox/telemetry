#!/bin/sh

if [ $# -ne 2 ]
then
	echo "$0: Usage: $0 SLUG LOCATION (No space in SLUG or LOCATION strings)"
	exit 1
fi

SLUG=$1
LOCATION=$2

# Decide wheter to use curl or wget .. default is curl
CURL=`which curl`
RES=$?

if [ $RES -ne 0 ]
then
	echo "curl not found. Exiting."
	exit 1
fi

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

cat /etc/crontabs/root | grep -v telemetry.sh > /tmp/root.new
echo "* * * * * /bin/nice -n 19 /etc/config/telemetry/telemetry.sh" >> /tmp/root.new
mv /tmp/root.new /etc/crontabs/root

echo $SLUG
uci set hopcloud.credentials.slug=$SLUG
echo $LOCATION
uci set hopcloud.credentials.location=$LOCATION
uci commit hopcloud
uci show hopcloud.credentials

TUNINTERFACES=$(uci show network | grep interface | grep -v -E 'lan|self|hopcloud|loopback|route|wf' | awk -F'.' '{print $2}' | awk -F'=' '{print $1}' | grep tun)
echo "got tunnels $TUNINTERFACES"
WANINTERFACES=$(uci show network | grep interface | grep -v -E 'lan|self|hopcloud|loopback|route|tun|wf' | awk -F'.' '{print $2}' | awk -F'=' '{print $1}')
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
uci commit hopcloud
sync
