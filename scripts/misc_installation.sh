#!/bin/bash

# environment variables file #properties_envDetails#
source ../sourcefile/env_variables.properties

#installing Java
installJava(){
  # copying java jars and ca_certs.
  dzdo mkdir -p /opt/java_jars;
  dzdo chmod -R 775 /opt/java_jars;
  dzdo aws s3 cp ${s3_java_jarPath}/ /opt/java_jars/ --recursive ;
  dzdo chmod -R 775 /opt/java_jars;

  # Installing Java via local rpm using yum command
  dzdo yum localinstall /opt/java_jars/jdk-8u121-linux-x64.rpm -y;

  echo "******************************************************************";
  echo " Installed Java"
  echo "`java -version`"
  echo "******************************************************************";
}

addCACerts(){
# Coping certs to java path
dzdo cp /opt/java_jars/ca-certs_dtv/* /usr/java/jdk1.8.0_121/jre/lib/security/ ;

 #Adding CA CERTS to Keystore
cd /usr/java/jdk1.8.0_121/jre/lib/security/;
dzdo /usr/java/jdk1.8.0_121/bin/keytool -import -trustcacerts -keystore cacerts -storepass changeit  -noprompt -alias ATT_Entertainment_Technology_and_Operations_Intermediate_CA -file ATT_Entertainment_Technology_and_Operations_Intermediate_CA.cer
dzdo /usr/java/jdk1.8.0_121/bin/keytool -import -trustcacerts -keystore cacerts -storepass changeit  -noprompt -alias ATT_Mobility_and_Entertainment_Technology_and_Operations_Root_CA  -file ATT_Mobility_and_Entertainment_Technology_and_Operations_Root_CA.cer
dzdo /usr/java/jdk1.8.0_121/bin/keytool -import -trustcacerts -keystore cacerts -storepass changeit  -noprompt -alias DIRECTV_Classic_Issuing_CA -file DIRECTV_Classic_Issuing_CA.cer
dzdo /usr/java/jdk1.8.0_121/bin/keytool -import -trustcacerts -keystore cacerts -storepass changeit  -noprompt -alias DIRECTV_Engineering_DTVENG_Issuing_CA -file DIRECTV_Engineering_DTVENG_Issuing_CA.cer
dzdo /usr/java/jdk1.8.0_121/bin/keytool -import -trustcacerts -keystore cacerts -storepass changeit  -noprompt -alias DIRECTV_NextGen_Issuing_CA -file DIRECTV_NextGen_Issuing_CA.cer
dzdo /usr/java/jdk1.8.0_121/bin/keytool -import -trustcacerts -keystore cacerts -storepass changeit  -noprompt -alias DIRECTV_Operations_DTVOPS__Issuing_CA -file DIRECTV_Operations_DTVOPS__Issuing_CA.cer
dzdo /usr/java/jdk1.8.0_121/bin/keytool -import -trustcacerts -keystore cacerts -storepass changeit  -noprompt -alias DTV-Eng-Issuing-CA-01 -file DTV-Eng-Issuing-CA-01.cer
dzdo /usr/java/jdk1.8.0_121/bin/keytool -import -trustcacerts -keystore cacerts -storepass changeit  -noprompt -alias DTV-Ops-Issuing-CA-01 -file DTV-Ops-Issuing-CA-01.cer
dzdo /usr/java/jdk1.8.0_121/bin/keytool -import -trustcacerts -keystore cacerts -storepass changeit  -noprompt -alias DTV-Ops-Root-CA-01 -file DTV-Ops-Root-CA-01.cer
}

addJcepolicy(){
   # Install JCE Unlimited Strength Policy
  dzdo unzip /opt/java_jars/jce_policy-8.zip "*.jar" -d /tmp ;
  dzdo ls -l /usr/java/jdk1.8.0_121/jre/lib/security/*policy.jar ;
  # if anything exits run below command if not skip it.
  dzdo rm -f /usr/java/jdk1.8.0_121/jre/lib/security/*policy.jar ;
  dzdo chmod -R 777 /tmp/UnlimitedJCEPolicyJDK8;
  dzdo cp --preserve=timestamps /tmp/UnlimitedJCEPolicyJDK8/*policy.jar  /usr/java/jdk1.8.0_121/jre/lib/security/ ;
  dzdo chmod 644 /usr/java/jdk1.8.0_121/jre/lib/security/*policy.jar ;
  dzdo ls -l  /usr/java/jdk1.8.0_121/jre/lib/security/*policy.jar ;
}

awscliInstall(){
  dzdo mkdir -p /tmp/installation_stuff/aws_temp;
  dzdo chmod -R 777 /tmp/installation_stuff/aws_temp;
  dzdo cd /tmp/installation_stuff/aws_temp;
  dzdo curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/installation_stuff/aws_temp/awscliv2.zip" ;
  dzdo unzip /tmp/installation_stuff/aws_temp/awscliv2.zip -d /tmp/installation_stuff/aws_temp/ ;
  dzdo chmod -R 777 /tmp/installation_stuff/aws_temp;
  dzdo sh /tmp/installation_stuff/aws_temp/aws/install -i /usr/local/aws -b /usr/local/bin;
  dzdo chmod -R 775 /usr/local/aws;
  echo " **************** AWS CLI VERSION INFORMATION ****************"
  echo "`aws --version`"
  echo " **************************** END ****************************"
}

ad_kerberosfiles(){
  # making sure we have kerberos libs
  dzdo yum install krb5* -y;

  # creating necessary directories
  dzdo mkdir -p /etc/security/keytabs /opt/kerberos_Creationfiles;
  dzdo chmod -R 755 /etc/security/keytabs;
  dzdo chmod -R 755 /opt/kerberos_Creationfiles;

  #download the files from s3 to local
  dzdo cd /opt/kerberos_Creationfiles/;
  dzdo aws s3 cp ${s3_kerberos_filePath}/  /opt/kerberos_Creationfiles/ --recursive ;
  dzdo chmod -R 755 /opt/kerberos_Creationfiles/*;
  dzdo mv /opt/kerberos_Creationfiles/nifi-admin.keytab /etc/security/keytabs/;
  dzdo mv /opt/kerberos_Creationfiles/nifi.principal /etc/security/keytabs/;

  dzdo echo "${svc_accName_withRelam}" > /etc/security/keytabs/nifi.principal;
  temp_svcname=`klist -kt /etc/security/keytabs/nifi-admin.keytab | awk '{print $4}'| awk 'NF > 0'`;

   #condition check to make sure the svc account used and the keytab has correct information
   if [[ "$temp_svcname" != "$svc_accName_withRelam" ]];
    then
        echo "update the keytab in s3 location AND update it on the server";
        exit 1;
  else
      echo "Keytab looks good and you are good to run bias commands to create keytabs";
  fi
}


# Misc installation starting point
awscliInstall;
installJava;
addCACerts;
addJcepolicy;
ad_kerberosfiles;





}