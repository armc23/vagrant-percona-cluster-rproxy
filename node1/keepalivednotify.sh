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
