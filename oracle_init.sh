#!/bin/bash

#Date:2021-01-10
#Author:Created by b
#Version:1.0
#Describe:Automatically configure the configuration required for Oracle installation

HOME="/home"
ORACLE_PASSWD="123456"
ORACLE_SID=orcl
PORT=1521
MEM_PERCENTAGE=85

function User_Create(){
  groupadd oinstall
  groupadd dba
  useradd -g oinstall -g dba -m oracle
  groups oracle > /dev/null
  echo ${ORACLE_PASSWD} | passwd --stdin oracle > /dev/null
  echo "=============== User created success ==============="
}

function Directory_Create(){

  mkdir -p ${HOME}/oracle
  mkdir -p ${HOME}/oraInventory
  mkdir -p ${HOME}/database
  chown -R oracle:oinstall ${HOME}/oracle
  chown -R oracle:oinstall ${HOME}/oraInventory
  chown -R oracle:oinstall ${HOME}/database
  echo "=============== Directory created successfully ==============="

}

function System_Version_Update(){
  echo "redhat-7" > /etc/redhat-release

}

function Port_Configure(){
  local temp_parameter=$(systemctl status firewalld | grep Active |awk '{printf($2)}')

  if [ $temp_parameter == "active" ]
    then
      firewall-cmd --permanent --zone=public --add-port=1521/tcp > /dev/null
      systemctl restart firewalld

      echo "=============== port ${PORT} configure successfully ==============="
    else
      echo "---------- Firewalld has been disabled  ----------"
  fi

}

function Selinux_Configure(){
  local temp_parameter=$(getenforce)

  if [ ${temp_parameter} == "Enforcing" ] || [ ${temp_parameter} == "Permissive" ]
    then
      setenforce 0
      sed -i 's#SELINUX=.*#SELINUX=disabled#' /etc/selinux/config
      echo "=============== selinux configure successfully ==============="
    else
      echo "---------- selinux does not require configuration ----------"
  fi

}

function Kernel_Configure(){
  local kernel_shmmax=$(cat /proc/meminfo | grep "MemTotal:" |awk -v mem=${MEM_PERCENTAGE} '{printf($2*1024/100*mem)}' |awk '{printf("%d",$0)}')
  local kernel_shmall=$(cat /proc/meminfo | grep "MemTotal:" |awk -v mem=${MEM_PERCENTAGE} '{printf($2*1024/100*mem)/4096}' |awk '{printf("%d",$0)}')


  if [ ${kernel_shmall} -le 2097152 ]; then
    kernel_shmall=2097152
  fi

  echo "net.ipv4.icmp_echo_ignore_broadcasts = 1" >> /etc/sysctl.conf
  echo "net.ipv4.conf.all.rp_filter = 1" >> /etc/sysctl.conf
  echo "fs.file-max = 6815744" >> /etc/sysctl.conf
  echo "fs.aio-max-nr = 1048576" >> /etc/sysctl.conf
  echo "kernel.shmall = ${kernel_shmall}" >> /etc/sysctl.conf
  echo "kernel.shmmax = ${kernel_shmmax}" >> /etc/sysctl.conf
  echo "kernel.shmmni = 4096" >> /etc/sysctl.conf
  echo "kernel.sem = 250 32000 100 128" >> /etc/sysctl.conf
  echo "net.ipv4.ip_local_port_range = 9000 65500" >> /etc/sysctl.conf
  echo "net.core.rmem_default = 262144" >> /etc/sysctl.conf
  echo "net.core.rmem_max= 4194304" >> /etc/sysctl.conf
  echo "net.core.wmem_default= 262144" >> /etc/sysctl.conf
  echo "net.core.wmem_max= 1048576" >> /etc/sysctl.conf

  sysctl -p > /dev/null

  echo "=============== kernel configure successfully ==============="

}

function User_Resource_Configure(){

  echo "session required /lib/security/pam_limits.so" >>/etc/pam.d/login
  echo "oracle soft nproc 2047" >> /etc/security/limits.conf
  echo "oracle hard nproc 16384" >> /etc/security/limits.conf
  echo "oracle soft nofile 1024" >> /etc/security/limits.conf
  echo "oracle hard nofile 65536" >> /etc/security/limits.conf
  
  echo 'if [ $USER = "oracle" ] || [ $USER = "grid" ] ; then' >>  /etc/profile
  echo ' if [ $SHELL = "/bin/ksh" ]; then' >> /etc/profile
  echo '  ulimit -p 16384' >> /etc/profile
  echo '  ulimit -n 65536' >> /etc/profile
  echo ' else' >> /etc/profile
  echo '  ulimit -u 16384 -n 65536' >> /etc/profile
  echo ' fi' >> /etc/profile
  echo 'fi' >> /etc/profile

  echo "=============== user resource configure successfully ==============="
}

function Oracle_Env_Configure(){

  echo "export ORACLE_BASE=${HOME}/oracle">> /home/oracle/.bash_profile
  echo "export ORACLE_HOME=${HOME}/oracle/app/oracle/product/11.2.0/dbhome_1">> /home/oracle/.bash_profile
  echo "export ORACLE_SID=${ORACLE_SID}">> /home/oracle/.bash_profile
  echo "export ORACLE_TERM=xterm">> /home/oracle/.bash_profile
  echo "export PATH=\$ORACLE_HOME/bin:/usr/sbin:\$PATH">> /home/oracle/.bash_profile
  echo "export LD_LIBRARY_PATH=\$ORACLE_HOME/lib:/lib:/usr/lib">> /home/oracle/.bash_profile
  echo "export LANG=C">> /home/oracle/.bash_profile
  echo "export NLS_LANG=AMERICAN_AMERICA.ZHS16GBK">> /home/oracle/.bash_profile
  source /home/oracle/.bash_profile

  echo "=============== configure oracle environment successfully ==============="

}

function main(){
  if [ "$(grep -o "^oracle" /etc/passwd)" = oracle ]
    then
      echo "User already exists ! "
    else
      User_Create
      Directory_Create
      System_Version_Update
      Port_Configure
      Selinux_Configure
      Kernel_Configure
      User_Resource_Configure
      Oracle_Env_Configure
      echo "After the initial configuration is complete, install Oracle dependencies"  
  fi

}

main
