#!/bin/bash -x
# ------------------------------------------------------------------
#         Validate and Signal Completion or Failure of Wait Handle
# ------------------------------------------------------------------


SCRIPT_DIR=/root/install/
if [ -z "${HANA_LOG_FILE}" ] ; then
    HANA_LOG_FILE=${SCRIPT_DIR}/install.log
fi

log() {
    echo $* 2>&1 | tee -a ${HANA_LOG_FILE}
}

usage() {
    cat <<EOF
    Usage: $0 [WAIT-HANDLE]
EOF
    exit 0
}

source /root/install/config.sh

# ------------------------------------------------------------------
#          Read all inputs
# ------------------------------------------------------------------


[[ $# -ne 1 ]] && usage;

SIGNAL=$*

function success() {
	log `date` "sh /root/install/signal-complete.sh ${SIGNAL}"
	sh /root/install/signal-complete.sh
	exit 0;
}

function failure() {
	log `date` "sh /root/install/signal-failure.sh HANAINSTALLFAIL "
	sh /root/install/signal-failure.sh "HANAINSTALLFAIL"
	exit 1
}




log `date` START validate-install

if [ "${INSTALL_HANA}" == "No" ]; then
    echo "INSTALL_HANA set to no, will pass through validation check"
    success;
    exit 0
fi


HANAS3Bucket=$(/usr/local/bin/aws cloudformation describe-stacks --stack-name ${MyStackId}  --region ${REGION}  \
				| /root/install/jq '.Stacks[0].Parameters[] | select(.ParameterKey=="HANAInstallMedia") | .ParameterValue' \
				| sed 's/"//g')
HANAS3BucketLen=${#HANAS3Bucket} 
if (( ${HANAS3BucketLen} < 4 )); then
    echo "HANAS3BucketLen is ${HANAS3BucketLen} < 4. Bypass validation to avoid empty/invalid strings"
    success;
    exit 0
fi


SAPCONTROL=$(find /usr/sap/ -type f -name sapcontrol | grep host)
[ ! -f "$SAPCONTROL" ] && failure;

_SAP_UP=$(ps -ef | grep dw.sap${SAP_SID} | grep -v grep | wc -l )

if [ "$_SAP_UP" -eq 0 ]
then
	echo "${p}: NOT RUNNING: FAILURE"
	failure;
else
	echo "${p}: RUNNING OKAY"
fi

log `date` "SAP INSTALLATION VALIDATED"
success;
log `date` END validate-install



exit 0








