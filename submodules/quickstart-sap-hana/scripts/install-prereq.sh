#!/bin/bash

# ------------------------------------------------------------------
#         Global Variables
# ------------------------------------------------------------------

SCRIPT_DIR=/root/install/
CLUSTERWATCH_SCRIPT=${SCRIPT_DIR}/ClusterWatchEngine.sh
TZ_LOCAL_FILE=/etc/localtime

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


#***BEGIN Functions***

# ------------------------------------------------------------------
#          Output log to HANA_LOG_FILE
# ------------------------------------------------------------------

log() {

    echo $* 2>&1 | tee -a ${HANA_LOG_FILE}

#error check and return
}

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
        JT)
                TZ_ZONE_FILE="/usr/share/zoneinfo/Asia/Tokyo"
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


#***END Functions***

# ------------------------------------------------------------------
#         Code Body section
# ------------------------------------------------------------------

#Execute the RHEL or SLES install pre-requisite script based on O.S. type
if (( $(isRHEL) == 1 )); then
     set_tz
     echo "Executing  /root/install/install-prereq-rhel.sh @ `date`" | tee -a ${HANA_LOG_FILE}
     /root/install/install-prereq-rhel.sh
else
     set_tz
     echo "Executing  /root/install/install-prereq-sles.sh @ `date`" | tee -a ${HANA_LOG_FILE}
     /root/install/install-prereq-sles.sh
fi
