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