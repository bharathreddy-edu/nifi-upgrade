#!/bin/bash

# environment variables file
source ../sourcefile/env_variables.properties

# The extractZK_pid function helps to check if zookeeper is running on this server
# Further extract the pid of the zookeeper process
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


# This killZookeeper function is to kill zookeeper id if that didn't work we are use the
# service command to stop
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


# Installing zookeeper as service. This function is copied/taken from apache nifi.sh file
install() {
    SVC_NAME=zookeeper
    # since systemd seems to honour /etc/init.d we don't still create native systemd services
    # yet...
    initd_dir='/etc/init.d'
    SVC_FILE="${initd_dir}/${SVC_NAME}"
    if [ ! -w  "${initd_dir}" ]; then
        echo "Current user does not have write permissions to ${initd_dir}. Cannot install NiFi as a service."
        exit 1
    fi

# Create the init script, overwriting anything currently present
cat <<SERVICEDESCRIPTOR > ${SVC_FILE}
#!/bin/sh

#
# description: Apache ZooKeeper is a centralized service for maintaining configuration information, naming, providing distributed synchronization, and providing group service .

# Make use of the configured ZOOKEEPER_HOME directory and pass service requests to the zkServer.sh executable
ZOOKEEPER_HOME=/opt/zookeeper/current_zookeeper
bin_dir=\${ZOOKEEPER_HOME}/bin
zookeeper_executable=\${bin_dir}/zkServer.sh

\${zookeeper_executable} "\$@"
SERVICEDESCRIPTOR
}

# Copying the zookeeper's tar.gz file from s3 to local
s3Download(){
aws s3 cp ${S3_DOWNLOAD_ABSPATH}/${ZKDownload_Filename}} ${BASE_ZOOKEEPER_HOMEPATH:=/opt/zookeeper}/
if [[ ${?} -ne 0 ]];
then
  echo -e "AWS copy Failed, Please check and make sure you have permissions to copy. \n Server/Host should able to download it from the bucket you specified without keys"
fi
}

# Upgrading the zookeeper to newer version
zookeeper_Upgrade(){


}


## Actual Process Starts here
extractZK_pid;
killZookeeper;
s3Download;
zookeeper_Upgrade;
if [[ ${?} -eq 0 ]];
then
  echo  "*********** Zookeeper Upgrade done successfully and service is started"
fi


