#!/bin/sh
#####################################################################
# (C) Unmukti Technology Pvt Ltd
# support@hopbox.in
#
# This is a free software which comes with absolutely no warranty.
# Please use at your own risk.
#
# License: GNU General Public License - GPL v3.0 or later
####################################################################

# Include network.sh lib

. /lib/functions/network.sh

#

date="$( date +%s )000000000"
#deviceid,location=$location=`uci show system | grep hostname | cut -d "=" -f 2 | sed -e "s/'//g"`
deviceid=`uci get system.@system[0].hostname`

server=`uci get hopcloud.statistics.telemetry_host`
port=`uci get hopcloud.statistics.telemetry_port`
slug=`uci get hopcloud.credentials.slug`
location=`uci get hopcloud.credentials.location`
POST_CMD="curl -k -i -XPOST https://$server:$port/write?db=$slug"

## CPU
#cpu=`cat /proc/stat | head -n1 | sed 's/cpu //'`
cpu=`top -b -n 1 | grep CPU | grep irq | sed 's/%//g'`
user=`echo $cpu | awk '{print $2}'`
nice=`echo $cpu | awk '{print $6}'`
system=`echo $cpu | awk '{print $4}'`
idle=`echo $cpu | awk '{print $8}'`
iowait=`echo $cpu | awk '{print $10}'`
irq=`echo $cpu | awk '{print $12}'`
softirq=`echo $cpu | awk '{print $14}'`
$POST_CMD --data-binary "cpu,host=$deviceid,location=$location user=$user,nice=$nice,system=$system,idle=$idle,iowait=$iowait,irq=$irq,softirq=$softirq $date"

## Memory
mem=`cat /proc/meminfo`
total=`echo "$mem" | grep ^MemTotal | awk '{print $2}'`
free=`echo "$mem" | grep ^MemFree | awk '{print $2}'`
$POST_CMD --data-binary "memory,host=$deviceid,location=$location total=$total,free=$free $date"

## Disk
# Checkif overlayfs else report root usage
total=`df -k | grep -E 'overlayfs|/root' | tail -1 | awk '{print $2}'`
used=`df -k | grep -E 'overlayfs|/root' | tail -1 | awk '{print $5}' | sed -e 's/%//'`
$POST_CMD --data-binary "disk,host=$deviceid,location=$location total=$total,used=$used $date"

## Load
load=`cat /proc/loadavg`
load1=`echo "$load" | awk '{print $1}'`
load5=`echo "$load" | awk '{print $2}'`
load15=`echo "$load" | awk '{print $3}'`
proc_run=`echo "$load" | awk '{print $4}' | awk -F '/' '{print $1}'`
proc_total=`echo "$load" | awk '{print $4}' | awk -F '/' '{print $2}'`
$POST_CMD --data-binary "load,host=$deviceid,location=$location load1=$load1,load5=$load5,load15=$load15,proc_run=$proc_run,proc_total=$proc_total $date"

## Check WAN Status
for i in `uci get hopcloud.statistics.wan`
do
#        int=`uci get network.$i.ifname`
	sIP=`network_get_ipaddr ip $i;echo $ip`
        ping_destination=`uci get hopcloud.destination.$i`
        if [ "$sIP" == "" ]
        then
                continue
        fi
        ping=`ping -W 5 -I $sIP -c3 $ping_destination`
        res=$?
        status=0
        if [ "$res" == 0 ]
        then
                status=1
        fi
        $POST_CMD --data-binary "wanstatus,host=$deviceid,location=$location,interface=$i status=$status $date"
	done

## Check WAN Bandwidth 
for i in `uci get hopcloud.statistics.wan`
do
	int=`uci get network.$i.ifname`
	net=$i
	echo $int, $net
	rx=0
	tx=0
	rx=`cat /sys/class/net/$int/statistics/rx_bytes`
	res=$?
	if [ "$res" -ne 0 ] 
	then 
		continue
	fi
	tx=`cat /sys/class/net/$int/statistics/tx_bytes`
	$POST_CMD --data-binary "wanbw,host=$deviceid,location=$location,interface=$net rx=$rx,tx=$tx $date"
done

## Check OpenVPN Bandwidth
for i in `uci get hopcloud.statistics.ovpn`
do
	rx=0
	tx=0
	rx=`cat /sys/class/net/$i/statistics/rx_bytes`
	res=$?
	if [ "$res" -ne 0 ]
	then
		continue
	fi
	tx=`cat /sys/class/net/$i/statistics/tx_bytes`
	$POST_CMD --data-binary "ovpnbw,host=$deviceid,location=$location,interface=$i rx=$rx,tx=$tx $date"
done

## Get Wireless data

# Wireless bandwidth & Station counts
for i in `iwinfo  | grep ESSID | sed -e 's/ESSID: //' | awk '{print $1}'`
do
	int=$i
	ssid=`iw $i info | grep ssid | sed -e 's/.*ssid //'`
	if [ "$ssid" = "" ];then
		ssid="unknown"
	fi

	echo "WBW,ASSOC: $ssid, $int"

	tx=0
	rx=0
	assoc=0
	
	tx=`cat /sys/class/net/$int/statistics/tx_bytes`
	res=$?
        if [ "$res" -ne 0 ]
        then
                continue
        fi
	rx=`cat /sys/class/net/$int/statistics/rx_bytes`
	assoc=`iw $int station dump | grep Station | wc -l`

	$POST_CMD --data-binary "wbw,host=$deviceid,location=$location,interface=$int,ssid=$ssid rx=$rx,tx=$tx $date"
	$POST_CMD --data-binary "wireless,host=$deviceid,location=$location,interface=$int,ssid=$ssid count=$assoc $date"

done

## Number of Connections
connections=`cat /proc/net/nf_conntrack`
tcp=`/usr/sbin/conntrack -L -p tcp | wc -l`
udp=`/usr/sbin/conntrack -L -p udp | wc -l`
icmp=`/usr/sbin/conntrack -L -p icmp | wc -l`
total=`/usr/sbin/conntrack -C`
$POST_CMD --data-binary "connections,host=$deviceid,location=$location tcp=$tcp,udp=$udp,icmp=$icmp,total=$total $date"

## OpenVPN tunnel status
for i in `uci show openvpn | grep status | cut -d "=" -f2 | sed -e "s/'//g"`
do
	devq=`uci show openvpn | grep $i | cut -d "=" -f 1 | sed -e 's/status/dev/'`
	tun=`uci get $devq`
	count=`grep -v '^[0-9]' $i | grep -v -E 'Common|ROUTING|GLOBAL|CLIENT|Updated|bcast|END' | wc -l`
	$POST_CMD --data-binary "ovpntunnelscount,host=$deviceid,location=$location,tunnel=$tun count=$count $date"
done

## Latency & Packet loss

for i in `uci get hopcloud.statistics.wan`
do
#	interface=`uci get network.$i.ifname`
	sIP=`network_get_ipaddr ip $i;echo $ip`
	ping_destination=`uci get hopcloud.destination.$i`

	if [ "$sIP" == "" ]
	then
		continue
	fi
	pingResult=`ping -W 5 -I $sIP -c 10 $ping_destination | tail -2`
	packet=`echo "$pingResult" |grep "packet loss" | cut -d "," -f 3 | cut -d " " -f 2| sed 's/.$//'`
	latency=`echo "$pingResult" |grep -E 'rtt|round-trip' | cut -d "=" -f 2 | cut -d "/" -f 2`
	$POST_CMD --data-binary "ping,host=$deviceid,location=$location,interface=$i,destination=$ping_destination packetloss=$packet,latency=$latency $date"
done

