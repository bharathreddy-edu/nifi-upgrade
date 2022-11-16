#!/bin/bash

# environment variables file
source ../sourcefile/env_variables.properties

# Condition to check if zookeeper update is required or not
if [[ ${ZK_UPDATE} ]]

extractZK_pid(){
# zookeeper installation check, if zookeeper is present it run process on 2181 by default
ZK_PID_EXIST=`dzdo netstat -plten | grep ${ZK_PORT:=2181} | awk '{print $9}' | awk -F / '{print $1}'`
if [[ ! -z ${ZK_PID_EXIST} ]];
 then
    echo "Zookeeper is installed on this node";
    ZK_INSTALLED=true;
else
    echo "Zookeeper is not installed on this node";
    ZK_INSTALLED=false;
    exit 1;
fi
}

killZookeeper(){
# perform  steps to make sure  zookeeper is stopped
if [[ ${ZK_INSTALLED} ]];
    then
      # Kill the existing zookeeper
      dzdo kill -9 ${ZK_PID_EXIST};
    elif [[ ${?} -ne 0 ]];
    then
    service zookeeper stop;
fi
}





