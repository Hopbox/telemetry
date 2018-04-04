cd /etc/config
rm hopcloud
wget https://raw.githubusercontent.com/Hopbox/telemetry/master/hopcloud
mkdir /etc/config/telemetry
cd /etc/config/telemetry
rm telemetry.sh
wget https://raw.githubusercontent.com/Hopbox/telemetry/master/telemetry.sh
chmod +x telemetry.sh
echo "* * * * * /etc/config/telemetry/telemetry.sh" >> /etc/crontabs/root
