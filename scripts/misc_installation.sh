check_java()
{

}


#installing Java
installJava(){
  # copying java jars and certs.
  dzdo mkdir -p /opt/java_jars;
  dzdo chmod -R 775 /opt/java_jars;
  dzdo aws s3 cp s3://dtv-bigdatadl-nifi-dev-int/NiFi_Backups/java_jars/ /opt/java_jars/ --recursive ;
  dzdo chmod -R 775 /opt/java_jars;
  # Installing Java via local rpm
  dzdo yum localinstall /opt/java_jars/jdk-8u121-linux-x64.rpm -y;

}

addCACerts(){
 #download ca_certs from s3 to local
dzdo mdkir -p /opt/ca_certs;
dzdo chmod -R 775 /opt/ca_certs;
dzdo aws s3 cp ${s3_ca_certs_path}/ /opt/ca_certs/ --recursive;
dzdo chmod -R 775 /opt/ca_certs;

# Coping certs to java path
dzdo cp /opt/ca_certs/* /usr/java/jdk1.8.0_121/jre/lib/security/ ;

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

createZKKeytabs(){
  #Creating Zookeeper Keytab
  dzdo sh /opt/nifi/nifi-admin/bias-create-svc-user.sh /etc/security/keytabs/zk.service.keytab 'zookeeper/d010220017016.ds.dtveng.net@DS.DTVENG.NET'
  dzdo sh /opt/nifi/nifi-admin/bias-create-svc-user.sh /etc/security/keytabs/spnego.service.keytab 'HTTP/d010220017016.ds.dtveng.net@DS.DTVENG.NET'

# Permission for keytabs
 dzdo chmod 744 /etc/security/keytabs/*;
 dzdo chown -R  zookeeper:zookeeper /etc/security/keytabs/zk.service.keytab;
 dzdo chmod 740 /etc/security/ nkeytabs/zk.service.keytab;
 ll /etc/security/keytabs
}

awscliInstall(){
  cd /tmp/;
  dzdo mkdir -p /tmp/installation_stuff/aws_temp;
  dzdo chmod -R 777 /tmp/installation_stuff/aws_temp;
  dzdo curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip";
  dzdo cd /tmp/installation_stuff/aws_temp;
  dzdo unzip awscliv2.zip;
  dzdo chmod -R 777 /tmp/installation_stuff/aws_temp;
  dzdo /tmp/installation_stuff/aws_temp/aws/install -i /usr/local/aws -b /usr/local/bin;
  dzdo chmod -R 775 /usr/local/aws;
  echo " **************** AWS CLI VERSION INFORMATION ****************"
  echo "`aws --version`"
  echo " **************************** END ****************************"
}


# installation starting point
awscliInstall;