#!/bin/bash

# environment variables file #properties_envDetails#
source ../sourcefile/env_variables.properties



installnifi(){
# Creating nifi, zookeeper users and thier home dir's
useradd -m nifi

# Creating group named "apache-admin" & Adding users to it
groupadd apache-admin
usermod -a -G apache-admin nifi

# Creating zookeeper dir and nifi dir
dzdo mkdir -p /opt/nifi;dzdo chown -R nifi:nifi  /opt/nifi

}

## Actual Process Starts here
if [[ ${installNIFI:=true} ]];
then
            shopt -s nocasematch;
            case ${upgradeNIFI} in
                yes)
                    echo " #### @@@@ Upgrading NIFI service based on the below parameter  #### @@@@ ";
                    echo "  #### @@@@ upgradeNIFI parameter is set to ${upgradeNIFI}  #### @@@@ ";
                    stopZKService;
                    zk_s3Download;
                    zookeeper_Upgrade;
                    startZKService;
                    success_failure_MSG;
                ;;
                no)
                    echo " #### @@@@ Installing NIFI service based on the below parameter #### @@@@ ";
                    echo " #### @@@@ upgradeNIFI parameter is set to ${upgradeNIFI} #### @@@@ ";
                    cleanup_forfreshInstall;
                    userCreation;
                    zk_s3Download;
                    fresh_installZK;
                    zk_asService;
                    createZKKeytabs;
                    startZKService;
                    success_failure_MSG;
                ;;
                *)
                    echo " Invalid option, Please choose yes/no"
            esac
fi
