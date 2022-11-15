#!/bin/bash

# zookeeper installation check
ZK_PID=netstat -plten | grep 2181 | awk '{print $9}' | awk -F / '{print $1}'
if [ ! -z $zk_exist ]; then
    echo "Zookeeper is installed on this node";
    ZK_INSTALLED=true;
else
    echo "Zookeeper is not installed on this node";
    ZK_INSTALLED=false;
fi