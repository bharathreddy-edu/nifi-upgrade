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
      if [[ ${upgradeZK} ]];
      then
          echo " #### @@@@ Upgrading zookeeper service based on the below parameter  #### @@@@ ";
          echo "  #### @@@@ ZK_UPDATE parameter is set to ${ZK_UPDATE}  #### @@@@ ";
          stopZKService;
          zk_s3Download;
          zookeeper_Upgrade;
          startZKService;
          success_failure_MSG;
      else
          echo " #### @@@@ Installing zookeeper service based on the below parameter #### @@@@ ";
          echo " #### @@@@ ZK_UPDATE parameter is set to ${ZK_UPDATE} #### @@@@ ";
          cleanup_forfreshInstall;
          userCreation;
          zk_s3Download;
          fresh_installZK;
          zk_asService;
          createZKKeytabs;
          startZKService;
          success_failure_MSG;
      fi
fi
