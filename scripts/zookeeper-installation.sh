#!/bin/bash

#environment variables file
source ../sourcefile/env_variables.properties

# zookeeper installation check, if zookeeper is present it run process on 2181 by default
ZK_PID_EXIST=`dzdo netstat -plten | grep ${ZK_PORT} | awk '{print $9}' | awk -F / '{print $1}'`
if [[ ! -z ${ZK_PID_EXIST} ]]; then
    echo "Zookeeper is installed on this node";
    ZK_INSTALLED=true;
else
    echo "Zookeeper is not installed on this node";
    ZK_INSTALLED=false;
fi





