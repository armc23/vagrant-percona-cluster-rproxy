#!/bin/bash

apt-get  update
add-apt-repository ppa:vbernat/haproxy-2.4 -y
apt-get  install -y wget gnupg2 lsb-release curl ntp keepalived -y
apt-get  install --no-install-recommends software-properties-common
apt-get  install haproxy=2.4.\* -y
wget https://repo.percona.com/apt/percona-release_latest.generic_all.deb
dpkg -i percona-release_latest.generic_all.deb
percona-release disable all
percona-release setup pxc80
percona-release enable pxc-80
apt-get  update
DEBIAN_FRONTEND=noninteractive apt-get -yq install percona-xtradb-cluster
systemctl stop mysql


cat << EOF >> /etc/mysql/mysql.conf.d/mysqld.cnf

# Template my.cnf for PXC
# Edit to your requirements.
[client]
socket=/var/run/mysqld/mysqld.sock

[mysqld]

skip-name-resolve

port=3306
bind-address=0.0.0.0

server-id=20
datadir=/var/lib/mysql
socket=/var/run/mysqld/mysqld.sock
log-error=/var/log/mysql/error.log
pid-file=/var/run/mysqld/mysqld.pid

# Binary log expiration period is 604800 seconds, which equals 7 days
binlog_expire_logs_seconds=604800

######## wsrep ###############
# Path to Galera library
wsrep_provider=/usr/lib/galera4/libgalera_smm.so

# Cluster connection URL contains IPs of nodes
#If no IP is found, this implies that a new cluster needs to be created,
#in order to do that you need to bootstrap this node

# In order for Galera to work correctly binlog format should be ROW
binlog_format=ROW

# Slave thread to use
wsrep_slave_threads=8

wsrep_log_conflicts

# This changes how InnoDB autoincrement locks are managed and is a requirement for Galera
innodb_autoinc_lock_mode=2

#If wsrep_node_name is not specified,  then system hostname will be used

#pxc_strict_mode allowed values: DISABLED,PERMISSIVE,ENFORCING,MASTER
pxc_strict_mode=ENFORCING

# SST method
wsrep_sst_method=xtrabackup-v2
wsrep_cluster_name=pxc-cluster
wsrep_node_name=node2
wsrep_node_address=192.168.10.53
wsrep_cluster_address=gcomm://192.168.10.51,192.168.10.52,192.168.10.53
pxc-encrypt-cluster-traffic=OFF

EOF

cat << EOF >> /etc/hosts
192.168.10.51 node1
192.168.10.52 node2
192.168.10.53 node3
EOF
sed -i 's/server-id=1/server-id=30/g' /etc/mysql/mysql.conf.d/mysqld.cnf
cat << EOF >> /etc/keepalived/keepalived.conf
vrrp_script chk_pxc {
        script "/usr/bin/clustercheck clustercheck admin 0"
        interval 1
}

vrrp_instance PXC {
    state MASTER
    interface eth1
    virtual_router_id 190
    priority 90
    advert_int 1
    nopreempt
    virtual_ipaddress {
        192.168.10.200
    }

    track_script {
        chk_pxc
    }

    notify /etc/keepalived/keepalivednotify.sh

}
EOF
cat << EOF >> /etc/keepalived/keepalivednotify.sh
#!/bin/bash

TYPE=$1
NAME=$2
STATE=$3

case $STATE in
        "MASTER") /usr/bin/echo "Node is in MASTER state" > /run/keepalived.state
                  exit 0
                  ;;
        "BACKUP") /usr/bin/echo "Node is in BACKUP state" > /run/keepalived.state
                  exit 0
                  ;;
        "FAULT")  /usr/bin/echo "Node is in FAULT state" > /run/keepalived.state
                  exit 0
                  ;;
        *)        /usr/bin/echo "Node is in Unknown state and  we probobly fucked up" > /run/keepalived.state
                  exit 1
                  ;;
esac
EOF


cat << EOF > /etc/haproxy/haproxy.cfg
global
        log /dev/log    local0
        log /dev/log    local1 notice
        chroot /var/lib/haproxy
        stats socket /run/haproxy/admin.sock mode 660 level admin expose-fd listeners
        stats timeout 30s
        user haproxy
        group haproxy
        daemon

        # Default SSL material locations
        ca-base /etc/ssl/certs
        crt-base /etc/ssl/private

        # See: https://ssl-config.mozilla.org/#server=haproxy&server-version=2.0.3&config=intermediate
        ssl-default-bind-ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384
        ssl-default-bind-ciphersuites TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256
        ssl-default-bind-options ssl-min-ver TLSv1.2 no-tls-tickets

defaults
        log     global
        mode    http
        option  tcplog
        option  dontlognull
        timeout connect 5000
        timeout client  50000
        timeout server  50000
        retries 3
  #      redispatch
        maxconn 2000
        errorfile 400 /etc/haproxy/errors/400.http
        errorfile 403 /etc/haproxy/errors/403.http
        errorfile 408 /etc/haproxy/errors/408.http
        errorfile 500 /etc/haproxy/errors/500.http
        errorfile 502 /etc/haproxy/errors/502.http
        errorfile 503 /etc/haproxy/errors/503.http
        errorfile 504 /etc/haproxy/errors/504.http

listen mysql-cluster
    bind 0.0.0.0:3308
    mode tcp

    balance roundrobin
   # option  httpchk
    #option mysql-check user haproxy_check
    server node1  192.168.10.51:3306  check  weight 30
    server node2  192.168.10.52:3306 check  weight 30
    server node3 192.168.10.53:3306  check weight 30
EOF

systemctl restart haproxy
systemctl restart keepalived
systemctl restart mysql