check_java()
{

}


#installing Java
installJava(){
  # copying java jars and certs.
  mkdir -p /opt/java_jars;
  aws s3 cp s3://dtv-bigdatadl-nifi-dev-int/NiFi_Backups/java_jars/ /opt/java_jars/ --recursive ;
  chmod -R 775 /opt/java_jars;
# Installing Java via local rpm
yum localinstall /opt/java_jars/jdk-8u121-linux-x64.rpm;

}

addCACerts(){
  #Adding CA CERTS to Keystore
  cd /usr/java/jdk1.8.0_121/jre/lib/security/;
  dzdo /usr/java/jdk1.8.0_121/bin/keytool -import -trustcacerts -keystore cacerts -storepass changeit  -noprompt -alias ATT_Entertainment_Technology_and_Operations_Intermediate_CA -file ATT_Entertainment_Technology_and_Operations_Intermediate_CA.cer;
  dzdo /usr/java/jdk1.8.0_121/bin/keytool -import -trustcacerts -keystore cacerts -storepass changeit -noprompt -alias ATT_Mobility_and_Entertainment_Technology_and_Operations_Root_CA -file  ATT_Mobility_and_Entertainment_Technology_and_Operations_Root_CA.cer;
  dzdo /usr/java/jdk1.8.0_121/bin/keytool -import -trustcacerts -keystore cacerts -storepass changeit -noprompt -alias DIRECTV_Classic_Issuing_CA -file DIRECTV_Classic_Issuing_CA.cer;
  dzdo /usr/java/jdk1.8.0_121/bin/keytool -import -trustcacerts -keystore cacerts -storepass changeit -noprompt -alias DIRECTV_Engineering_DTVENG_Issuing_CA -file DIRECTV_Engineering_DTVENG_Issuing_CA.cer;
  dzdo /usr/java/jdk1.8.0_121/bin/keytool -import -trustcacerts -keystore cacerts -storepass changeit -noprompt -alias DIRECTV_NextGen_Issuing_CA -file DIRECTV_NextGen_Issuing_CA.cer;
  dzdo /usr/java/jdk1.8.0_121/bin/keytool -import -trustcacerts -keystore cacerts -storepass changeit -noprompt -alias DIRECTV_Operations_DTVOPS__Issuing_CA -file DIRECTV_Operations_DTVOPS__Issuing_CA.cer;

}

addJcepolicy(){
   Install JCE Unlimited Strength Policy
  unzip /opt/java_jars/jce_policy-8.zip "*.jar" -d /tmp
  ll /usr/java/jdk1.8.0_121/jre/lib/security/*policy.jar
  # if anything exits run below command if not skip it.
  rm -f /usr/java/jdk1.8.0_121/jre/lib/security/*policy.jar
  cp --preserve=timestamps /tmp/UnlimitedJCEPolicyJDK8/*policy.jar  /usr/java/jdk1.8.0_121/jre/lib/security/
  chmod 644 /usr/java/jdk1.8.0_121/jre/lib/security/*policy.jar
  ll  /usr/java/jdk1.8.0_121/jre/lib/security/*policy.jar
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