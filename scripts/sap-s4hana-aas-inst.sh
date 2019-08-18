#!/bin/bash -x

###Global Variables###
source /root/install/config.sh
TZ_LOCAL_FILE="/etc/localtime"
NTP_CONF_FILE="/etc/ntp.conf"
OS_VER="/etc/os-release"
USR_SAP="/usr/sap"
SAPMNT="/sapmnt"
USR_SAP_VOLUME="/dev/xvdb"
SWAP_DEVICE="/dev/xvdc"
FSTAB_FILE="/etc/fstab"
DHCP="/etc/sysconfig/network/dhcp"
CLOUD_CFG="/etc/cloud/cloud.cfg"
IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4/)
HOSTS_FILE="/etc/hosts"
HOSTNAME_FILE="/etc/HOSTNAME"
INSTANCE_TYPE=$(curl http://169.254.169.254/latest/meta-data/instance-type 2> /dev/null)
NETCONFIG="/etc/sysconfig/network/config"
ETC_SVCS="/etc/services"
SERVICES_FILE="/sapmnt/SWPM/services"
AUTO_MASTER="/etc/auto.master"
AUTO_DIRECT="/etc/auto.direct"
PRODUCT="NW_DI:S4HANA1809.CORE.HDB.PD"
DB_PRODUCT="NW_ABAP_DB:S4HANA1809.CORE.HDB.ABAP"
SW_TARGET="/sapmnt/SWPM"
SRC_INI_DIR="/root/install"
SAPINST="/sapmnt/SWPM/sapinst"
REGION=$(curl http://169.254.169.254/latest/dynamic/instance-identity/document/ | grep -i region | awk '{ print $3 }' | sed 's/"//g' | sed 's/,//g')
MASTER_HOSTS="/sapmnt/SWPM/master_etc_hosts"
HOSTNAME=$(hostname)

ASCS_INI_FILE="/sapmnt/SWPM/s4-ascs.params"
PAS_INI_FILE="/sapmnt/SWPM/s4-pas.params"
DB_INI_FILE="/sapmnt/SWPM/s4-db.params"
AAS_INI_FILE="/sapmnt/SWPM/s4-aas.params"

_TEMP_NAME=$(echo $NAME | cut -c1-3)
#Do not quote the TEMP_NAME variable...doing so will preseve the "\"...which we don't want
#USE a last random number
RAND=$(expr $RANDOM % 100)
TEMP_NAME=$_TEMP_NAME\temp"$RAND"
TEMP_NAME_NR=$_TEMP_NAME\temp
NUMBER_COUNT=2

set_tz() {
#set correct timezone per CF parameter input
        rm "$TZ_LOCAL_FILE"
        case "$TZ_INPUT_PARAM" in
        PT)
                TZ_ZONE_FILE="/usr/share/zoneinfo/US/Pacific"
                ;;
        CT)
                TZ_ZONE_FILE="/usr/share/zoneinfo/US/Central"
                ;;
        ET)
                TZ_ZONE_FILE="/usr/share/zoneinfo/US/Eastern"
                ;;
        *)
                TZ_ZONE_FILE="/usr/share/zoneinfo/UTC"
                ;;
        esac

        ln -s "$TZ_ZONE_FILE" "$TZ_LOCAL_FILE"

        #validate correct timezone
        CURRENT_TZ=$(date +%Z | cut -c 1,3)
        if [ "$CURRENT_TZ" == "$TZ_INPUT_PARAM" -o "$CURRENT_TZ" == "UC" ]
        then
                echo 0
        else
                echo 1
        fi
}

set_oss_configs() {
    #This     #This section is from OSS #2205917 - SAP HANA DB: Recommended OS settings for SLES 12 / SLES for SAP Applications 12
    #and OSS #2292711 - SAP HANA DB: Recommended OS settings for SLES 12 SP1 / SLES for SAP Applications 12 SP1 
    
    # Disable THP
    echo never > /sys/kernel/mm/transparent_hugepage/enabled
    echo "echo never > /sys/kernel/mm/transparent_hugepage/enabled" >> /etc/init.d/boot.local
    
    echo 10 > /proc/sys/vm/swappiness
    echo "echo 10 > /proc/sys/vm/swappiness" >> /etc/init.d/boot.local
    # Disable KSM
    echo 0 > /sys/kernel/mm/ksm/run
    echo "echo 0 > /sys/kernel/mm/ksm/run" >> /etc/init.d/boot.local
    # Disable SELINUX
    sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
    sed -i 's/SELINUX=permissive/SELINUX=disabled/g' /etc/sysconfig/selinux
    
    if grep -i suse ${OS_VER} 1> /dev/null
    then
        # Install and configure SLES 
        zypper -n remove ulimit > /dev/null
        echo "###################" >> /etc/init.d/boot.local
        echo "#BEGIN: This section inserted by AWS SAP Quickstart" >> /etc/init.d/boot.local
        #Disable AutoNUMA
        echo 0 > /proc/sys/kernel/numa_balancing
        echo "echo 0 > /proc/sys/kernel/numa_balancing" >> /etc/init.d/boot.local
        zypper -n install gcc > /dev/null
        zypper -n install libgcc_s1 libstdc++6 > /dev/null
        echo "#END: This section inserted by AWS SAP HANA Quickstart" >> /etc/init.d/boot.local
        echo "###################" >> /etc/init.d/boot.local
        # Install GCC and GC++ compilers. GCC includes package libatomic1 that is required for all GCC 7 compiled apps, see OSS note 2593824. 
        zypper -n install gcc-c++ > /dev/null
        zypper -n install systemd > /dev/null
        zypper -n install nvme-cli > /dev/null

        if grep -i sap ${OS_VER} 1> /dev/null
        then
            # "Optional" - installing GNOME Desktop Environment
            zypper -n install -t pattern x11 gnome_basic > /dev/null 
            # --- OSS Note 1275776 -----------------
            zypper -n install saptune > /dev/null
            saptune daemon start
            saptune solution apply HANA
            saptune solution apply S4HANA-APPSERVER
            # --------------------------------------
        else
            # --- OSS Note 1275776 -----------------
            zypper -n install sapconf > /dev/null
            systemctl start sapconf.service > /dev/null
        fi
        # ---- Specifics for SLES15 ----
        if grep 15 ${OS_VER} 1> /dev/null
        then 
            zypper -n install unrar_wrapper > /dev/null
            zypper -n install net-tools-deprecated > /dev/null
        fi
     
        # Update all installed packages to the latest version
        zypper -n update --auto-agree-with-licenses
    else
        # RHEL package install and configuration
        # --------------------------------------------
        yum -y install vhostmd > /dev/null
        yum -y install vm-dump-metrics > /dev/null
        yum -y install glibc > /dev/null
        yum -y install gcc > /dev/null
        yum -y install gcc-c++ > /dev/null
        yum -y install compat-sap-c++ > /dev/null
        yum -y install nvme-cli > /dev/null
        yum -y update > /dev/null
    fi
}

set_awsdataprovider() {
#install the AWS dataprovider require for AWS support

	cd /tmp
    aws s3 cp s3://aws-data-provider/bin/aws-agent_install.sh . > /dev/null

	if [ -f /tmp/aws-agent_install.sh ]
	then
		bash /tmp/aws-agent_install.sh > /dev/null
		echo 0
	else
		echo 1
	fi
}

set_aasinifile() {
    #set the password from the SSM parameter store
    sed -i  "/NW_GetMasterPassword.masterPwd/ c\NW_GetMasterPassword.masterPwd = ${MP}" $AAS_INI_FILE
    sed -i  "/storageBasedCopy.hdb.systemPassword/ c\storageBasedCopy.hdb.systemPassword = ${MP}" $AAS_INI_FILE
    sed -i  "/storageBasedCopy.abapSchemaPassword/ c\storageBasedCopy.abapSchemaPassword = ${MP}" $AAS_INI_FILE
    sed -i  "/HDB_Schema_Check_Dialogs.schemaPassword/ c\HDB_Schema_Check_Dialogs.schemaPassword = ${MP}" $AAS_INI_FILE
    sed -i  "/NW_HDB_getDBInfo.systemDbPassword/ c\NW_HDB_getDBInfo.systemDbPassword = ${MP}" $AAS_INI_FILE
    sed -i  "/nwUsers.sidadmPassword/ c\nwUsers.sidadmPassword = ${MP}" $AAS_INI_FILE
    sed -i  "/hostAgent.sapAdmPassword/ c\hostAgent.sapAdmPassword = ${MP}" $AAS_INI_FILE

    #set the profile directory
    sed -i  "/NW_readProfileDir.profileDir/ c\NW_readProfileDir.profileDir = /sapmnt/${SAP_SID}/profile" $AAS_INI_FILE
     
    #set the SID and Schema
    sed -i  "/HDB_Schema_Check_Dialogs.schemaName/ c\HDB_Schema_Check_Dialogs.schemaName = ${SAP_SCHEMA_NAME}" $AAS_INI_FILE

    #set the UID and GID
    sed -i  "/nwUsers.sidAdmUID/ c\nwUsers.sidAdmUID = ${SIDadmUID}" $AAS_INI_FILE
    sed -i  "/nwUsers.sapsysGID/ c\nwUsers.sapsysGID = ${SAPsysGID}" $AAS_INI_FILE

    sed -i  "/archives.downloadBasket/ c\archives.downloadBasket = ${SW_TARGET}/s4-1809" $AAS_INI_FILE
    sed -i  "/NW_getFQDN.FQDN/ c\NW_getFQDN.FQDN = ${HOSTED_ZONE}" $AAS_INI_FILE
    sed -i  "/NW_CI_Instance.ciVirtualHostname/ c\NW_CI_Instance.ciVirtualHostname = ${HOSTNAME}" $AAS_INI_FILE
    sed -i  "/NW_CI_Instance.ascsVirtualHostname/ c\NW_CI_Instance.ascsVirtualHostname = ${HOSTNAME}" $AAS_INI_FILE
    sed -i  "/storageBasedCopy.hdb.instanceNumber/ c\storageBasedCopy.hdb.instanceNumber = ${SAPInstanceNum}" $AAS_INI_FILE  
    sed -i  "/NW_AS.instanceNumber/ c\NW_AS.instanceNumber = ${SAPInstanceNum}" $AAS_INI_FILE
    sed -i  "/NW_DI_Instance.virtualHostname/ c\NW_DI_Instance.virtualHostname = ${HOSTNAME}" $AAS_INI_FILE

    _VAL_MP=$(grep "$MP" $AAS_INI_FILE)
	_VAL_SAP_SID=$(grep "$SAP_SID" $AAS_INI_FILE)

	if [ -n "$_VAL_MP" -a "$_VAL_SAP_SID" ]
	then
		echo 0
	else
		echo 1
	fi
}

set_cleanup_aasinifile() {
#clean up the INI file after finishing the SAP install

MP="DELETED"
	sed -i  "/hdb.create.dbacockpit.user/ c\hdb.create.dbacockpit.user = true" $AAS_INI_FILE
	#set the password from the SSM parameter store
	sed -i  "/NW_GetMasterPassword.masterPwd/ c\NW_GetMasterPassword.masterPwd = ${MP}" $AAS_INI_FILE
    sed -i  "/storageBasedCopy.hdb.systemPassword/ c\storageBasedCopy.hdb.systemPassword = ${MP}" $AAS_INI_FILE
    sed -i  "/storageBasedCopy.abapSchemaPassword/ c\storageBasedCopy.abapSchemaPassword = ${MP}" $AAS_INI_FILE
    sed -i  "/HDB_Schema_Check_Dialogs.schemaPassword/ c\HDB_Schema_Check_Dialogs.schemaPassword = ${MP}" $AAS_INI_FILE
    sed -i  "/NW_HDB_getDBInfo.systemDbPassword/ c\NW_HDB_getDBInfo.systemDbPassword = ${MP}" $AAS_INI_FILE
    sed -i  "/nwUsers.sidadmPassword/ c\nwUsers.sidadmPassword = ${MP}" $AAS_INI_FILE
    sed -i  "/hostAgent.sapAdmPassword/ c\hostAgent.sapAdmPassword = ${MP}" $AAS_INI_FILE
}

Implement_Chrony()
{
    if grep -i suse ${OS_VER} 1> /dev/null
    then
        zypper -n remove 'ntp*' 1>/dev/null
        zypper -n install chrony 1>/dev/null
    else
        yum -y erase 'ntp*' 1>/dev/null
        yum -y install chrony 1>/dev/null
    fi
    echo "server 169.254.169.123 prefer iburst minpoll 4 maxpoll 4" >> /etc/chrony.conf
    ps -ef | grep '[c]hronyd' && service chronyd stop
    service chronyd start 1>/dev/null
    chronyc sources -v | grep '169.254.169.123' && return 0 || return 1
}

#set_ntp() {
#set ntp in the /etc/ntp.conf file
#	cp "$NTP_CONF_FILE" "$NTP_CONF_FILE.bak"
#	echo "server 0.pool.ntp.org" >> "$NTP_CONF_FILE"
#	echo "server 1.pool.ntp.org" >> "$NTP_CONF_FILE"
#	echo "server 2.pool.ntp.org" >> "$NTP_CONF_FILE"
#	echo "server 3.pool.ntp.org" >> "$NTP_CONF_FILE"
#	systemctl start ntpd
#	echo "systemctl start ntpd" >> /etc/init.d/boot.local
#	_COUNT_NTP=$(grep ntp "$NTP_CONF_FILE" | wc -l)
#	if [ "$_COUNT_NTP" -ge 4 ]
#	then
#		echo 0
#	else
#		echo 1
#	fi
#}

set_install_jq () {
#install jq s/w

	cd /tmp
	wget https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64
    mv jq-linux64 jq
    chmod 755 jq
}

set_filesystems() {
#create /usr/sap filesystem, swap space and mount /sapmnt
    if [ ${INSTANCE_TYPE:1:1} == 5 ]
    then
#        for devf in `ls /dev/nvme?n? | grep -v $(df | grep boot | head -c12)`
        for devf in `ls /dev/nvme?n?`
        do
            if nvme id-ctrl -v ${devf} | grep xvdb
            then
                USR_SAP_VOLUME=${devf}
            elif nvme id-ctrl -v ${devf} | grep xvdc
              then
                  SWAP_DEVICE=${devf}
            fi
        done
    fi
    if [ -z "$USR_SAP_VOLUME" -o -z "$SWAP_DEVICE" ]
	then
		echo "Exiting, can not create /usr/sap or SWAP EBS volumes"
        #signal the waithandler, 1=Failed
        /root/install/signalFinalStatus.sh 1 "Exiting, can not create /usr/sap or SWAP EBS volumes"
        set_cleanup_aasinifile
		exit 1
	else
		mkdir $USR_SAP > /dev/null 2>&1
		mkfs.xfs $USR_SAP_VOLUME -L USR-SAP> /dev/null
		echo "/dev/disk/by-label/USR-SAP  $USR_SAP xfs nobarrier,noatime,nodiratime,logbsize=256k 0 0" >> $FSTAB_FILE 2>&1
		mkswap -L SWAP $SWAP_DEVICE > /dev/null 2>&1
		swapon $SWAP_DEVICE > /dev/null 2>&1
		echo "/dev/disk/by-label/SWAP	swap swap defaults 0 0" >> $FSTAB_FILE 2>&1
        cnt=1
        while ! df | grep /usr/sap 2>/dev/null
        do
            mount $USR_SAP > /dev/null 2>&1
            [[ cnt -lt 6 ]] && { (( cnt++ )) && sleep 15; } || break
        done
	fi
}

set_dhcp() {
    if grep -i rhel ${OS_VER} 1> /dev/null
    then
        sed -i '/HOSTNAME/ c\HOSTNAME='$(hostname) /etc/sysconfig/network
        echo 0
    else
	    sed -i '/DHCLIENT_SET_HOSTNAME/ c\DHCLIENT_SET_HOSTNAME="no"' $DHCP
	    service network restart
	    _DHCP=$(grep DHCLIENT_SET_HOSTNAME $DHCP | grep no)
	    if [ -n "$_DHCP" ]
	    then
		    echo 0
	    else
		    echo 1
	    fi
    fi
}

set_hostname() {
#set and preserve the hostname
	hostname $HOSTNAME
	#update /etc/hosts file
	echo "$IP  $HOSTNAME" >> $HOSTS_FILE
	echo "$DBIP  $DBHOSTNAME" >> $HOSTS_FILE
	#save our HOSTNAME to the master_etc_hosts file as well
	echo "$IP  $HOSTNAME  #PAS Server#" >> $MASTER_HOSTS
	echo "$HOSTNAME" > $HOSTNAME_FILE
	sed -i '/preserve_hostname/ c\preserve_hostname: true' $CLOUD_CFG
	#disable dhcp
	_DISABLE_DHCP=$(set_dhcp)
	#validate hostname and dhcp
	if [ "$(hostname)" == "$HOSTNAME" -a "$_DISABLE_DHCP" == 0 ]
	then
        echo 0
	else
		echo 1
	fi
}

set_DB_hostname() {

	#add DB hostname
	echo "$DBIP  $DBHOSTNAME" >> $HOSTS_FILE

	#add own hostname
	MY_IP=$( ip a | grep inet | grep eth0 | awk -F"/" '{ print $1 }' | awk '{ print $2 }')
	echo "${MY_IP}"    "${HOSTNAME}" >> /etc/hosts  
}


set_net() {
#set and preserve the hostname
    if grep -i suse ${OS_VER} 1> /dev/null
    then
   	    #update DNS search order with our DNS Domain name
	    sed -i "/NETCONFIG_DNS_STATIC_SEARCHLIST=""/ c\NETCONFIG_DNS_STATIC_SEARCHLIST="${HOSTED_ZONE}"" $NETCONFIG
   	    #update the /etc/resolv.conf file
	    netconfig update -f > /dev/null
    else
        echo "search ${HOSTED_ZONE}" >> /etc/resolv.conf
        hostnamectl set-hostname -–static ${HOSTNAME}
    fi
	sed -i '/preserve_hostname/ c\preserve_hostname: true' $CLOUD_CFG

	#disable dhcp
	_DISABLE_DHCP=$(set_dhcp)

	if [ "$HOSTNAME" == $(hostname) ]
	then
		echo 0
	else
		echo 1
	fi
}

set_services_file() {
#update the /etc/services file with customer supplied values

	cat "$SERVICES_FILE" >> $ETC_SVCS
}

set_sapmnt() {
#setup /sapmnt from the ASCS or from EFS
	mkdir  $SAPMNT > /dev/null
    mkdir $SW > /dev/null
    #Check if EFS is in use, if EFS is in use then we mount up from the EFS share
	if [ "$EFS" == "Yes" ]
	then
		#mount up EFS
        echo "Mounting up EFS from this EFS location: "
        #construct the EFS DNS name
        EFS_MP=""$EFS_MT".efs."$REGION".amazonaws.com:/ "
        echo ""$EFS_MP"  "$SAPMNT"  nfs nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport 0 0"  >> $FSTAB_FILE
     
        #try to mount /sapmnt 3 times 
        mount /sapmnt > /dev/null
        sleep 5

       #validate /sapmnt filesystems were created and mounted
        FS_SAPMNT=$(df -h | grep "$SAPMNT" | awk '{ print $NF }')

        if [ -z "$FS_SAPMNT" ]
        then

            mount /sapmnt > /dev/null
            sleep 15
        fi

       #validate /sapmnt filesystems were created and mounted
        FS_SAPMNT=$(df -h | grep "$SAPMNT" | awk '{ print $NF }')

        if [ -z "$FS_SAPMNT" ]
        then

            mount /sapmnt  > /dev/null
            sleep 60
        fi

    else
        if [ "$DistributedInstall" == "Yes" ]
        then 
            #If EFS is *no*, we mount the /sapmnt filesystem from the ASCS server (Distributed Install) or PAS Server (non-Distributed Install).
            #Supporting a single-AZ /sapmnt scenario is for intra-AZ fail-over scenarios.
            #Mount /sapmnt from the ASCS server
            echo ""$ASCS_NAME:$SAPMNT"  "$SAPMNT"  nfs rw,soft,bg,timeo=3,intr 0 0"  >> $FSTAB_FILE
            #try to mount /sapmnt 3 times 
            mount /sapmnt > /dev/null
            sleep 5

            #validate /sapmnt filesystems were created and mounted
            FS_SAPMNT=$(df -h | grep "$SAPMNT" | awk '{ print $NF }')
            if [ -z "$FS_SAPMNT" ]
            then
                mount /sapmnt > /dev/null
                sleep 15
            fi
            #validate /sapmnt filesystems were created and mounted
            FS_SAPMNT=$(df -h | grep "$SAPMNT" | awk '{ print $NF }')
            if [ -z "$FS_SAPMNT" ]
            then
                mount /sapmnt > /dev/null
                sleep 60
            fi
            #validate /sapmnt filesystems were created and mounted
            FS_SAPMNT=$(df -h | grep "$SAPMNT" | awk '{ print $NF }')
            if [ -z "$FS_SAPMNT" ]
            then
	            #we did not successfully created the filesystems and mount points	
	            echo 1
            else
	            #we did successfully created the filesystems and mount points
                echo 0
            fi
        else
            #Mount /sapmnt from the PAS server
            echo ""$SAP_PAS:$SAPMNT"  "$SAPMNT"  nfs rw,soft,bg,timeo=3,intr 0 0"  >> $FSTAB_FILE
            #try to mount /sapmnt 3 times 
            mount /sapmnt > /dev/null
            sleep 5
            #validate /sapmnt filesystems were created and mounted
            FS_SAPMNT=$(df -h | grep "$SAPMNT" | awk '{ print $NF }')
            if [ -z "$FS_SAPMNT" ]
            then
                mount /sapmnt > /dev/null
                sleep 15
            fi

            #validate /sapmnt filesystems were created and mounted
            FS_SAPMNT=$(df -h | grep "$SAPMNT" | awk '{ print $NF }')

            if [ -z "$FS_SAPMNT" ]
            then
                mount /sapmnt > /dev/null
                sleep 60
            fi

            #validate /sapmnt filesystems were created and mounted
            FS_SAPMNT=$(df -h | grep "$SAPMNT" | awk '{ print $NF }')

            if [ -z "$FS_SAPMNT" ]
            then
	            #we did not successfully created the filesystems and mount points	
	            echo 1
            else
	            #we did successfully created the filesystems and mount points
                echo 0
            fi
        fi
    fi
}


set_uuidd() {
#Install the uuidd daemon per SAP Note 1391070
    if grep -i suse ${OS_VER} 1>/dev/null
    then
        zypper -n install uuidd > /dev/null
    else
        yum -y install uuidd > /dev/null
    fi
	systemctl enable uuidd
    systemctl start uuidd
    _UUIDD_RUNNING=$(ps -ef | grep uuidd | grep -v grep)
	if [ -n "$_UUIDD_RUNNING" ]
	then
		echo 0
	else
		echo 1
	fi
}

set_update_cli() {
#update the aws cli
#	zypper -n install python-pip > /dev/null 2>&1
#	pip install --upgrade --user awscli > /dev/null 2>&1
    curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "/tmp/awscli-bundle.zip" 1> /dev/null
    unzip /tmp/awscli-bundle.zip -d /tmp 1> /dev/null
    /tmp/awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws 1> /dev/null
	_AWS_CLI=$(aws --version 2>&1)
	if [ -n "$_AWS_CLI" ]
	then
		echo 0
	else
		echo 1
	fi
}

set_ini_file () {
#set the correct SAP PARAMS file based on SAP App Server name

   cd "$SRC_INI_DIR" 
   cp s4-aas.params  "$SW_TARGET"


    if [ ! -e "$AAS_INI_FILE" ]
	then
		#No template files - exit
		FNAME=$(echo $AAS_INI_FILE | awk -F"/" '{ print $4 }')
                #signal failure and do not proceed
                set_cleanup_aasinifile
                #signal the waithandler, 1=Failure
                /root/install/signalFinalStatus.sh 1 "There is no AAS_INI_FILE for silent SAP Install - Failure"
		        echo 1
                exit 1
	fi

    cp $AAS_INI_FILE $AAS_INI_FILE.$HOSTNAME

	sed -i  "/NW_DI_Instance.virtualHostname/ c\NW_DI_Instance.virtualHostname = ${HOSTNAME}" $AAS_INI_FILE.$HOSTNAME

	echo "$AAS_INI_FILE.$HOSTNAME" > /tmp/AAS_INI_FILE

	SID=$(grep -i "NW_GetSidNoProfiles.sid" "$SW_TARGET"/s4-ascs.params | awk '{ print $NF }' | tr '[A-Z]' '[a-z]')
	SIDADM=$(echo $SID\adm)
	echo $SIDADM > /tmp/SIDADM

	if [ -n "$SIDADM" ]
	then
		echo 0
	else
		echo 1
	fi
}


set_install_ssm() {
	cd /tmp
	wget https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm > /dev/null 2>&1
	rpm -ivh /tmp/amazon-ssm-agent.rpm > /dev/null 2>&1
	echo '#!/usr/bin/sh' > /etc/init.d/ssm
	echo "service amazon-ssm-agent start" >> /etc/init.d/ssm
	chmod 755 /etc/init.d/ssm
    systemctl enable amazon-ssm-agent
    systemctl start amazon-ssm-agent
	_SSM_RUNNING=$(ps -ef | grep ssm | grep -v grep)

	if [ -n "$_SSM_RUNNING" ]
	then
		echo 0
	else
		echo 1
	fi
}



set_configSAPWP() {
#configure the SAP workprocesses per the CF input parameter
#D = Optimize for Dialog processes, B = Optimize for Batch processes

	cd /sapmnt/"$SAP_SID"/profile 
	LOCHOST=$(hostname)
	SAP_PROF=$(ls *$LOCHOST)

	if [[ "$SAPWP" == "D" ]]
	then
		sed -i  "/wp_no_dia =/ c\rdisp\/wp_no_dia = 60" $SAP_PROF
		sed -i  "/wp_no_btc =/ c\rdisp\/wp_no_btc = 1" $SAP_PROF
	elif [[ "$SAPWP" == "B" ]]
	then
		sed -i  "/wp_no_dia =/ c\rdisp\/wp_no_dia = 1" $SAP_PROF
		sed -i  "/wp_no_btc =/ c\rdisp\/wp_no_btc = 60" $SAP_PROF
	else
		#Do nothing default config
		echo
	fi
}

set_SUSE_BYOS() {

#Check to see if BYOS SLES registration is successful

    if [[ "$MyOS" =~ BYOS ]];
    then
        SUSEConnect -r "$SLESBYOSRegCode" > /dev/null
        sleep 5
        CheckSLESRegistration=$(SUSEConnect -s | grep ACTIVE)
        if [ -n "$CheckSLESRegistration" ]
        then
          SUSEConnect -p sle-module-public-cloud/12/x86_64 > /dev/null
          echo 0
        else
          echo 1
        fi
    fi
}

###Main Body###

if [ -f "/etc/sap-app-quickstart" ]
then
        echo "****************************************************************"
	echo "****************************************************************"
        echo "The /etc/sap-app-quickstart file exists, exiting the Quick Start"
        echo "****************************************************************"
        echo "****************************************************************"
        exit 0
fi

echo "----- Entering sap-s4hana-aas-inst.sh -----"

# -------------------------------------------------------------------------- #
# Temporary fix for the issue of unable to access SuSE repo issue - 07/06/19
# -------------------------------------------------------------------------- #
echo "Applying temporary fix for accessing SuSE repository issues"
if grep -i suse ${OS_VER} 1> /dev/null
then
    if ls -l /etc/products.d/baseproduct | grep -v "SLES_SAP.prod" 1> /dev/null
    then
        cd /etc/products.d 2>&1
        unlink baseproduct 2>&1
        ln -s SLES_SAP.prod baseproduct 2>&1
        registercloudguest --force-new 2>&1
    fi
fi 
# -------------------------------------------------------------------------- #

#Check to see if this is a BYOS system and register it if it is
if [[ "$MyOS" =~ BYOS ]];
then
    _SUSE_BYOS=$(set_SUSE_BYOS)

    if [ "$_SUSE_BYOS" == 0 ]
    then
	    echo "Successfully setup BYOS"
    else
	    echo "FAILED to setup BYOS...exiting"
	    #signal the waithandler, 1=Failed
        /root/install/signalFinalStatus.sh 1 "FAILED to setup BYOS...exiting"
	    set_cleanup_aasinifile
	    exit 1
    fi
fi

_SET_NET=$(set_net)

if [ "$HOSTNAME" == $(hostname) ]
then
	echo "Successfully set and updated hostname"
	set_DB_hostname
else
	echo "FAILED to set hostname"
	#signal the waithandler, 1=Failed
    /root/install/signalFinalStatus.sh 1 "Failed to set hostname"
	set_cleanup_aasinifile
	exit 1
fi

_SET_AWSCLI=$(set_update_cli)
if [ "$_SET_AWSCLI" == 0 ]
then
    echo "Successfully installed AWS CLI"
else
    echo "FAILED to install AWS CLI...exiting"
	#signal the waithandler, 1=Failed
    /root/install/signalFinalStatus.sh 1 "FAILED to install AWS CLI...exiting"
	set_cleanup_aasinifile
	exit 1
fi

set_oss_configs

_SET_SSM=$(set_install_ssm)

if [ "$_SET_SSM" == 0 ]
then
	echo "Successfully installed SSM"
else
	echo "FAILED to install SSM...exiting"
	#signal the waithandler, 1=Failed
    /root/install/signalFinalStatus.sh 1 "FAILED to install ssm...exiting"
	set_cleanup_aasinifile
	exit 1
fi


_SET_UUIDD=$(set_uuidd)

if [ "$_SET_UUIDD" == 0 ]
then
	echo "Successfully installed UUIDD"
else
	echo "FAILED to install UUIDD...exiting"

fi


_SET_TZ=$(set_tz)

if [ "$_SET_TZ" == 0 ]
then
	echo "Successfully updated TimeZone"
else
	echo "FAILED to update TimeZone...exiting"
	#signal the waithandler, 1=Failed
    /root/install/signalFinalStatus.sh 1 "FAILED to update TimeZone...exiting"
	set_cleanup_aasinifile
	exit 1
fi

if Implement_Chrony
then
    echo "Successfully implemented Chrony!!"
else
    echo "FAILED: Chrony NOT implmented!!"
    /root/install/signalFinalStatus.sh 1 "FAILED: Chrony NOT implemented!!"
    exit
fi

#_SET_NTP=$(set_ntp)
#if [ "$_SET_NTP" == 0 ]
#then
#	echo "Successfully updated NTP"
#else
#	echo "FAILED to update NTP...exiting"
#	#signal the waithandler, 1=Failed
#   /root/install/signalFinalStatus.sh 1 "FAILED to update NTP...exiting"
#	set_cleanup_aasinifile
#	exit 1
#fi

set_install_jq

_SET_FILESYSTEMS=$(set_filesystems)

_VAL_USR_SAP=$(df -h $USR_SAP) 

if [ -n "$_VAL_USR_SAP" ]
then
	echo "Successfully updated $USR_SAP filesystem"
else
	echo "FAILED to update $USR_SAP filesystem...exiting"
	#signal the waithandler, 1=Failed
        /root/install/signalFinalStatus.sh 1 "FAILED to  update $USR_SAP filesystem...exiting"
	set_cleanup_aasinifile
	exit 1
fi

_SET_SAPMNT=$(set_sapmnt)

_SAPMNT=$(df -h $SAPMNT | awk '{ print $NF }' | tail -1)

if [ "$_SAPMNT" == "$SAPMNT"  ]
then
	echo "Successfully setup /sapmnt"
else
	echo "Failed to mount $SAPMNT...exiting"
	#signal the waithandler, 1=Failed
       	/root/install/signalFinalStatus.sh 1 "Failed to mount $SAPMNT...exiting"
	set_cleanup_aasinifile
	exit 1
fi

_SET_AWSDP=$(set_awsdataprovider)

if [ "$_SET_AWSDP" == 0 ]
then
	echo "Successfully installed AWS Data Provider"
else
	echo "FAILED to install AWS Data Provider...exiting"
	#signal the waithandler, 1=Failed
        /root/install/signalFinalStatus.sh 1 "Failed to install AWS Data Provider...exiting"
	set_cleanup_aasinifile
	exit 1
fi


if [ "$INSTALL_SAP" == "No" ]
then
	echo "Completed setting up SAP App Server Infrastrucure."
	echo "Exiting as the option to install SAP software was set to: $INSTALL_SAP"
	#signal the waithandler, 0=Success
	/root/install/signalFinalStatus.sh 0 "Finished. Exiting as the option to install SAP software was set to: $INSTALL_SAP"
	exit 0

fi

MP=$(aws ssm get-parameters --names $SSM_PARAM_STORE --with-decryption --region $REGION --output table | grep Value | awk '{ print $4}')
INVALID_MP=$(aws ssm get-parameters --names $SSM_PARAM_STORE --with-decryption --region $REGION --output text | awk '{ print $1}')

if [ "$INVALID_MP" == "INVALIDPARAMETERS" ]
then
	echo "Invalid encrypted SSM Parameter store: $SSM_PARAM_STORE...exiting"
	#signal the waithandler, 1=Failed
    /root/install/signalFinalStatus.sh 1 "Invalid SSM Parameter Store...exiting"
	set_cleanup_aasinifile
	exit 1
fi

if [ -z "$MP" ]
then
	echo "Could not read encrypted SSM Parameter store: $SSM_PARAM_STORE...exiting"
	#signal the waithandler, 1=Failed
    /root/install/signalFinalStatus.sh 1 "Could not read encrypted SSM Parameter store: $SSM_PARAM_STORE...exiting"
	set_cleanup_aasinifile
	exit 1
fi

###Execute sapinst###

set_ini_file

AAS_INI_FILE=$(cat /tmp/AAS_INI_FILE)

if [ ! -f "$AAS_INI_FILE" ]
then
	echo "Exiting script...no INI FILE...$AAS_INI_FILE"
	#signal the waithandler, 1=Failed
    /root/install/signalFinalStatus.sh 1 "Exiting script...no INI FILE...$AAS_INI_FILE"
	set_cleanup_aasinifile
	exit 1
fi

set_aasinifile

cd $SAPINST
sleep 5

./sapinst SAPINST_INPUT_PARAMETERS_URL="$AAS_INI_FILE" SAPINST_EXECUTE_PRODUCT_ID="$PRODUCT" SAPINST_SKIP_DIALOGS="true" SAPINST_START_GUISERVER="false"

SIDADM=$(cat /tmp/SIDADM)
HOSTNAME=$(hostname)
su - $SIDADM -c "stopsap $HOSTNAME"
su - $SIDADM -c "startsap $HOSTNAME"

sleep 15

#test if SAP is up
_SAP_UP=$(netstat -an | grep 32"$SAPInstanceNum" | grep tcp | grep LISTEN | wc -l )

echo "This is the value of SAP_UP: $_SAP_UP"

if [ "$_SAP_UP" -eq 1 ]
then
	echo "Successfully installed SAP"
	set_cleanup_aasinifile
	set_dist_hosts
	#signal the waithandler, 0=Success
    /root/install/signalFinalStatus.sh 0 "Successfully installed SAP. SAP_UP value is: $_SAP_UP"
	#create the /etc/sap-app-quickstart file
	touch /etc/sap-app-quickstart
	exit
else
	#retry the install and exit if it failed again
    cd $SAPINST
    sleep 5
    ./sapinst SAPINST_INPUT_PARAMETERS_URL="$AAS_INI_FILE" SAPINST_EXECUTE_PRODUCT_ID="$PRODUCT" SAPINST_SKIP_DIALOGS="true" SAPINST_START_GUISERVER="false"

    SIDADM=$(cat /tmp/SIDADM)
    HOSTNAME=$(hostname)
    su - $SIDADM -c "stopsap $HOSTNAME"
    su - $SIDADM -c "startsap $HOSTNAME"

    sleep 15

    #test if SAP is up
    _SAP_UP2=$(netstat -an | grep 32"$SAPInstanceNum" | grep tcp | grep LISTEN | wc -l )

    if [ "$_SAP_UP2" -eq 1 ]
    then
	    echo "Successfully installed SAP"
	    set_cleanup_aasinifile
	    set_dist_hosts
	    #signal the waithandler, 0=Success
        /root/install/signalFinalStatus.sh 0 "Successfully installed SAP. SAP_UP value is: $_SAP_UP"
	    #create the /etc/sap-app-quickstart file
	    touch /etc/sap-app-quickstart
	    exit
    else
        echo "SAP installed FAILED."
	    set_cleanup_aasinifile
	    #signal the waithandler, 0=Success
	    _ERR_LOG=$(find /tmp -type f -name "sapinst_dev.log")
	    _PASS_ERR=$(grep ERR "$_ERR_LOG" | grep -i password)
	    /root/install/signalFinalStatus.sh 1 "SAP AAS install RETRY Failed...AAS not installed 2nd retry...password error?= "$_PASS_ERR" "
    fi
fi
