#! /bin/bash

exist_netns()
{
    if [ ! $#  -eq 1 ] ; then
        echo 'invalid arguments'
        exit 1
    fi
    for ns in `ip netns`
    do 
        if [ "$ns" == "$1" ] ; then 
            return 0
        fi
    done
    return 1
}

create_netns()
{
    if [ ! $#  -eq 1 ] ; then
        echo 'invalid arguments'
        exit 1
    fi
    exist_netns $1
    if [ ! "$?" -eq 0 ] ; then
       /usr/sbin/ip netns add $1
    else
    	#delete all the links in the netns
        for iface in `/usr/sbin/ip netns exec $1 ip li |grep "^[0-9]*: "  |sed 's/^[0-9]*: \(.*:\).*/\1/g' |tr -d ':' |sed 's/@.*//g'`
        do
            /usr/sbin/ip netns exec $1 ip link delete $iface 2> /dev/null
        done
		/usr/sbin/ip netns exec $1 ip route delete default 2> /dev/null
    fi
    
}
delete_netns()
{
    if [ ! $#  -eq 1 ] ; then
        echo 'invalid arguments'
        exit 1
    fi
    exist_netns $1
    if [ "$?" -eq 0 ] ; then
        /usr/sbin/ip netns delete $1
    fi
}

create_lan()
{
	if [ ! $#  -eq 1 ] ; then
		echo 'invalid arguments'
		exit 1
	fi
	ovs-vsctl  br-exists $1
	if [ ! "$?" -eq 0 ] ; then
		ovs-vsctl add-br $1
	else 
		for iface in `ovs-vsctl  list-ports $1`
		do
			ovs-vsctl del-port $1 $iface
		done
	fi
	ip addr flush dev $1
	ip link set $1 up 	
}

delete_lan()
{
	if [ $#  -eq 1 ] ; then
		ovs-vsctl del-br $1
	fi
    
}

bind_ipaddr_to_lan()
{   #$1:lan-dev $2:ipaddr
	if [ ! $# -eq 2 ] ; then
		echo 'invalid arguments'
		exit 1
	fi
    ip addr add $2 dev $1
}
enable_snat_lan()
{
    #$1:lan-dev $2:subnet
    if [ ! $# -eq 2 ] ; then
        echo 'invalid arguments'
        exit 1
    fi
    key="snat_for_$1"
    iptables -t nat -S POSTROUTING |grep "$key " >/dev/null
    if [ ! $? -eq 0 ] ; then
        iptables -t nat -A POSTROUTING -s $2 -j MASQUERADE -m comment  --comment $key
    fi
}
disable_snat_lan()
{
    #$1:lan-dev
    if [ ! $# -eq 1 ] ; then
        echo 'invalid arguments'
        exit 1
    fi
    key="snat_for_$1"
    iptables -t nat -S POSTROUTING |grep "$key " >/dev/null
    if [ $? -eq 0 ] ; then
       $(iptables -t nat -S POSTROUTING  |grep $key  |sed 's/^-A /iptables -t nat -D /')
    fi
}

create_link()
{
    #$1:link name, $2:attached_lan, $3:attached_vswitch
    # front_eth0 & backend_eth0
    if [ ! $# -eq 3 ] ; then 
        echo 'invalid arguments'
        exit 1
    fi
    frontend_dev="frontend_$1"
    backend_dev="backend_$1"
    ip link show $frontend_dev &> /dev/null
    if [ ! $? -eq 0 ] ; then 
        ip link add name $frontend_dev type veth peer name $backend_dev
        ip link set $backend_dev up
        ovs-vsctl add-port $2 $backend_dev
        ip link set dev $frontend_dev netns $3
        ip netns exec $3 ip link set $frontend_dev up 
    fi
}
delete_link()
{
    #$1:link name
    if [ ! $# -eq 1 ] ; then
        echo 'invalid arguments'
        exit 1
    fi
    backend_dev="backend_$1"
    ovs-vsctl del-port $backend_dev &> /dev/null 
    ip link delete $backend_dev &> /dev/null 
}

bind_ipaddr_to_link()
{
    #$1:link name,$2:vswitch $3:ipaddr
    if [ ! $# -eq 3 ] ; then  
        echo 'invalid arguments'
        exit 1
    fi
    frontend_dev="frontend_$1"
    ip netns exec $2 ip addr add $3 dev $frontend_dev 
}
set_gateway()
{
    #$1:link name $2:vswitch $3: gw-addr
    if [ ! $# -eq 3 ] ; then
        echo 'invalid arguments'
        exit 1
    fi
    frontend_dev="frontend_$1"
    ip netns exec $2 ip route add default via $3 dev $frontend_dev
}
#delete_netns $1
#create_netns test1
#create_lan br-lan0
#delete_lan br-lan0
#bind_ipaddr_to_lan br-lan0 192.16.2.1/24
#bind_ipaddr_to_lan br-lan0 10.0.1.1/24
#enable_snat_lan br-lan0 192.16.2.0/24
#disable_snat_lan br-lan0 
#create_link eth0 br-lan0 test1
#bind_ipaddr_to_link eth0 test1 10.0.1.3/24
#bind_ipaddr_to_link eth0 test1 192.16.2.3/24
#set_gateway eth0 test1 192.16.2.1


 
