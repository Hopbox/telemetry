cd /etc/config
wget https://raw.githubusercontent.com/Hopbox/telemetry/master/hopcloud
mkdir telemetry
cd telemetry
wget https://raw.githubusercontent.com/Hopbox/telemetry/master/telemetry.sh
chmod +x telemetry.sh
echo " * * * * /etc/config/telemetry/telemetry.sh" >> /etc/crontabs/root
