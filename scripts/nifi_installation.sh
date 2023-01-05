#!/bin/bash

# environment variables file #properties_envDetails#
source ../sourcefile/env_variables.properties


# The extractZK_pid function helps to check if nifi is running on this server
# Further extract the pid of the nifi process
extractNIFIpid_killNIFIpid(){
# nifi installation check, if nifi is present it run process on 2181 by default
echo "*********************Initiating extractZK_pid function*********************";
NIFI_PID_EXIST=`dzdo netstat -plten | grep ${NIFI_PORT:=9091} | awk '{print $9}' | awk -F / '{print $1}'`;
if [[ ! -z ${NIFI_PID_EXIST} ]];
 then
    echo "Zookeeper is installed on this node";
     echo " Process Id is : ${NIFI_PID_EXIST} "
    NIFI_INSTALLED=nifi_installed;
else
    echo "Zookeeper is not installed on this node";
    NIFI_INSTALLED=nifi_notinstalled;
    exit 1;
fi
echo "killing NiFi via PID";
if [[ ${NIFI_INSTALLED} = "nifi_installed"]];
    then
      # Kill the existing nifi
      dzdo kill -9 ${NIFI_PID_EXIST};
fi
echo "*********************END of extractNIFIpid_killNIFIpid function*********************";
}


# Installing nifi as service. This function********************* is copied/taken from apache nifi.sh file
nifi_asService() {
  echo "*********************Initiating zk_asService function*********************";
SVC_FILE=/etc/init.d/nifi;
dzdo rm  -f  ${SVC_FILE};
dzdo sh /opt/nifi/current_nifi/bin/nifi.sh install;
sed -i 's/^.*NIFI_HOME=.*$/NIFI_HOME=\/opt\/nifi\/current_nifi/' ${SVC_FILE} ;
dzdo chmod 755 ${SVC_FILE};
echo "*********************END of zk_asService function*********************";
}

# Copying the nifi's tar.gz file from s3 to local
nifi_s3Download(){
   echo "*********************Initiating zk_s3Download function*********************";
  # create dir if it dose not exits
  dzdo mkdir -p /opt/nifi;
  dzdo chown -R nifi:apache-admin /opt/nifi;
  aws s3 cp ${S3_DOWNLOAD_ABSPATH}/${NIFI_Download_Filename} ${BASE_NIFI_HOMEPATH:=/opt/nifi}/;
if [[ ${?} -ne 0 ]];
then
  echo -e "AWS copy Failed, Please check and make sure you have permissions to copy. \n Server/Host should able to download it from the bucket you specified without keys"
  exit 1;
fi
echo "*********************END of zk_s3Download function*********************";
}

# Upgrading the nifi to newer version
nifi_Upgrade(){
echo "*********************Initiating nifi_Upgrade function*********************";
ls -lart ${BASE_NIFI_HOMEPATH:=/opt/nifi}/${ZKDownload_Filename};
if [[ ${?} -ne 0 ]];
then
  echo -e "File not available to extract"
  exit 1;
fi


# extracting the tar.gz file
(cd /opt/nifi/; dzdo tar -xvzf ${BASE_NIFI_HOMEPATH:=/opt/nifi}/${ZKDownload_Filename};)
#`ls -lart ${BASE_NIFI_HOMEPATH:=/opt/nifi} | grep ^l | awk '{print $11}'`;

# extracting dir name from filename
ZKDownload_Dirname=`echo ${ZKDownload_Filename} | cut -d '.' -f 1-3`;

#finding the current conf
current_zkConfdir=`service nifi status 2>&1 | sed -n '2p'  | sed -n -e 's/^.*: //p' | sed s/"\/zoo.cfg"//`;

#Copy conf from the previous version to new version.
cd /opt/nifi/${ZKDownload_Dirname};
dzdo mv /opt/nifi/${ZKDownload_Dirname}/conf /opt/nifi/${ZKDownload_Dirname}bkp_conf_`date '+%m-%d-%Y'`;
dzdo cp ${current_zkConfdir} /opt/nifi/${ZKDownload_Dirname}/;
dzdo chown -R nifi:apache-admin /opt/nifi;
dzdo chmod -R 755 /opt/nifi;

#creating Symlink to currently installed nifi
unlink /opt/nifi/current_nifi;
dzdo ln -s /opt/nifi/${ZKDownload_Dirname} /opt/nifi/current_nifi;
dzdo chown -R nifi:apache-admin /opt/nifi/current_nifi;

echo "*********************END of nifi_Upgrade function*********************";
}

# Printing Success Message
success_failure_MSG(){
  echo "*********************Initiating success_failure_MSG function*********************";
  dzdo  netstat -plten | grep  2181;
  if [[ ${?} -eq 0 ]];
  then
    extractZK_pid;
  else
      echo "Zookeeper might got Upgraded/installed, but there is trouble running the process";
      echo "Verify manually and  start the process."
      exit 1;
  fi
echo "*********************END of success_failure_MSG function*********************";
}

#user/group creation
userCreation(){
echo "*********************Initiating userCreation function*********************";
  # Creating  nifi users and their home dirs
  useradd -m nifi;

  # Creating group named "apache-admin" & Adding users to it
  groupadd apache-admin;
  usermod -a -G apache-admin nifi;

  # Creating nifi dir and nifi dir
  dzdo mkdir -p /opt/nifi;dzdo chown -R nifi:apache-admin /opt/nifi;
echo "*********************END of userCreation function*********************";
}





# Installing Zookeeper on the node
fresh_installZK(){
echo "*********************Initiating fresh_installZK function*********************";
#Creating Keytab Dir
dzdo mkdir -p /etc/security/keytabs;
dzdo chmod  755 /etc/security/keytab;


# Creating Data-dir for nifi
dzdo mkdir -p /data/zk_d1/nifi;
dzdo chown -R nifi:nifi /data/zk_d1;


# Creating /var/run/nifi for nifi
dzdo mkdir -p /var/run/nifi;
dzdo chown -R nifi:apache-admin /var/run/nifi;
dzdo mkdir -p /var/log/nifi;
dzdo chown -R nifi:apache-admin /var/log/nifi;

# extracting dir name from filename
ZKDownload_Dirname=`echo ${ZKDownload_Filename} | cut -d '.' -f 1-3`;

# Extracting nifi from tar file
(cd /opt/nifi/;dzdo tar -xvzf ${BASE_NIFI_HOMEPATH:=/opt/nifi}/${ZKDownload_Filename};)

#copying conf from s3 to new path
cd /opt/nifi/;
dzdo mv /opt/nifi/${ZKDownload_Dirname}/conf /opt/nifi/${ZKDownload_Dirname}/bkpORG_conf_`date '+%m-%d-%Y_%N'`;
dzdo aws s3 cp ${S3_zkpath_working_ABSPATH}/conf /opt/nifi/${ZKDownload_Dirname}/conf/ --recursive ;
dzdo chown -R nifi:apache-admin /opt/nifi;
dzdo chmod -R 755 /opt/nifi;

# updating the files based on the server
if [[ "$HOSTNAME" = "${new_zkServer1}" ]];
  then
    echo "using grep command to find the files";
    echo "grep -ir ${old_zkserver1} /opt/nifi/${ZKDownload_Dirname}/ | wc -l";
    fntoedit=`grep -ir ${old_zkserver1} /opt/nifi/${ZKDownload_Dirname}/ | wc -l`;
    echo " Number of files to edit : ${fntoedit} ";
    nametoChange=${new_zkServer1};
    oldname=${old_zkserver1};
fi

if [[ "$HOSTNAME" = "${new_zkServer2}" ]];
  then
    echo "using grep command to find the files";
        echo "grep -ir ${old_zkserver2} /opt/nifi/${ZKDownload_Dirname}/ | wc -l";
    fntoedit=`grep -ir ${old_zkserver2} /opt/nifi/${ZKDownload_Dirname}/ | wc -l`;
    echo " Number of files to edit : ${fntoedit} ";
    nametoChange=${new_zkServer2};
    oldname=${old_zkserver2};
fi

if [[ "$HOSTNAME" = "${new_zkServer3}" ]];
  then
    echo "using grep command to find the files";
    echo "grep -ir ${old_zkserver3} /opt/nifi/${ZKDownload_Dirname}/ | wc -l";
    fntoedit=`grep -ir ${old_zkserver3} /opt/nifi/${ZKDownload_Dirname}/ | wc -l`;
    echo " Number of files to edit : ${fntoedit} ";
    nametoChange=${new_zkServer3};
    oldname=${old_zkserver3};
fi

# changing dir and running find command with sed
echo "changing dir to /opt/nifi/${ZKDownload_Dirname}/";
(cd /opt/nifi/${ZKDownload_Dirname}/;echo "current dir : `pwd`";)
echo "using grep command with xargs and sed to update string in a file";
#dzdo find /opt/nifi/${ZKDownload_Dirname}/conf/ -type f -exec sed -i "s/${oldname}/${nametoChange}/g" {} \;
dzdo grep -irl 'd010220017016.ds.dtveng.net' /opt/nifi/${ZKDownload_Dirname}/conf | xargs -I % sh -c " echo 'updating %' ; sed -i 's/${oldname}/${nametoChange}/g' %" ;


#creating Symlink to currently installed nifii
unlink /opt/nifi/current_nifi;
dzdo ln -s /opt/nifi/${ZKDownload_Dirname} /opt/nifi/current_nifi;
dzdo chown -R nifi:apache-admin /opt/nifi/current_nifi;

echo "*********************END of fresh_installZK function*********************";
}



check_awscli_Installation(){
echo "*********************Initiating check_awscli_Installation function*********************";
dzdo aws --version;
 if [[ ${?} -eq 0 ]];
  then
    echo  "*********** AWS CLI is already installed, you are good to go. ***********"
    exit 0;
 else
  echo "Please install AWS CLI First";
  exit 1;
  fi
  echo "*********************END of check_awscli_Installation function*********************";
}

# Starting Zk Service
startZKService(){
dzdo service nifi start;
}

# Stoping Zk Service
stopZKService(){
  echo "*********************Initiating stopZKService function*********************";
dzdo service nifi stop;
 if [[ ${?} -eq 0 ]];
  then
    echo "nifi is stopped";
 else
   extractNIFIpid_killNIFIpid;
 fi
 echo "*********************END of stopZKService function*********************";
}


cleanup_forfreshInstall(){
echo "*********************Initiating cleanup_forfreshInstall function*********************";
temp_cdir=bkp_zoo_`date '+%m-%d-%Y_%N'`;
dzdo mkdir -p /tmp/cleanup/${temp_cdir};
dzdo chmod -R 777 /tmp/cleanup;
dzdo mv /opt/nifi /tmp/cleanup/${temp_cdir}/;
unset temp_cdir fntoedit NIFI_PID_EXIST oldname nametoChange;

echo "*********************END of cleanup_forfreshInstall function*********************";
}

createZKKeytabs(){
  #Creating Zookeeper Keytab
  dzdo cd /opt/kerberos_Creationfiles;
  (dzdo cd /opt/kerberos_Creationfiles ; dzdo sh /opt/kerberos_Creationfiles/bias-create-svc-user.sh /etc/security/keytabs/zk.service.keytab "nifi/${HOSTNAME}@DS.DTVENG.NET";)
  (dzdo cd /opt/kerberos_Creationfiles ; dzdo sh /opt/kerberos_Creationfiles/bias-create-svc-user.sh /etc/security/keytabs/spnego.service.keytab "HTTP/${HOSTNAME}@DS.DTVENG.NET";)

# Permission for keytabs
 dzdo chmod -R 744 /etc/security/keytabs;
 dzdo chown -R  nifi:apache-admin /etc/security/keytabs/zk.service.keytab;
 dzdo chmod 740 /etc/security/keytabs/zk.service.keytab;
 dzdo ls -lart /etc/security/keytabs;
}



installnifi(){
# Creating nifi, NiFi users and thier home dir's
useradd -m nifi

# Creating group named "apache-admin" & Adding users to it
groupadd apache-admin
usermod -a -G apache-admin nifi

# Creating NiFi dir and nifi dir
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
                    stopNiFiService;
                    nifi_s3Download;
                    nifi_Upgrade;
                    startNiFiService;
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
                    createNiFiKeytabs;
                    startNiFiService;
                    success_failure_MSG;
                ;;
                *)
                    echo " Invalid option, Please choose yes/no"
            esac
fi
