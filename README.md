# vagrant-percona-cluster-rproxy
Use for the purpose of education
# Ubuntu 18
This vagrant provision a 3 pxc 8.0 nodes cluster.

Vagrantfile IP's are created based on script.sh settings. You can change ip addresses from script.sh file.

# Keeplaived and Haproxy load balancer

Keeplaived is used for redundancy. In this build every nodes are checking for node sync state and for primary cluster state. When node bacome primary cluster keepalived script change the state of node to MASTER and set ip addresss on interface, that ip address will be used by haproxy for load balancing between nodes 
Once a node (or nodes) is determined to be disconnected, then the remaining nodes cast a quorum vote, and if the majority of nodes from before the disconnect are still still connected, then that partition remains up and new primary cluster will be chosen after quorum. All settings for keepalived and haproxy can be changed in script.sh file.

In next build release will be added ability for setings all necessary configuration by using variable.
