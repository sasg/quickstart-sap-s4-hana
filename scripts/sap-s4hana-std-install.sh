#!/bin/bash -x

usage() {
	cat <<EOF
	Usage: $0 [options]
		-h print usage
		-s SID
		-i instance
		-p HANA password
		-n MASTER_HOSTNAME
		-d DOMAIN
		-w WORKER_HOSTNAME
		-l HANA_LOG_FILE [optional]
EOF
	exit 1
}

# ------------------------------------------------------------------
# Read all inputs based on the same format as install-master.sh
# ------------------------------------------------------------------

while getopts ":h:s:i:p:n:d:w:l:" o; do
    case "${o}" in
    h) usage && exit 0
	   ;;
	s) SID=${OPTARG}
	   ;;
	i) INSTANCE=${OPTARG}
	   ;;
	p) HANAPASSWORD=${OPTARG}
	   ;;
	n) MASTER_HOSTNAME=${OPTARG}
	   ;;
	d) DOMAIN=${OPTARG}
	   ;;
    w) WORKER_HOSTNAME=${OPTARG}
	   ;;
    l) HANA_LOG_FILE=${OPTARG}
	   ;;
    *)
       usage
	   ;;
    esac
done

###Global Variables###
source /root/install/config.sh
TZ_LOCAL_FILE="/etc/localtime"
NTP_CONF_FILE="/etc/ntp.conf"
USR_SAP="/usr/sap"
SAPMNT="/sapmnt"
USR_SAP_DEVICE="/dev/xvdb"
SAPMNT_DEVICE="/dev/xvdy"
SWAP_DEVICE="/dev/xvdd"
USR_SAP_VOL="xvdb"
SAPMNT_VOL="xvdy"
SWAP_VOL="xvdd"
FSTAB_FILE="/etc/fstab"
DHCP="/etc/sysconfig/network/dhcp"
CLOUD_CFG="/etc/cloud/cloud.cfg"
IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4/)
HOSTS_FILE="/etc/hosts"
HOSTNAME_FILE="/etc/HOSTNAME"
NETCONFIG="/etc/sysconfig/network/config"
ETC_SVCS="/etc/services"
SAPMNT_SVCS="/sapmnt/SWPM/services"
SERVICES_FILE="/sapmnt/SWPM/services"
SW_TARGET="/sapmnt/SWPM"
SRC_INI_DIR="/root/install"
SAPINST="/sapmnt/SWPM/sapinst"
REGION=$(curl http://169.254.169.254/latest/dynamic/instance-identity/document/ | grep -i region | awk '{ print $3 }' | sed 's/"//g' | sed 's/,//g')
MASTER_HOSTS="/sapmnt/SWPM/master_etc_hosts"

ASCS_INI_FILE="/sapmnt/SWPM/s4-ascs.params"
PAS_INI_FILE="/sapmnt/SWPM/s4-pas.params"
DB_INI_FILE="/sapmnt/SWPM/s4-db.params"
STD_INI_FILE="/sapmnt/SWPM/s4-std.params"

ASCS_PRODUCT="NW_ABAP_ASCS:S4HANA1809.CORE.HDB.ABAP"
DB_PRODUCT="NW_ABAP_DB:S4HANA1809.CORE.HDB.ABAP"
PAS_PRODUCT="NW_ABAP_CI:S4HANA1809.CORE.HDB.ABAP"
STD_PRODUCT="NW_ABAP_OneHost:S4HANA1809.CORE.HDB.ABAP"

###Dynamic Variables###
HOSTNAME=$(hostname)
DB_SID=$SID
INSTALL_SAP="Yes"
INSTALL_SAP_VERSION="S/4HANA-1809"
DBHOSTNAME=$MASTER_HOSTNAME
HOSTED_ZONE=$DOMAIN
MP=$HANAPASSWORD
SAP_SCHEMA_NAME="SAPABAP1"

#TODO as parameters#
EFS="No"

#if [ "$INSTALL_SAP_VERSION" == "SAP-NetWeaver-7.4" ]
#then
#    PAS_INI_FILE="/sapmnt/SWPM/PASX_D00_Linux_HDB.params"
#    DB_INI_FILE="/sapmnt/SWPM/DB_00_Linux_HDB.params"
#    ASCS_PRODUCT="NW_ABAP_ASCS:NW740SR2.HDB.PIHA"
#    DB_PRODUCT="NW_ABAP_DB:NW740SR2.HDB.PI"
#    PAS_PRODUCT="NW_ABAP_CI:NW740SR2.HDB.PIHA"
#    SW_TARGET="/sapmnt/SWPM"
#    SRC_INI_DIR="/root/install"
#    SAPINST="/sapmnt/SWPM/sapinst"
#else
#    PAS_INI_FILE="/sapmnt/SWPM/NW75/PASX_D00_Linux_HDB.params"
#    DB_INI_FILE="/sapmnt/SWPM/NW75/DB_00_Linux_HDB.params"
#    ASCS_PRODUCT="NW_ABAP_ASCS:NW750.HDB.ABAPHA"
#    DB_PRODUCT="NW_ABAP_DB:NW750.HDB.ABAPHA"
#    PAS_PRODUCT="NW_ABAP_CI:NW750.HDB.ABAPHA"
#    SW_TARGET="/sapmnt/SWPM/NW75"
#    SRC_INI_DIR="/root/install/NW75"
#    SAPINST="/sapmnt/SWPM/NW75/sapinst"
#fi

#
###  Variables below need to be CUSTOMIZED for your environment  ###


###Functions###
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

    #This section is from OSS #2205917 - SAP HANA DB: Recommended OS settings for SLES 12 / SLES for SAP Applications 12
    #and OSS #2292711 - SAP HANA DB: Recommended OS settings for SLES 12 SP1 / SLES for SAP Applications 12 SP1

    zypper remove ulimit > /dev/null

    echo "###################" >> /etc/init.d/boot.local
    echo "#BEGIN: This section inserted by AWS SAP Quickstart" >> /etc/init.d/boot.local

    #Disable THP
    echo never > /sys/kernel/mm/transparent_hugepage/enabled
    echo "echo never > /sys/kernel/mm/transparent_hugepage/enabled" >> /etc/init.d/boot.local

    echo 10 > /proc/sys/vm/swappiness
    echo "echo 10 > /proc/sys/vm/swappiness" >> /etc/init.d/boot.local

    #Disable KSM
    echo 0 > /sys/kernel/mm/ksm/run
    echo "echo 0 > /sys/kernel/mm/ksm/run" >> /etc/init.d/boot.local

    #NoHZ is not set

    #Disable AutoNUMA
    echo 0 > /proc/sys/kernel/numa_balancing
    echo "echo 0 > /proc/sys/kernel/numa_balancing" >> /etc/init.d/boot.local

    #Increase max open files
    echo 1048576 > /proc/sys/fs/nr_open
    echo "echo 1048576 > /proc/sys/fs/nr_open" >> /etc/init.d/boot.local

    zypper -n install gcc

    zypper -n install libgcc_s1 libstdc++6

    echo "#END: This section inserted by AWS SAP HANA Quickstart" >> /etc/init.d/boot.local
    echo "###################" >> /etc/init.d/boot.local
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

set_stdinifile() {
#set the vname of the database server in the INI file

    sed -i  "/HDB_Schema_Check_Dialogs.schemaPassword/ c\HDB_Schema_Check_Dialogs.schemaPassword = ${MP}" $STD_INI_FILE
    sed -i  "/NW_CI_Instance.ascsVirtualHostname/ c\NW_CI_Instance.ascsVirtualHostname = ${HOSTNAME}" $STD_INI_FILE
    sed -i  "/NW_CI_Instance.ciVirtualHostname/ c\NW_CI_Instance.ciVirtualHostname = ${HOSTNAME}" $STD_INI_FILE
    sed -i  "/NW_CI_Instance.scsVirtualHostname/ c\NW_CI_Instance.scsVirtualHostname = ${HOSTNAME}" $STD_INI_FILE
    sed -i  "/NW_GetMasterPassword.masterPwd/ c\NW_GetMasterPassword.masterPwd = ${MP}" $STD_INI_FILE
    sed -i  "/NW_GetSidNoProfiles.sid/ c\NW_GetSidNoProfiles.sid = ${SAP_SID}" $STD_INI_FILE
    sed -i  "/NW_HDB_getDBInfo.dbhost/ c\NW_HDB_getDBInfo.dbhost = ${DBHOSTNAME}" $STD_INI_FILE
    sed -i  "/NW_HDB_getDBInfo.dbsid/ c\NW_HDB_getDBInfo.dbsid = ${DB_SID}" $STD_INI_FILE
    sed -i  "/NW_HDB_getDBInfo.systemDbPassword/ c\NW_HDB_getDBInfo.systemDbPassword = ${MP}" $STD_INI_FILE
    sed -i  "/NW_HDB_getDBInfo.systemPassword/ c\NW_HDB_getDBInfo.systemPassword = ${MP}" $STD_INI_FILE
    sed -i  "/NW_Recovery_Install_HDB.extractLocation/ c\NW_Recovery_Install_HDB.extractLocation = /backup/data/${DB_SID}" $STD_INI_FILE
    sed -i  "/NW_Recovery_Install_HDB.sidAdmName/ c\NW_Recovery_Install_HDB.sidAdmName = ${DB_SIDADM}" $STD_INI_FILE
    sed -i  "/NW_Recovery_Install_HDB.sidAdmPassword/ c\NW_Recovery_Install_HDB.sidAdmPassword = ${MP}" $STD_INI_FILE
    sed -i  "/NW_getFQDN.FQDN/ c\NW_getFQDN.FQDN = ${HOSTED_ZONE}" $STD_INI_FILE
    sed -i  "/archives.downloadBasket/ c\archives.downloadBasket = ${SW_TARGET}/s4-1809" $STD_INI_FILE
    sed -i  "/nwUsers.sidadmPasswod/ c\nwUsers.sidadmPassword = ${MP}" $STD_INI_FILE
    sed -i  "/storageBasedCopy.hdb.systemPassword/ c\storageBasedCopy.hdb.systemPassword = ${MP}" $STD_INI_FILE
    echo "NW_HDB_DB.abapSchemaName = ${SAP_SCHEMA_NAME}" >> $STD_INI_FILE
    echo "NW_HDB_DB.abapSchemaPassword = ${MP}" >> $STD_INI_FILE
}

set_cleanup_stdinifiles() {
#cleanup the password in the  the INI files

    MP="DELETED"
    sed -i  "/HDB_Schema_Check_Dialogs.schemaPassword/ c\HDB_Schema_Check_Dialogs.schemaPassword = ${MP}" $STD_INI_FILE
    sed -i  "/NW_GetMasterPassword.masterPwd/ c\NW_GetMasterPassword.masterPwd = ${MP}" $STD_INI_FILE
    sed -i  "/NW_HDB_getDBInfo.systemDbPassword/ c\NW_HDB_getDBInfo.systemDbPassword = ${MP}" $STD_INI_FILE
    sed -i  "/NW_HDB_getDBInfo.systemPassword/ c\NW_HDB_getDBInfo.systemPassword = ${MP}" $STD_INI_FILE
    sed -i  "/NW_Recovery_Install_HDB.sidAdmPassword/ c\NW_Recovery_Install_HDB.sidAdmPassword = ${MP}" $STD_INI_FILE
    sed -i  "/nwUsers.sidadmPasswod/ c\nwUsers.sidadmPassword = ${MP}" $STD_INI_FILE
    sed -i  "/storageBasedCopy.hdb.systemPassword/ c\storageBasedCopy.hdb.systemPassword = ${MP}" $STD_INI_FILE
}

set_s3_download() {

    #download the media from the S3 bucket provided
    _S3_DL=$(aws s3 sync "s3://${S3_BUCKET}/${S3_BUCKET_KP}" "$SW_TARGET" 2>&1 >/dev/null | grep "download failed")

    if [ -n "$S3_DL" ]
    then

        #download failed for some reason, try to download again
        _S3_DL2=$(aws s3 sync "s3://${S3_BUCKET}/${S3_BUCKET_KP}" "$SW_TARGET" 2>&1 >/dev/null | grep "download failed")
        
        if [ -n "$S3_DL2" ]
        then
            #download failed on 2nd try, exit
            echo 1
            return
        fi
    fi
    cd "$SRC_INI_DIR" 
    cp *.params  "$SW_TARGET"

    if [ -d "$SAPINST" ]
    then
        chmod -R 755 $SW_TARGET > /dev/null 
	    cd "$SRC_INI_DIR" 
        cp *.params  "$SW_TARGET"
        echo 0
    else
	    #retry the download again
        aws s3 sync "s3://${S3_BUCKET}/${S3_BUCKET_KP}" "$SW_TARGET" > /dev/null
        
        #aws s3 sync "$S3_BUCKET/$S3_BUCKET_KP" "$SW_TARGET" > /dev/null
        if [ -d "$SAPINST" ]
        then
            chmod -R 755 $SW_TARGET > /dev/null 
	        cd "$SRC_INI_DIR" 
            cp *.params  "$SW_TARGET"
            echo 0
        else
            echo 1
        fi
    fi

}

set_dbinifile() {
#set the vname of the database server in the INI file

    #set the db server hostname
    sed -i  "/NW_HDB_getDBInfo.dbhost/ c\NW_HDB_getDBInfo.dbhost = ${DBHOSTNAME}" $DB_INI_FILE
    
    # Remove - This is set to "true" in S4/HANA db.params file
    #sed -i  "/hdb.create.dbacockpit.user/ c\hdb.create.dbacockpit.user = false" $DB_INI_FILE

    #set the password from the SSM parameter store
    sed -i  "/NW_HDB_getDBInfo.systemPassword/ c\NW_HDB_getDBInfo.systemPassword = ${MP}" $DB_INI_FILE
    sed -i  "/storageBasedCopy.hdb.systemPassword/ c\storageBasedCopy.hdb.systemPassword = ${MP}" $DB_INI_FILE
    sed -i  "/HDB_Schema_Check_Dialogs.schemaPassword/ c\HDB_Schema_Check_Dialogs.schemaPassword = ${MP}" $DB_INI_FILE
    sed -i  "/NW_GetMasterPassword.masterPwd/ c\NW_GetMasterPassword.masterPwd = ${MP}" $DB_INI_FILE
    sed -i  "/NW_HDB_DB.abapSchemaPassword/ c\NW_HDB_DB.abapSchemaPassword = ${MP}" $DB_INI_FILE
    sed -i  "/NW_HDB_getDBInfo.systemDbPassword/ c\NW_HDB_getDBInfo.systemDbPassword = ${MP}" $DB_INI_FILE
    
    # Add - This is set in S4/HANA db.params file
    sed -i  "/NW_Recovery_Install_HDB.sidAdmPassword/ c\NW_Recovery_Install_HDB.sidAdmPassword = ${MP}" $DB_INI_FILE

    #set the SID and Schema
    sed -i  "/NW_HDB_getDBInfo.dbsid/ c\NW_HDB_getDBInfo.dbsid = ${SAP_SID}" $DB_INI_FILE
    sed -i  "/NW_readProfileDir.profileDir/ c\NW_readProfileDir.profileDir = /sapmnt/${SAP_SID}/profile" $DB_INI_FILE
    sed -i  "/NW_HDB_DB.abapSchemaName/ c\NW_HDB_DB.abapSchemaName = ${SAP_SCHEMA_NAME}" $DB_INI_FILE
    
    # Remove - This is commented out in S4/HANA db.params file
    #sed -i  "/HDB_Schema_Check_Dialogs.schemaName/ c\HDB_Schema_Check_Dialogs.schemaName = ${SAP_SCHEMA_NAME}" $DB_INI_FILE

    #set the UID and GID
    sed -i  "/nwUsers.sidAdmUID/ c\nwUsers.sidAdmUID = ${SIDadmUID}" $DB_INI_FILE
    sed -i  "/nwUsers.sapsysGID/ c\nwUsers.sapsysGID = ${SAPsysGID}" $DB_INI_FILE

    # Remove - These are set through parameter "archives.downloadBasket" in S4/HANA db.params file
    #set the CD location based on $SW_TARGET
    #sed -i  "/SAPINST.CD.PACKAGE.KERNEL/ c\SAPINST.CD.PACKAGE.KERNEL = ${SW_TARGET}/KERN_CD" $DB_INI_FILE
    #sed -i  "/SAPINST.CD.PACKAGE.RDBMS/ c\SAPINST.CD.PACKAGE.RDBMS = ${SW_TARGET}/HDB_CLNTCD" $DB_INI_FILE
    #sed -i  "/SAPINST.CD.PACKAGE.LOAD/ c\SAPINST.CD.PACKAGE.LOAD = ${SW_TARGET}/EXP_CD" $DB_INI_FILE

    # Add - These 3 are set in S4/HANA db.params file
    sed -i  "/archives.downloadBasket/ c\archives.downloadBasket = ${SW_TARGET}/s4-1809" $DB_INI_FILE
    sed -i  "/NW_Recovery_Install_HDB.extractLocation/ c\NW_Recovery_Install_HDB.extractLocation = /backup/data/${SAP_SID}" $DB_INI_FILE
    sed -i  "/NW_Recovery_Install_HDB.sidAdmName/ c\NW_Recovery_Install_HDB.sidAdmName = ${SIDADM}" $DB_INI_FILE
}

set_pasinifile() {
#set the vname of the database server in the INI file

    # Remove - "true" is the default value for S4/HANA in pas.params file
    #sed -i  "/hdb.create.dbacockpit.user/ c\hdb.create.dbacockpit.user = true" $PAS_INI_FILE

    #set the password from the SSM parameter store
    sed -i  "/NW_GetMasterPassword.masterPwd/ c\NW_GetMasterPassword.masterPwd = ${MP}" $PAS_INI_FILE
    # Remove - This is not in S4/HANA pas.params file
    #sed -i  "/NW_HDB_getDBInfo.systemPassword/ c\NW_HDB_getDBInfo.systemPassword = ${MP}" $PAS_INI_FILE
    sed -i  "/storageBasedCopy.hdb.systemPassword/ c\storageBasedCopy.hdb.systemPassword = ${MP}" $PAS_INI_FILE
    sed -i  "/storageBasedCopy.abapSchemaPassword/ c\storageBasedCopy.abapSchemaPassword = ${MP}" $PAS_INI_FILE
    sed -i  "/HDB_Schema_Check_Dialogs.schemaPassword/ c\HDB_Schema_Check_Dialogs.schemaPassword = ${MP}" $PAS_INI_FILE
    sed -i  "/NW_HDB_getDBInfo.systemDbPassword/ c\NW_HDB_getDBInfo.systemDbPassword = ${MP}" $PAS_INI_FILE

    # Add - These 2 are set in S4/HANA pas.params file
    sed -i  "/nwUsers.sidadmPasswod/ c\nwUsers.sidadmPassword = ${MP}" $PAS_INI_FILE
    sed -i  "/hostAgent.sapAdmPassword/ c\hostAgent.sapAdmPassword = ${MP}" $PAS_INI_FILE

    #set the profile directory
    sed -i  "/NW_readProfileDir.profileDir/ c\NW_readProfileDir.profileDir = /sapmnt/${SAP_SID}/profile" $PAS_INI_FILE
     
    #set the SID and Schema
    sed -i  "/HDB_Schema_Check_Dialogs.schemaName/ c\HDB_Schema_Check_Dialogs.schemaName = ${SAP_SCHEMA_NAME}" $PAS_INI_FILE

    #set the UID and GID
    sed -i  "/nwUsers.sidAdmUID/ c\nwUsers.sidAdmUID = ${SIDadmUID}" $PAS_INI_FILE
    sed -i  "/nwUsers.sapsysGID/ c\nwUsers.sapsysGID = ${SAPsysGID}" $PAS_INI_FILE

    #set the CD location based on $SW_TARGET
    #sed -i  "/SAPINST.CD.PACKAGE.KERNEL/ c\SAPINST.CD.PACKAGE.KERNEL = ${SW_TARGET}/KERN_CD" $PAS_INI_FILE
    #sed -i  "/SAPINST.CD.PACKAGE.RDBMS/ c\SAPINST.CD.PACKAGE.RDBMS = ${SW_TARGET}/HDB_CLNTCD" $PAS_INI_FILE
    #sed -i  "/SAPINST.CD.PACKAGE.LOAD/ c\SAPINST.CD.PACKAGE.LOAD = ${SW_TARGET}/EXP_CD" $PAS_INI_FILE

    sed -i  "/archives.downloadBasket/ c\archives.downloadBasket = ${SW_TARGET}/s4-1809" $PAS_INI_FILE
    sed -i  "/NW_getFQDN.FQDN/ c\NW_getFQDN.FQDN = ${HOSTED_ZONE}" $PAS_INI_FILE
    sed -i  "/NW_CI_Instance.ciVirtualHostname/ c\NW_CI_Instance.ciVirtualHostname = ${HOSTNAME}" $PAS_INI_FILE
    sed -i  "/NW_CI_Instance.ascsVirtualHostname/ c\NW_CI_Instance.ascsVirtualHostname = ${HOSTNAME}" $PAS_INI_FILE    
}

set_cleanup_inifiles() {
#cleanup the password in the  the INI files

    MP="DELETED"
    sed -i  "/nwUsers.sidadmPasswod/ c\nwUsers.sidadmPassword = ${MP}" $PAS_INI_FILE

    sed -i  "/NW_GetMasterPassword.masterPwd/ c\NW_GetMasterPassword.masterPwd = ${MP}" $PAS_INI_FILE
    # Remove - This is not in S4/HANA pas.params file
    #sed -i  "/NW_HDB_getDBInfo.systemPassword/ c\NW_HDB_getDBInfo.systemPassword = ${MP}" $PAS_INI_FILE
    sed -i  "/storageBasedCopy.hdb.systemPassword/ c\storageBasedCopy.hdb.systemPassword = ${MP}" $PAS_INI_FILE
    sed -i  "/storageBasedCopy.abapSchemaPassword/ c\storageBasedCopy.abapSchemaPassword = ${MP}" $PAS_INI_FILE
    sed -i  "/HDB_Schema_Check_Dialogs.schemaPassword/ c\HDB_Schema_Check_Dialogs.schemaPassword = ${MP}" $PAS_INI_FILE
    sed -i  "/NW_HDB_getDBInfo.systemPassword/ c\NW_HDB_getDBInfo.systemPassword = ${MP}" $DB_INI_FILE
    sed -i  "/nwUsers.sidadmPasswod/ c\nwUsers.sidadmPassword = ${MP}" $PAS_INI_FILE
    sed -i  "/hostAgent.sapAdmPassword/ c\hostAgent.sapAdmPassword = ${MP}" $PAS_INI_FILE

    sed -i  "/NW_HDB_getDBInfo.systemPassword/ c\NW_HDB_getDBInfo.systemPassword = ${MP}" $DB_INI_FILE
    sed -i  "/NW_Recovery_Install_HDB.sidAdmPassword/ c\NW_Recovery_Install_HDB.sidAdmPassword = ${MP}" $DB_INI_FILE
    sed -i  "/storageBasedCopy.hdb.systemPassword/ c\storageBasedCopy.hdb.systemPassword = ${MP}" $DB_INI_FILE
    sed -i  "/HDB_Schema_Check_Dialogs.schemaPassword/ c\HDB_Schema_Check_Dialogs.schemaPassword = ${MP}" $DB_INI_FILE
    sed -i  "/NW_GetMasterPassword.masterPwd/ c\NW_GetMasterPassword.masterPwd = ${MP}" $DB_INI_FILE
    sed -i  "/NW_HDB_DB.abapSchemaPassword/ c\NW_HDB_DB.abapSchemaPassword = ${MP}" $DB_INI_FILE
    sed -i  "/NW_HDB_getDBInfo.systemDbPassword/ c\NW_HDB_getDBInfo.systemDbPassword = ${MP}" $PAS_INI_FILE
}

set_ntp() {
#set ntp in the /etc/ntp.conf file

	cp "$NTP_CONF_FILE" "$NTP_CONF_FILE.bak"
	echo "server 0.pool.ntp.org" >> "$NTP_CONF_FILE"
	echo "server 1.pool.ntp.org" >> "$NTP_CONF_FILE"
	echo "server 2.pool.ntp.org" >> "$NTP_CONF_FILE"
	echo "server 3.pool.ntp.org" >> "$NTP_CONF_FILE"
	systemctl start ntpd
	echo "systemctl start ntpd" >> /etc/init.d/boot.local

	_COUNT_NTP=$(grep ntp "$NTP_CONF_FILE" | wc -l)

	if [ "$_COUNT_NTP" -ge 4 ]
	then
		echo 0
	else
		echo 1
	fi
}

set_install_jq () {
#install jq s/w

	cd /tmp
	wget https://github.com/stedolan/jq/releases/download/jq-1.5/jq-linux64
    mv jq-linux64 jq
    chmod 755 jq
}

set_filesystems() {
#create /usr/sap filesystem and mount /sapmnt


	#bash /root/install/create-attach-single-volume.sh "50:gp2:$USR_SAP_DEVICE:$USR_SAP" > /dev/null
	USR_SAP_VOLUME=$(lsblk  | grep $USR_SAP_VOL)

	if [ -z "$USR_SAP_VOLUME" ]
	then
		echo "Exiting, can not create $USR_SAP_DEVICE or $SAPMNT_DEVICE EBS volumes"
	    #signal the waithandler, 1=Failed
	    /root/install/signalFinalStatus.sh 1 "Exiting, can not create $USR_SAP_DEVICE or $SAPMNT_DEVICE EBS volumes"
	    set_cleanup_stdinifiles
		exit 1
	else
		mkdir $USR_SAP > /dev/null 2>&1
		mkfs -t xfs $USR_SAP_DEVICE > /dev/null 2>&1
		echo "$USR_SAP_DEVICE  $USR_SAP xfs nobarrier,noatime,nodiratime,logbsize=256k 0 0" >> $FSTAB_FILE 2>&1
		mount -a > /dev/null 2>&1
		mkswap $SWAP_DEVICE > /dev/null 2>&1
		swapon $SWAP_DEVICE > /dev/null 2>&1
	fi
}

set_dhcp() {

	sed -i '/DHCLIENT_SET_HOSTNAME/ c\DHCLIENT_SET_HOSTNAME="no"' $DHCP

	service network restart

	_DHCP=$(grep DHCLIENT_SET_HOSTNAME $DHCP | grep no)

	if [ -n "$_DHCP" ]
	then
		echo 0
	else
		echo 1
	fi
}

#set_DB_hostname() {
#
#	#add DB hostname
#	echo "$DBIP  $DBHOSTNAME" >> $HOSTS_FILE
#
#	#add own hostname
#	MY_IP=$( ip a | grep inet | grep eth0 | awk -F"/" '{ print $1 }' | awk '{ print $2 }')
#	echo "${MY_IP}"    "${HOSTNAME}" >> /etc/hosts  
#
#	#echo "$SAP_PASIP  $SAP_PAS" >> $HOSTS_FILE
#	#echo "$SAP_PASIP  $SAP_PAS" >> $HOSTS_FILE
#	#echo "$SAP_ASCSIP  $SAP_ASCS" >> $HOSTS_FILE
#}

set_net() {
#set and preserve the hostname


	#update DNS search order with our DNS Domain name
	sed -i "/NETCONFIG_DNS_STATIC_SEARCHLIST=""/ c\NETCONFIG_DNS_STATIC_SEARCHLIST="${HOSTED_ZONE}"" $NETCONFIG

	#update the /etc/resolv.conf file
	netconfig update -f > /dev/null

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
            mount /sapmnt > /dev/null
            sleep 60
        fi
    else
        #If EFS is *no*, we create a new mount the /sapmnt filesystem from the ASCS server.
        #Supporting a single-AZ /sapmnt scenario is for intra-AZ fail-over scenarios.
        #The /sapmnt filesystem is tied to the ASCS server (use a bigger ASCS instance/EBS vol. type if you need more throughput or IOPs for /sapmnt) 

        #Mount /sapmnt from the ASCS server

    #    echo ""$ASCS_NAME:$SAPMNT"  "$SAPMNT"  nfs rw,soft,bg,timeo=3,intr 0 0"  >> $FSTAB_FILE
		mkdir /sapmnt > /dev/null 2>&1
		mkfs -t xfs $SAPMNT_DEVICE > /dev/null 2>&1
		echo "$SAPMNT_DEVICE  /sapmnt xfs nobarrier,noatime,nodiratime,logbsize=256k 0 0" >> $FSTAB_FILE 2>&1

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
}

set_uuidd() {
#Install the uuidd daemon per SAP Note 1391070

	zypper -n install uuidd > /dev/null 2>&1
	chkconfig uuidd on > /dev/null 2>&1
	service uuidd start > /dev/null 2>&1

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
    zypper -n install python-pip > /dev/null 2>&1

	pip install --upgrade --user awscli > /dev/null 2>&1

	_AWS_CLI=$(aws --version 2>&1)

	if [ -n "$_AWS_CLI" ]
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

	chkconfig ssm on > /dev/null 2>&1

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

##Check to see if this is a BYOS system and register it if it is
#if [[ "$MyOS" =~ BYOS ]];
#then
#    _SUSE_BYOS=$(set_SUSE_BYOS)
#
#    if [ "$_SUSE_BYOS" == 0 ]
#    then
#	    echo "Successfully setup BYOS"
#    else
#	    echo "FAILED to setup BYOS...exiting"
#	    #signal the waithandler, 1=Failed
#        /root/install/signalFinalStatus.sh 1 "FAILED to setup BYOS...exiting"
#        set_cleanup_aasinifile
#	    exit 1
#    fi
#fi

_SET_NET=$(set_net)


#if [ "$HOSTNAME" == $(hostname) ]
#then
#	echo "Successfully set and updated hostname"
#	set_DB_hostname
#else
#	echo "FAILED to set hostname"
#	#signal the waithandler, 1=Failed
#    /root/install/signalFinalStatus.sh 1 "Failed to set hostname"
#	set_cleanup_stdinifiles
#	exit 1
#fi

_SET_AWSCLI=$(set_update_cli)

if [ "$_SET_AWSCLI" == 0 ]
then
	echo "Successfully installed AWS CLI"
else
	echo "FAILED to install AWS CLI...exiting"
	#signal the waithandler, 1=Failed
    /root/install/signalFinalStatus.sh 1 "FAILED to install AWS CLI...exiting"
	set_cleanup_stdinifiles
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
	set_cleanup_stdinifiles
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
	set_cleanup_stdinifiles
	exit 1
fi

_SET_NTP=$(set_ntp)

if [ "$_SET_NTP" == 0 ]
then
	echo "Successfully updated NTP"
else
	echo "FAILED to update NTP...exiting"
	#signal the waithandler, 1=Failed
    /root/install/signalFinalStatus.sh 1 "FAILED to update NTP...exiting"
	set_cleanup_stdinifiles
	exit 1
fi

set_install_jq

_SET_AWSDP=$(set_awsdataprovider)

if [ "$_SET_AWSDP" == 0 ]
then
	echo "Successfully installed AWS Data Provider"
else
	echo "FAILED to install AWS Data Provider...exiting"
	#signal the waithandler, 1=Failed
    /root/install/signalFinalStatus.sh 1 "Failed to install AWS Data Provider...exiting"
	set_cleanup_stdinifiles
	exit 1
fi

_SET_FILESYSTEMS=$(set_filesystems)

_VAL_USR_SAP=$(df -h $USR_SAP) 

if [ -n "$_VAL_USR_SAP" ]
then
	echo "Successfully updated $USR_SAP filesystem"
else
	echo "FAILED to update $USR_SAP filesystem...exiting"
	#signal the waithandler, 1=Failed
    /root/install/signalFinalStatus.sh 1 "FAILED to  update $USR_SAP filesystem...exiting"
	set_cleanup_stdinifiles
	exit 1
fi

#mkdir /sapmnt
_SET_SAPMNT=$(set_sapmnt)

_SAPMNT=$(df -h $SAPMNT | awk '{ print $NF }' | tail -1)

if [ "$_SAPMNT" == "$SAPMNT"  ]
then
	echo "Successfully setup /sapmnt"
else
	echo "Failed to mount $SAPMNT...exiting"
	#signal the waithandler, 1=Failed
    /root/install/signalFinalStatus.sh 1 "Failed to mount $SAPMNT, tried $COUNT times...exiting"
	sset_cleanup_stdinifiles
	exit 1
fi

#recreate the SSM param store as encrypted
#_MPINV=$(aws ssm get-parameters --names $SSM_PARAM_STORE --with-decryption --region $REGION --output text | awk '{ print $1}' | grep INVALID | wc -l)

#_MPVAL=$(aws ssm get-parameters --names $SSM_PARAM_STORE --with-decryption --region $REGION --output text | awk '{ print $NF}' | wc -l)

#_MPINV will be 1 when aws ssm get-parameters returns the INVALID response

#while [ "$_MPVAL" -eq 0 -a "$_MPINV" -eq 1 ]
#do
#	echo "Waiting for SSM parameter store: $SSM_PARAM_STORE @ $(date)..."
#    #_MPINV will be 0 when aws ssm get-parameters command returns a valid response
#	_MPINV=$(aws ssm get-parameters --names $SSM_PARAM_STORE --with-decryption --region $REGION --output text | awk '{ print $1}' | grep INVALID | wc -l)
#	sleep 15
#done

#MP=$(aws ssm get-parameters --names $SSM_PARAM_STORE --with-decryption --region $REGION --output text | awk '{ print $4}')

#MP=$(aws ssm get-parameters --names $SSM_PARAM_STORE --with-decryption --region $REGION --output table | grep Value | awk '{ print $4}')
#INVALID_MP=$(aws ssm get-parameters --names $SSM_PARAM_STORE --with-decryption --region $REGION --output text | awk '{ print $1}')

#if [ "$INVALID_MP" == "INVALIDPARAMETERS" ]
#then
#	echo "Invalid encrypted SSM Parameter store: $SSM_PARAM_STORE...exiting"
#	#signal the waithandler, 1=Failed
#    /root/install/signalFinalStatus.sh 1 "Invalid SSM Parameter Store...exiting"
#	set_cleanup_stdinifiles
#	exit 1
#fi
#
#if [ -z "$MP" ]
#then
#	echo "Could not read encrypted SSM Parameter store: $SSM_PARAM_STORE...exiting"
#	#signal the waithandler, 1=Failed
#   /root/install/signalFinalStatus.sh 1 "Could not read encrypted SSM Parameter store: $SSM_PARAM_STORE...exiting"
#	set_cleanup_stdinifiles
#	exit 1
#fi

if [ "$INSTALL_SAP" == "No" ]
then
	echo "Completed setting up SAP App Server Infrastrucure."
	echo "Exiting as the option to install SAP software was set to: $INSTALL_SAP"
	#signal the waithandler, 0=Success
	/root/install/signalFinalStatus.sh 0 "Finished. Exiting as the option to install SAP software was set to: $INSTALL_SAP"
	exit 0
fi

###Execute sapinst###

SIDADM=`echo ${SAP_SID} | tr '[:upper:]' '[:lower:]'`adm
DB_SIDADM=`echo ${DB_SID} | tr '[:upper:]' '[:lower:]'`adm

set_s3_download
set_services_file
#set_dbinifile
#set_pasinifile
set_stdinifile

cd $SAPINST
sleep 5

#support multilple NW versions
echo "Before SAP Install\n" >> /tmp/install-single-hosts.log

echo "Installing the SAP instance...(1st try)"
./sapinst SAPINST_INPUT_PARAMETERS_URL="$STD_INI_FILE" SAPINST_EXECUTE_PRODUCT_ID="$STD_PRODUCT" SAPINST_SKIP_DIALOGS=true SAPINST_START_GUISERVER=false

echo "After SAP Install\n" >> /tmp/install-single-hosts.log

#test if SAP is up
_SAP_UP=$(ps -ef | grep dw.sap${SAP_SID} | grep -v grep | wc -l )

echo "This is the value of SAP_UP: $_SAP_UP"

if [ "$_SAP_UP" -eq 0 ]
then
    echo "Failed install SAP" >> /tmp/install-single-hosts.log
    touch /root/install/sap-s4hana-std-install-script-failed
    set_cleanup_stdinifiles
    exit 1
else

    echo "Successfully installed SAP" >> /tmp/install-single-hosts.log
    set_cleanup_stdinifiles
	#create the /etc/sap-app-quickstart file
    touch /root/install/sap-s4hana-std-install-script-ended-successfully
	touch /etc/sap-app-quickstart
    exit 0

fi