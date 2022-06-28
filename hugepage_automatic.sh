#!/bin/bash

#Date:2022-06-14
#Author:Created by b
#Version:1.0
#Describe:Oracle HugePage automatic configuration optimization

TODAY=$(date +%Y%m%d)

function Back_Limit_Config(){
  cp /etc/security/limits.conf /tmp/limits.conf.${TODAY}
  echo "limits.conf file is backed up to the /TMP directory"
}

function Edit_Limit_Config(){
  local memlock=`su - oracle -c "ulimit -a | grep 'max locked memory'" | awk '{print $6}'`

  if [ ${memlock} = "unlimited" ]; then
    echo "Max Locked Memory has been changed to Unlimited and will not be changed"
  else
    echo "oracle  soft   memlock  unlimited" >> /etc/security/limits.conf
    echo "oracle  hard   memlock  unlimited" >> /etc/security/limits.conf
    echo "Max Locked Memory parameter has been changed to Unlimited"
  fi
}

function Back_Sysctl_Config(){
  cp /etc/sysctl.conf /tmp/sysctl.conf.${TODAY}
  echo "sysctl.conf file is backed up to the /TMP directory"
}

function Calculate_Hugepage(){

  # Check for the kernel version
  KERN=`uname -r | awk -F. '{ printf("%d.%d\n",$1,$2); }'`

  # Find out the HugePage size
  HPG_SZ=`grep Hugepagesize /proc/meminfo | awk '{print $2}'`
  if [ -z "$HPG_SZ" ];then
    echo "The hugepages may not be supported in the system where the script is being executed."
    exit 1
  fi

  # Initialize the counter
  NUM_PG=0

  # Cumulative number of pages required to handle the running shared memory segments
  for SEG_BYTES in `ipcs -m | cut -c44-300 | awk '{print $1}' | grep "[0-9][0-9]*"`
  do
    MIN_PG=`echo "$SEG_BYTES/($HPG_SZ*1024)" | bc -q`
    if [ $MIN_PG -gt 0 ]; then
      NUM_PG=`echo "$NUM_PG+$MIN_PG+1" | bc -q`
    fi
  done

  RES_BYTES=`echo "$NUM_PG * $HPG_SZ * 1024" | bc -q`

  if [ $RES_BYTES -lt 100000000 ]; then
    echo "Sorry! There are not enough total of shared memory segments allocated for HugePages configuration."
    exit 1
  fi

  # Configuration sysctl.conf
  if [ -z `cat /etc/sysctl.conf | grep -E -o "^vm.nr_hugepages"` ]; then
    echo "vm.nr_hugepages = $NUM_PG" >> /etc/sysctl.conf
    sysctl -p > /dev/null
    echo "Hugepage is not configured in the sysctl.conf file, and parameters have been added. parameter values : "$NUM_PG
  else
    sed -i '/^vm.nr_hugepages/d' /etc/sysctl.conf
    echo "vm.nr_hugepages = $NUM_PG" >> /etc/sysctl.conf
    sysctl -p > /dev/null
    echo "The hugepage parameter already exists in the sysctl.conf file. Replace the parameter values : "$NUM_PG
  fi

}

function main(){
  Back_Limit_Config
  Edit_Limit_Config
  Back_Sysctl_Config
  Calculate_Hugepage

}

main
