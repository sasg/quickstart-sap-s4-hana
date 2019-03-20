#!/bin/bash

# ------------------------------------------------------------------
#         Global Variables
# ------------------------------------------------------------------

SCRIPT_DIR=/root/install/
CLUSTERWATCH_SCRIPT=${SCRIPT_DIR}/ClusterWatchEngine.sh
MIN_KERN="310"
OSRELEASE="/etc/redhat-release"

# ------------------------------------------------------------------
#          Choose default log file
# ------------------------------------------------------------------

if [ -z "${HANA_LOG_FILE}" ] ; then
    if [ ! -d "/root/install/" ]; then
      mkdir -p "/root/install/"
    fi
    HANA_LOG_FILE=/root/install/install.log
fi

[ -e /root/install/config.sh ] && source /root/install/config.sh
[ -e /root/install/os.sh ] && source /root/install/os.sh

while getopts ":l:" o; do
    case "${o}" in
        l)
            HANA_LOG_FILE=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done

shift $((OPTIND-1))
[[ $# -gt 0 ]] && usage;


#***BEGIN Functions***

# ------------------------------------------------------------------
#
#          Install SAP HANA prerequisites (master node)
#
# ------------------------------------------------------------------

usage() {
    cat <<EOF
    Usage: $0 [options]
        -h print usage
        -l HANA_LOG_FILE [optional]
EOF
    exit 1
}

check_kernel() {

    KERNEL=$(uname -r | cut -c 1-4 | awk -F"." '{ print $1$2 }')

    if [ "$KERNEL" -gt "$MIN_KERN" ]
    then
    	echo 1
    else
    	echo 0
    fi
}

check_rhel() {

    RHEL=$(grep -i red "$OSRELEASE" )

    if [ "$RHEL" ]
    then
    	echo 1
    else
    	echo 0
    fi
}

check_yum() {

    YRM=$(yum -y remove gcc )
    YINST=$(yum -y install gcc | grep -i complete )

    if [ "$YINST" ]
    then
    	echo 1
    else
    	echo 0
    fi
}

check_instancetype() {
	INSTANCE_TYPE=$(curl http://169.254.169.254/latest/meta-data/instance-type 2> /dev/null )
	IS_IT_X1=$(echo $INSTANCE_TYPE | grep -i x1)

	if [ "$IS_IT_X1" ]
	then
	    echo 1
	else
	    echo 0
	fi
}

preserve_hostname() {
    hostnamectl set-hostname --static $(hostname)
    echo "preserve_hostname: true" >> /etc/cloud/cloud.cfg
}

# ------------------------------------------------------------------
#          Output log to HANA_LOG_FILE
# ------------------------------------------------------------------

log() {

    echo $* 2>&1 | tee -a ${HANA_LOG_FILE}

#error check and return
}


# ------------------------------------------------------------------
#         Disable hostname reset via DHCP
# ------------------------------------------------------------------

disable_dhcp() {

    sed -i '/HOSTNAME/ c\HOSTNAME='$(hostname) /etc/sysconfig/network

#error check and return
}

# ------------------------------------------------------------------
#          Install all the pre-requisites for SAP HANA
# ------------------------------------------------------------------

start_fs() {

  if [ $(isRHEL7) == 1 ]
  then
    log "`date` Enabling Autofs and NFS for RHEL 7.x"
    systemctl enable nfs | tee -a ${HANA_LOG_FILE}
    systemctl start nfs | tee -a ${HANA_LOG_FILE}
    systemctl enable autofs | tee -a ${HANA_LOG_FILE}
    systemctl start autofs | tee -a ${HANA_LOG_FILE}
  elif [[ $(isRHEL6) == 1 ]]; then
   #statements
    log "`date` Enabling Autofs for RHEL 6.x"
    chkconfig nfs on  | tee -a ${HANA_LOG_FILE}
    service nfs restart  | tee -a ${HANA_LOG_FILE}
    chkconfig autofs on | tee -a ${HANA_LOG_FILE}
    service autofs start | tee -a ${HANA_LOG_FILE}
  fi
}

install_prereq() {

    log "## Installing HANA Prerequisites...## "

    yum -y install xfsprogs 2>&1 | tee -a ${HANA_LOG_FILE}
    yum -y install autofs 2>&1 | tee -a ${HANA_LOG_FILE}

#error check and return
}

install_prereq_rhel66() {
  log "`date` Installing packages required for RHEL 6.6"

  yum -y install xfsprogs 2>&1 | tee -a ${HANA_LOG_FILE}
  yum -y install autofs 2>&1 | tee -a ${HANA_LOG_FILE}
  yum -y install gcc
  yum -y install compat-sap-c++

}

install_prereq_rhel67() {
  log "`date` Installing packages required for RHEL 6.7"

  yum -y install xfsprogs 2>&1 | tee -a ${HANA_LOG_FILE}
  yum -y install autofs 2>&1 | tee -a ${HANA_LOG_FILE}
  yum -y install gcc | tee -a ${HANA_LOG_FILE}
  yum -y install compat-sap-c++ | tee -a ${HANA_LOG_FILE}
  yum -y install tuned-profiles-sap-hana | tee -a ${HANA_LOG_FILE}

}

install_prereq_rhel72() {
  log "`date` Installing packages required for RHEL 7.2"

  yum -y install xfsprogs 2>&1 | tee -a ${HANA_LOG_FILE}
  yum -y install autofs 2>&1 | tee -a ${HANA_LOG_FILE}
  yum -y install gcc | tee -a ${HANA_LOG_FILE}
  yum -y install compat-sap-c++ | tee -a ${HANA_LOG_FILE}

}

install_prereq_rhel73() {
  log "`date` Installing packages required for RHEL 7.3"

  yum -y install xfsprogs 2>&1 | tee -a ${HANA_LOG_FILE}
  yum -y install autofs 2>&1 | tee -a ${HANA_LOG_FILE}
  yum -y install gcc | tee -a ${HANA_LOG_FILE}
  yum -y install compat-sap-c++-5 | tee -a ${HANA_LOG_FILE}
  yum -y install compat-sap-c++-6 | tee -a ${HANA_LOG_FILE}
  yum -y install tuned-profiles-sap-hana | tee -a ${HANA_LOG_FILE}
  yum -y update glibc.x86_64 | tee -a ${HANA_LOG_FILE}
  yum -y install nvme-cli | tee -a ${HANA_LOG_FILE}

}

install_prereq_rhel74() {
  log "`date` Installing packages required for RHEL 7.4"

  yum -y install xfsprogs 2>&1 | tee -a ${HANA_LOG_FILE}
  yum -y install autofs 2>&1 | tee -a ${HANA_LOG_FILE}
  yum -y install gcc | tee -a ${HANA_LOG_FILE}
  yum -y install compat-sap-c++-5 | tee -a ${HANA_LOG_FILE}
  yum -y install compat-sap-c++-6 | tee -a ${HANA_LOG_FILE}
  yum -y install tuned-profiles-sap-hana | tee -a ${HANA_LOG_FILE}
  yum -y update glibc.x86_64 | tee -a ${HANA_LOG_FILE}
  yum -y install nvme-cli | tee -a ${HANA_LOG_FILE}

}

install_prereq_rhel75() {
  log "`date` Installing packages required for RHEL 7.4"

  yum -y install xfsprogs 2>&1 | tee -a ${HANA_LOG_FILE}
  yum -y install autofs 2>&1 | tee -a ${HANA_LOG_FILE}
  yum -y install gcc | tee -a ${HANA_LOG_FILE}
  yum -y install compat-sap-c++-5 | tee -a ${HANA_LOG_FILE}
  yum -y install compat-sap-c++-6 | tee -a ${HANA_LOG_FILE}
  yum -y install tuned-profiles-sap-hana | tee -a ${HANA_LOG_FILE}
  yum -y update glibc.x86_64 | tee -a ${HANA_LOG_FILE}
  yum -y install nvme-cli | tee -a ${HANA_LOG_FILE}

}

start_ntp() {
    # ------------------------------------------------------------------
    #          Configure and Start ntp server
    # ------------------------------------------------------------------
     log "`date` Removing default RHEL NTP server pools"
     cp /etc/ntp.conf /etc/ntp.conf.bakcup
     grep -v iburst /etc/ntp.conf.bakcup > /etc/ntp.conf
     log "`date` Adding NTP server pools"
     echo "server 0.pool.ntp.org" >> /etc/ntp.conf
     echo "server 1.pool.ntp.org" >> /etc/ntp.conf
     echo "server 2.pool.ntp.org" >> /etc/ntp.conf
     echo "server 3.pool.ntp.org" >> /etc/ntp.conf
     if [ $(isRHEL7) == 1 ]
     then
       log "`date` Configuring NTP service for RHEL 7.x"
       systemctl enable ntpd.service | tee -a ${HANA_LOG_FILE}
       systemctl start ntpd.service | tee -a ${HANA_LOG_FILE}
       systemctl restart systemd-timedated.service | tee -a ${HANA_LOG_FILE}
     elif [[ $(isRHEL6) == 1 ]]; then
      #statements
      #statements
      log "`date` Configuring NTP service for RHEL 6.x"
      chkconfig ntpd on  | tee -a ${HANA_LOG_FILE}
      service ntpd start  | tee -a ${HANA_LOG_FILE}
     fi
}

start_oss_configs() {

    #This section is from OSS #2247020 - SAP HANA DB: Recommended OS settings for RHEL

    echo "###################" >> /etc/rc.d/rc.local
    echo "#BEGIN: This section inserted by AWS SAP HANA Quickstart" >> /etc/rc.d/rc.local

    #Disable THP
    echo never > /sys/kernel/mm/transparent_hugepage/enabled
    echo "echo never > /sys/kernel/mm/transparent_hugepage/enabled" >> /etc/rc.d/rc.local

    echo 10 > /proc/sys/vm/swappiness
    echo "echo 10 > /proc/sys/vm/swappiness" >> /etc/rc.d/rc.local

    #Disable KSM
    echo 0 > /sys/kernel/mm/ksm/run
    echo "echo 0 > /sys/kernel/mm/ksm/run" >> /etc/rc.d/rc.local

    #Disable SELINUX
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
    sed -i 's/SELINUX=permissive/SELINUX=disabled/g' /etc/sysconfig/selinux

    instance_type=$(curl http://169.254.169.254/latest/meta-data/instance-type 2> /dev/null)
    case $instance_type in
      r4.8xlarge|r4.16xlarge|x1.16xlarge|x1.32xlarge|x1e.32xlarge )
          log "`date` Configuring c-state and p-state"
          cpupower frequency-set -g performance > /dev/null
          cpupower idle-set -d 6 > /dev/null; cpupower idle-set -d 5 > /dev/null
          cpupower idle-set -d 4 > /dev/null; cpupower idle-set -d 3 > /dev/null
          cpupower idle-set -d 2 > /dev/null
	        echo "cpupower frequency-set -g performance" >> /etc/init.d/boot.local
          echo "cpupower idle-set -d 6 > /dev/null; cpupower idle-set -d 5 > /dev/null" >> /etc/init.d/boot.local
     	    echo "cpupower idle-set -d 4 > /dev/null; cpupower idle-set -d 3 > /dev/null" >> /etc/init.d/boot.local
     	    echo "cpupower idle-set -d 2 > /dev/null" >> /etc/init.d/boot.local ;;
      *)
          log "`date`  Instance type doesn't allow c-state and p-state configuration" ;;
    esac

}

start_oss_configs_rhel73() {

    #This section is from OSS #2292690 - SAP HANA DB: Recommended OS settings for RHEL 7

    log "`date` - Apply saptune HANA profile"
    mkdir /etc/tuned/sap-hana
    cp /usr/lib/tuned/sap-hana/tuned.conf /etc/tuned/sap-hana/tuned.conf # OSS Note 2292690
    sed -i '/force_latency/ c\force_latency=70' /etc/tuned/sap-hana/tuned.conf # OSS Note 2292690
    tuned-adm profile sap-hana | tee -a ${HANA_LOG_FILE}
    tuned-adm active | tee -a ${HANA_LOG_FILE}

}

start_oss_configs_rhel74() {

    #This section is from OSS #2292690 - SAP HANA DB: Recommended OS settings for RHEL 7

    log "`date` - Apply saptune HANA profile"
    mkdir /etc/tuned/sap-hana
    cp /usr/lib/tuned/sap-hana/tuned.conf /etc/tuned/sap-hana/tuned.conf # OSS Note 2292690
    sed -i '/force_latency/ c\force_latency=70' /etc/tuned/sap-hana/tuned.conf # OSS Note 2292690
    tuned-adm profile sap-hana | tee -a ${HANA_LOG_FILE}
    tuned-adm active | tee -a ${HANA_LOG_FILE}

}

start_oss_configs_rhel75() {

    #This section is from OSS #2292690 - SAP HANA DB: Recommended OS settings for RHEL 7

    log "`date` - Apply saptune HANA profile"
    mkdir /etc/tuned/sap-hana
    cp /usr/lib/tuned/sap-hana/tuned.conf /etc/tuned/sap-hana/tuned.conf # OSS Note 2292690
    sed -i '/force_latency/ c\force_latency=70' /etc/tuned/sap-hana/tuned.conf # OSS Note 2292690
    tuned-adm profile sap-hana | tee -a ${HANA_LOG_FILE}
    tuned-adm active | tee -a ${HANA_LOG_FILE}

}

download_unrar() {

  log "`date` Downloading unrar from rarlab to extract HANA media"
  mkdir -p /root/install/misc
  wget http://www.rarlab.com/rar/unrar-5.0-RHEL5x64.tar.gz -O /root/install/misc/unrar-5.0-RHEL5x64.tar.gz
  (cd /root/install/misc && tar xvf /root/install/misc/unrar-5.0-RHEL5x64.tar.gz && chmod 755 /root/install/misc/unrar)

}

set_clocksource_rhel7x () {
  log "`date` Setting clocksource to TSC"
  echo "tsc" > /sys/devices/system/clocksource/*/current_clocksource
  cp /etc/default/grub /etc/default/grub.backup
  sed -i '/GRUB_CMDLINE_LINUX/ s|"| clocksource=tsc"|2' /etc/default/grub
  grub2-mkconfig -o /boot/grub2/grub.cfg | tee -a ${HANA_LOG_FILE}

}

lockversion () {
  log "`date` Executing yum versionlock to lock RHEL version"
  yum -y install yum-plugin-versionlock | tee -a ${HANA_LOG_FILE}
  yum versionlock redhat-release-server kernel kernel-headers | tee -a ${HANA_LOG_FILE}
  yum versionlock list | tee -a ${HANA_LOG_FILE}

}

#***END Functions***

# ------------------------------------------------------------------
#         Code Body section
# ------------------------------------------------------------------

#Call Functions

#Check if we are X1 instance type
X1=$(check_instancetype)

#Check the O.S. Version
KV=$(uname -r)

#Check to see if instance type is X1 and RHEL version is supported
if [ $(check_kernel) == 0 -a $(check_instancetype) == 1 -a "$MyOS" == "RHEL66SAPHVM" ]
then
    log "Calling signal-failure.sh from $0 @ `date` with INCOMPATIBLE_RHEL parameter"
    log "Instance Type = X1: $X1 and RHEL 6.6 is not supported with X1: $KV"
    /root/install/signal-failure.sh "INCOMPATIBLE_RHEL"
    touch "$SIG_FLAG_FILE"
    sleep 300
    exit 1
fi
# Check to see if RHEL 6.x is used with X1 scale out.
if [ "$MyOS" == "RHEL67SAPHVM" -a $(check_instancetype) == 1 -a $HostCount -gt 1 ]
then
    log "Calling signal-failure.sh from $0 @ `date` with INCOMPATIBLE_RHEL_SCALEOUT parameter"
    log "Instance Type = X1: $X1 and RHEL 6.7 is not supported with X1 Scaleout: $KV"
    /root/install/signal-failure.sh "INCOMPATIBLE_RHEL_SCALEOUT"
    touch "$SIG_FLAG_FILE"
    sleep 300
    exit 1
fi

#Check to see if yum repository is registered
if [ $(check_yum) == 0 ]
then
    log "Calling signal-failure.sh from $0 @ `date` with YUM parameter"
    log "Not able to access yum repository."
    /root/install/signal-failure.sh "YUM"
    touch "$SIG_FLAG_FILE"
    sleep 300
    exit 1
fi


case "$MyOS" in
  RHEL66SAPHVM )
    log "`date` Start - Executing RHEL 6.6 related pre-requisites"
    install_prereq_rhel66
    disable_dhcp
    start_oss_configs
    preserve_hostname
    start_ntp
    start_fs
    download_unrar
    lockversion
    log "`date` End - Executing RHEL 6.6 related pre-requisites" ;;
  RHEL67SAPHVM )
    log "`date` Start - Executing RHEL 6.7 related pre-requisites"
    install_prereq_rhel67
    disable_dhcp
    start_oss_configs
    preserve_hostname
    start_ntp
    start_fs
    download_unrar
    lockversion
    log "`date` End - Executing RHEL 6.7 related pre-requisites" ;;
  RHEL72SAPHVM )
    log "`date` Start - Executing RHEL 7.2 related pre-requisites"
    install_prereq_rhel72
    start_oss_configs
    preserve_hostname
    start_ntp
    start_fs
    set_clocksource_rhel7x
    download_unrar
    lockversion
    log "`date` End - Executing RHEL 7.2 related pre-requisites" ;;
  RHEL73SAPHVM )
    log "`date` Start - Executing RHEL 7.3 related pre-requisites"
    install_prereq_rhel73
    start_oss_configs_rhel73
    preserve_hostname
    start_ntp
    start_fs
    set_clocksource_rhel7x
    download_unrar
    lockversion
    log "`date` End - Executing RHEL 7.3 related pre-requisites" ;;
  RHEL74SAPHAUSHVM )
    log "`date` Start - Executing RHEL 7.4 with HA and US related pre-requisites"
    install_prereq_rhel74
    start_oss_configs_rhel74
    preserve_hostname
    start_ntp
    start_fs
    set_clocksource_rhel7x
    download_unrar
#   lockversion - Version lock not required for HA & EUS AMIs
    log "`date` End - Executing RHEL 7.4 with HA and US related pre-requisites" ;;
  RHEL75SAPHAUSHVM )
    log "`date` Start - Executing RHEL 7.5 with HA and US related pre-requisites"
    install_prereq_rhel75
    start_oss_configs_rhel75
    preserve_hostname
    start_ntp
    start_fs
    set_clocksource_rhel7x
    download_unrar
#   lockversion - Version lock not required for HA & EUS AMIs
    log "`date` End - Executing RHEL 7.5 with HA and US related pre-requisites" ;;
  RHEL75SAPHVM )
    log "`date` Start - Executing RHEL 7.5 related pre-requisites"
    install_prereq_rhel75
    start_oss_configs_rhel75
    preserve_hostname
    start_ntp
    start_fs
    set_clocksource_rhel7x
    download_unrar
    lockversion
    log "`date` End - Executing RHEL 7.5 related pre-requisites" ;;
esac
