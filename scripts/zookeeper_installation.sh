#!/bin/bash

# environment variables file #properties_envDetails#
source ../sourcefile/env_variables.properties


# The extractZK_pid function helps to check if zookeeper is running on this server
# Further extract the pid of the zookeeper process
extractZKpid_killzkpid(){
# zookeeper installation check, if zookeeper is present it run process on 2181 by default
echo "*********************Initiating extractZK_pid function*********************";
ZK_PID_EXIST=`dzdo netstat -plten | grep ${ZK_PORT:=2181} | awk '{print $9}' | awk -F / '{print $1}'`;
if [[ ! -z ${ZK_PID_EXIST} ]];
 then
    echo "Zookeeper is installed on this node";
     echo " Process Id is : ${ZK_PID_EXIST} "
    ZK_INSTALLED=zk_installed;
else
    echo "Zookeeper is not installed on this node";
    ZK_INSTALLED=zk_notinstalled;
    exit 1;
fi

if [[ ${zk_installed} = "zk_installed"]];
    then
      # Kill the existing zookeeper
      dzdo kill -9 ${ZK_PID_EXIST};
fi
echo "*********************END of extractZKpid_killzkpid function*********************";
}


# Installing zookeeper as service. This function********************* is copied/taken from apache nifi.sh file
zk_asService() {
  echo "*********************Initiating zk_asService function*********************";
    SVC_NAME=zookeeper
    # since systemd seems to honour /etc/init.d we don't still create native systemd services
    # yet...
    initd_dir='/etc/init.d'
    SVC_FILE="${initd_dir}/${SVC_NAME}"
    if [ ! -w  "${initd_dir}" ]; then
        echo "Current user does not have write permissions to ${initd_dir}. Cannot install NiFi as a service."
        exit 1
    fi

#removing existing file in init.d
echo "removing existing service file form /etc/init.d";
dzdo rm  -f  ${SVC_FILE};

# Create the init script, overwriting anything currently present
dzdo cat <<SERVICEDESCRIPTOR > ${SVC_FILE}
#!/bin/sh

# description: Apache Zookeeper ZooKeeper is a centralized service for maintaining configuration information, naming, providing distributed synchronization, and providing group services.
#

# Make use of the configured ZOOKEEPER_HOME directory and pass service requests to the zkServer.sh executable
ZOOKEEPER_HOME=/opt/zookeeper/current_zookeeper
bin_dir=\${ZOOKEEPER_HOME}/bin
zookeeper_executable=\${bin_dir}/zkServer.sh

\${zookeeper_executable} "\$@"
SERVICEDESCRIPTOR
dzdo chmod 755 ${SVC_FILE};
echo "*********************END of zk_asService function*********************";
}

# Copying the zookeeper's tar.gz file from s3 to local
zk_s3Download(){
   echo "*********************Initiating zk_s3Download function*********************";
  # create dir if it dose not exits
  dzdo mkdir -p /opt/zookeeper;
  dzdo chown -R zookeeper:apache-admin /opt/zookeeper;
  aws s3 cp ${S3_DOWNLOAD_ABSPATH}/${ZKDownload_Filename} ${BASE_ZOOKEEPER_HOMEPATH:=/opt/zookeeper}/;
if [[ ${?} -ne 0 ]];
then
  echo -e "AWS copy Failed, Please check and make sure you have permissions to copy. \n Server/Host should able to download it from the bucket you specified without keys"
  exit 1;
fi
echo "*********************END of zk_s3Download function*********************";
}

# Upgrading the zookeeper to newer version
zookeeper_Upgrade(){
echo "*********************Initiating zookeeper_Upgrade function*********************";
ls -lart ${BASE_ZOOKEEPER_HOMEPATH:=/opt/zookeeper}/${ZKDownload_Filename};
if [[ ${?} -ne 0 ]];
then
  echo -e "File not available to extract"
  exit 1;
fi


# extracting the tar.gz file
echo "extracting tar file"
(cd /opt/zookeeper/; dzdo tar -xvzf ${BASE_ZOOKEEPER_HOMEPATH:=/opt/zookeeper}/${ZKDownload_Filename} > /dev/null;  if [ ${?} -eq 0 ]; then echo successfully untar the file; else echo "unsuccessful to untar the file"; fi)

# extracting dir name from filename
ZKDownload_Dirname=`echo ${ZKDownload_Filename} | cut -d '.' -f 1-3`;

#finding the current conf
current_zkConfdir=`service zookeeper status 2>&1 | sed -n '2p'  | sed -n -e 's/^.*: //p' | sed s/"\/zoo.cfg"//`;

#Copy conf from the previous version to new version.
cd /opt/zookeeper/${ZKDownload_Dirname};
dzdo mv /opt/zookeeper/${ZKDownload_Dirname}/conf /opt/zookeeper/${ZKDownload_Dirname}bkp_conf_`date '+%m-%d-%Y'`;
dzdo cp ${current_zkConfdir} /opt/zookeeper/${ZKDownload_Dirname}/;
dzdo chown -R zookeeper:apache-admin /opt/zookeeper;
dzdo chmod -R 755 /opt/zookeeper;

#creating Symlink to currently installed zookeeper
unlink /opt/zookeeper/current_zookeeper;
dzdo ln -s /opt/zookeeper/${ZKDownload_Dirname} /opt/zookeeper/current_zookeeper;
dzdo chown -R zookeeper:apache-admin /opt/zookeeper/current_zookeeper;

echo "*********************END of zookeeper_Upgrade function*********************";
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
  # Creating  zookeeper users and their home dirs
  useradd -m zookeeper;

  # Creating group named "apache-admin" & Adding users to it
  groupadd apache-admin;
  usermod -a -G apache-admin zookeeper;

  # Creating zookeeper dir and nifi dir
  dzdo mkdir -p /opt/zookeeper;dzdo chown -R zookeeper:apache-admin /opt/zookeeper;
echo "*********************END of userCreation function*********************";
}


change_zkconf(){
    echo "using for loop to update the config"
     for line in `grep -ir 'server.[0-9]=' /opt/zookeeper/current_zookeeper/conf`;
     do
        echo "${line}" ;
        fl_name_f1=`echo "${line}"  | cut -d: -f1 `;
        serv_name_f2=`echo "${line}"  | cut -d: -f2`;
        serv_name_info=`echo "${line}"  | cut -d: -f2 | cut -d= -f1`;

        case ${serv_name_info} in
        server.1)
              echo "updating ${serv_name_info} info in ${fl_name_f1}" ;
              sed -i "s/${serv_name_f2}/${serv_name_info}=${new_zkServer1}/g" ${fl_name_f1} ;
        ;;
        server.2)
              echo "updating ${serv_name_info} info in ${fl_name_f1}" ;
              sed -i "s/${serv_name_f2}/${serv_name_info}=${new_zkServer2}/g" ${fl_name_f1} ;
        ;;
        server.3)
              echo "updating ${serv_name_info} info in ${fl_name_f1}" ;
              sed -i "s/${serv_name_f2}/${serv_name_info}=${new_zkServer3}/g" ${fl_name_f1} ;
        ;;
        esac

    done ;

}


# Installing Zookeeper on the node
fresh_installZK(){
echo "*********************Initiating fresh_installZK function*********************";
#Creating Keytab Dir
dzdo mkdir -p /etc/security/keytabs;
dzdo chmod  755 /etc/security/keytab;


# Creating Data-dir for zookeeper
dzdo mkdir -p /data/zk_d1/zookeeper;
dzdo chown -R zookeeper:zookeeper /data/zk_d1;


# Creating /var/run/zookeeper for zookeeper
dzdo mkdir -p /var/run/zookeeper;
dzdo chown -R zookeeper:apache-admin /var/run/zookeeper;
dzdo mkdir -p /var/log/zookeeper;
dzdo chown -R zookeeper:apache-admin /var/log/zookeeper;

# extracting dir name from filename
ZKDownload_Dirname=`echo ${ZKDownload_Filename} | cut -d '.' -f 1-3`;

# Extracting zookeeper from tar file
(cd /opt/zookeeper/;dzdo tar -xvzf ${BASE_ZOOKEEPER_HOMEPATH:=/opt/zookeeper}/${ZKDownload_Filename};)

#copying conf from s3 to new path
cd /opt/zookeeper/;
dzdo mv /opt/zookeeper/${ZKDownload_Dirname}/conf /opt/zookeeper/${ZKDownload_Dirname}/bkpORG_conf_`date '+%m-%d-%Y_%N'`;
dzdo aws s3 cp ${S3_zkpath_working_ABSPATH}/conf /opt/zookeeper/${ZKDownload_Dirname}/conf/ --recursive ;
dzdo chown -R zookeeper:apache-admin /opt/zookeeper;
dzdo chmod -R 755 /opt/zookeeper;

## updating the files based on the server
#if [[ "$HOSTNAME" = "${new_zkServer1}" ]];
#  then
#    echo "using grep command to find the files";
#    echo "grep -ir ${old_zkserver1} /opt/zookeeper/${ZKDownload_Dirname}/ | wc -l";
#    fntoedit=`grep -ir ${old_zkserver1} /opt/zookeeper/${ZKDownload_Dirname}/ | wc -l`;
#    echo " Number of files to edit : ${fntoedit} ";
#    nametoChange=${new_zkServer1};
#    oldname=${old_zkserver1};
#fi
#
#if [[ "$HOSTNAME" = "${new_zkServer2}" ]];
#  then
#    echo "using grep command to find the files";
#        echo "grep -ir ${old_zkserver2} /opt/zookeeper/${ZKDownload_Dirname}/ | wc -l";
#    fntoedit=`grep -ir ${old_zkserver2} /opt/zookeeper/${ZKDownload_Dirname}/ | wc -l`;
#    echo " Number of files to edit : ${fntoedit} ";
#    nametoChange=${new_zkServer2};
#    oldname=${old_zkserver2};
#fi
#
#if [[ "$HOSTNAME" = "${new_zkServer3}" ]];
#  then
#    echo "using grep command to find the files";
#    echo "grep -ir ${old_zkserver3} /opt/zookeeper/${ZKDownload_Dirname}/ | wc -l";
#    fntoedit=`grep -ir ${old_zkserver3} /opt/zookeeper/${ZKDownload_Dirname}/ | wc -l`;
#    echo " Number of files to edit : ${fntoedit} ";
#    nametoChange=${new_zkServer3};
#    oldname=${old_zkserver3};
#fi

## changing dir and running find command with sed
#echo "changing dir to /opt/zookeeper/${ZKDownload_Dirname}/";
#(cd /opt/zookeeper/${ZKDownload_Dirname}/;echo "current dir : `pwd`";)
#echo "using grep command with xargs and sed to update string in a file";
##dzdo find /opt/zookeeper/${ZKDownload_Dirname}/conf/ -type f -exec sed -i "s/${oldname}/${nametoChange}/g" {} \;
#dzdo grep -irl 'd010220017016.ds.dtveng.net' /opt/zookeeper/${ZKDownload_Dirname}/conf | xargs -I % sh -c " echo 'updating %' ; sed -i 's/${oldname}/${nametoChange}/g' %" ;


#creating Symlink to currently installed zookeeperi
unlink /opt/zookeeper/current_zookeeper;
dzdo ln -s /opt/zookeeper/${ZKDownload_Dirname} /opt/zookeeper/current_zookeeper;
dzdo chown -R zookeeper:apache-admin /opt/zookeeper/current_zookeeper;

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
dzdo service zookeeper start;
}

# Stoping Zk Service
stopZKService(){
  echo "*********************Initiating stopZKService function*********************";
dzdo service zookeeper stop;
 if [[ ${?} -eq 0 ]];
  then
    echo "zookeeper is stopped";
 else
   extractZKpid_killzkpid;
 fi
 echo "*********************END of stopZKService function*********************";
}


cleanup_forfreshInstall(){
echo "*********************Initiating cleanup_forfreshInstall function*********************";
temp_cdir=bkp_zoo_`date '+%m-%d-%Y_%N'`;
dzdo mkdir -p /tmp/cleanup/${temp_cdir};
dzdo chmod -R 777 /tmp/cleanup;
dzdo mv /opt/zookeeper /tmp/cleanup/${temp_cdir}/;
unset temp_cdir fntoedit ZK_PID_EXIST oldname nametoChange;

echo "*********************END of cleanup_forfreshInstall function*********************";
}

createZKKeytabs(){
  #Creating Zookeeper Keytab
  echo "creating  zookeeper and spenigo keytabs"
  dzdo cd /opt/kerberos_Creationfiles;
  (dzdo cd /opt/kerberos_Creationfiles ; dzdo sh /opt/kerberos_Creationfiles/bias-create-svc-user.sh /etc/security/keytabs/zk.service.keytab "zookeeper/${HOSTNAME}@DS.DTVENG.NET";)
  (dzdo cd /opt/kerberos_Creationfiles ; dzdo sh /opt/kerberos_Creationfiles/bias-create-svc-user.sh /etc/security/keytabs/spnego.service.keytab "HTTP/${HOSTNAME}@DS.DTVENG.NET";)

# Permission for keytabs
 dzdo chmod -R 744 /etc/security/keytabs;
 dzdo chown -R  zookeeper:apache-admin /etc/security/keytabs/zk.service.keytab;
 dzdo chmod 740 /etc/security/keytabs/zk.service.keytab;
 dzdo ls -lart /etc/security/keytabs;
}


## Actual Process Starts here
if [[ ${installZK} ]];
then
  echo "Doing a condition check for fresh install or upgrade using case";
      shopt -s nocasematch;
      case ${upgradeZK} in
          yes)
              echo " #### @@@@ Upgrading zookeeper service based on the below parameter  #### @@@@ ";
              echo "  #### @@@@ upgradeZK parameter is set to ${upgradeZK}  #### @@@@ ";
              stopZKService;
              zk_s3Download;
              zookeeper_Upgrade;
              zk_asService;
              startZKService;
              success_failure_MSG;
          ;;
          no)
              echo " #### @@@@ Installing zookeeper service based on the below parameter #### @@@@ ";
              echo " #### @@@@ upgradeZK parameter is set to ${upgradeZK} #### @@@@ ";
              cleanup_forfreshInstall;
              userCreation;
              zk_s3Download;
              fresh_installZK;
              change_zkconf;
              zk_asService;
              createZKKeytabs;
              startZKService;
              success_failure_MSG;
          ;;
          *)
              echo " Invalid option, Please choose yes/no"
      esac
fi
