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
     echo " Process Id is : ${ZK_PID_EXIST} "
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
zk_asService() {
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

# description: Apache Zookeeper ZooKeeper is a centralized service for maintaining configuration information, naming, providing distributed synchronization, and providing group services.
#

# Make use of the configured ZOOKEEPER_HOME directory and pass service requests to the zkServer.sh executable
ZOOKEEPER_HOME=/opt/zookeeper/current_zookeeper
bin_dir=${ZOOKEEPER_HOME}/bin
zookeeper_executable=${bin_dir}/zkServer.sh

${zookeeper_executable} "$@"
SERVICEDESCRIPTOR
}

# Copying the zookeeper's tar.gz file from s3 to local
zk_s3Download(){
  # create dir if it dose not exits
  dzdo mkdir -p /opt/zookeeper;
  dzdo chown -R zookeeper:apache-admin /opt/zookeeper;
  aws s3 cp ${S3_DOWNLOAD_ABSPATH}/${ZKDownload_Filename} ${BASE_ZOOKEEPER_HOMEPATH:=/opt/zookeeper}/;
if [[ ${?} -ne 0 ]];
then
  echo -e "AWS copy Failed, Please check and make sure you have permissions to copy. \n Server/Host should able to download it from the bucket you specified without keys"
  exit 1;
fi
}

# Upgrading the zookeeper to newer version
zookeeper_Upgrade(){
ls -lart ${BASE_ZOOKEEPER_HOMEPATH:=/opt/zookeeper}/${ZKDownload_Filename}
if [[ ${?} -ne 0 ]];
then
  echo -e "File not available to extract"
  exit 1;
fi


# extracting the tar.gz file
cd /opt/zookeeper/;
tar -xvzf ${BASE_ZOOKEEPER_HOMEPATH:=/opt/zookeeper}/${ZKDownload_Filename};
#`ls -lart ${BASE_ZOOKEEPER_HOMEPATH:=/opt/zookeeper} | grep ^l | awk '{print $11}'`;

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
dzdo ln -s "/opt/zookeeper/${ZKDownload_Dirname}" "/opt/zookeeper/current_zookeeper";
dzdo chown -R zookeeper:apache-admin /opt/zookeeper/current_zookeeper;

}

# Printing Success Message
success_failure_MSG(){
  dzdo  netstat -plten | grep  2181
  if [[ ${?} -eq 0 ]];
  then
    extractZK_pid;
  else
      echo "Zookeeper might got Upgraded/installed, but there is trouble running the process";
      echo "Verify manually and  start the process."
      exit 1;
  fi

}

#user/group creation
userCreation(){

  # Creating  zookeeper users and their home dirs
  useradd -m zookeeper;

  # Creating group named "apache-admin" & Adding users to it
  groupadd apache-admin;
  usermod -a -G apache-admin zookeeper;

  # Creating zookeeper dir and nifi dir
  dzdo mkdir -p /opt/zookeeper;dzdo chown -R zookeeper:apache-admin /opt/zookeeper;

}





# Installing Zookeeper on the node
fresh_installZK(){

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

# Extracting zookeeper from tar file
cd /opt/zookeeper/;
tar -xvzf ${BASE_ZOOKEEPER_HOMEPATH:=/opt/zookeeper}/${ZKDownload_Filename};

#copying conf from s3 to new path
cd /opt/zookeeper/;
dzdo mv /opt/zookeeper/${ZKDownload_Dirname}/conf /opt/zookeeper/${ZKDownload_Dirname}/bkpORG_conf_`date '+%m-%d-%Y'`;
dzdo aws s3 cp ${S3_zkpath_working_ABSPATH}/conf /opt/zookeeper/${ZKDownload_Dirname}/ ;
dzdo chown -R zookeeper:apache-admin /opt/zookeeper;
dzdo chmod -R 755 /opt/zookeeper;

# updating the files based on the server
if [[ "$HOSTNAME" = "${new_zkServer1}" ]];
  then
    fntoedit=`grep -ir ${new_zkServer1} /opt/zookeeper/${ZKDownload_Dirname}/ | wc -l`;
    echo " Number of files to edit : ${fntoedit} ";
    nametoChange=${new_zkServer1};
    oldname=${old_zkserver1};
fi

if [[ "$HOSTNAME" = "${new_zkServer2}" ]];
  then
    fntoedit=`grep -ir ${new_zkServer2} /opt/zookeeper/${ZKDownload_Dirname}/ | wc -l`;
    echo " Number of files to edit : ${fntoedit} ";
    nametoChange=${new_zkServer2};
    oldname=${old_zkserver2};
fi

if [[ "$HOSTNAME" = "${new_zkServer3}" ]];
  then
    fntoedit=`grep -ir ${new_zkServer3} /opt/zookeeper/${ZKDownload_Dirname}/ | wc -l`;
    echo " Number of files to edit : ${fntoedit} ";
    nametoChange=${new_zkServer3};
    oldname=${old_zkserver3};
fi

cd /opt/zookeeper/${ZKDownload_Dirname}/;
dzdo find /tmp/test -type f -exec sed -i "s/${oldname}/${nametoChange}/g" {} \;


}



check_awscli_Installation(){
aws --version;
 if [[ ${?} -eq 0 ]];
  then
    echo  "*********** AWS CLI is already installed, you are good to go. ***********"
    exit 0;
 else
  mkdir -p /tmp/aws_cli_install;cd /tmp/aws_cli_install;
  yum zk_asService python3 -y;
  temp_Python_version=`python3 -V | awk '{print $2}' | cut -d "." -f  1,2`;
  update-alternatives --install /usr/bin/python python /usr/bin/python${temp_Python_version} 1 ;
  curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip";
  unzip /tmp/aws_cli_install/awscli-bundle.zip
  dzdo ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws

  fi
}

startZKService(){
dzdo service zookeeper start;
}



## Actual Process Starts here
if [[ ${upgradeZK} ]];
then
  extractZK_pid;
  killZookeeper;
  zk_s3Download;
  zookeeper_Upgrade;
  startZKService;
  success_failure_MSG;
else
   userCreation;
   zk_s3Download;
   fresh_installZK;
   zk_asService;
   startZKService;
   success_failure_MSG;
fi
