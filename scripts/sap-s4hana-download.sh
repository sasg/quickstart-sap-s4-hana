#!/bin/bash

source /root/install/config.sh

shift $((OPTIND-1))
[[ $# -gt 0 ]] && usage;

DOWNLOADLINK=https://${QSS3BucketName}.s3.amazonaws.com/${QSS3KeyPrefix}
DOWNLOADSTORAGE=https://${QSS3BucketName}.s3.amazonaws.com/${QSS3KeyPrefix}

# ------------------------------------------------------------------
#          Download all the scripts needed for HANA install
# ------------------------------------------------------------------

wget ${DOWNLOADLINK}submodules/quickstart-sap-hana/scripts/cluster-watch-engine.sh --output-document=/root/install/cluster-watch-engine.sh
wget ${DOWNLOADLINK}submodules/quickstart-sap-hana/scripts/install-prereq.sh --output-document=/root/install/install-prereq.sh
wget ${DOWNLOADLINK}submodules/quickstart-sap-hana/scripts/install-prereq-sles.sh --output-document=/root/install/install-prereq-sles.sh
wget ${DOWNLOADLINK}submodules/quickstart-sap-hana/scripts/install-prereq-rhel.sh --output-document=/root/install/install-prereq-rhel.sh
wget ${DOWNLOADLINK}submodules/quickstart-sap-hana/scripts/install-aws.sh --output-document=/root/install/install-aws.sh
wget ${DOWNLOADLINK}scripts/sap-s4hana-std-install-master.sh  --output-document=/root/install/sap-s4hana-std-install-master.sh
wget ${DOWNLOADLINK}scripts/sap-s4hana-std-install.sh  --output-document=/root/install/sap-s4hana-std-install.sh
wget ${DOWNLOADLINK}submodules/quickstart-sap-hana/scripts/install-hana-master.sh --output-document=/root/install/install-hana-master.sh
wget ${DOWNLOADLINK}submodules/quickstart-sap-hana/scripts/install-worker.sh --output-document=/root/install/install-worker.sh
wget ${DOWNLOADLINK}scripts/s4-std.params --output-document=/root/install/s4-std.params
wget ${DOWNLOADLINK}submodules/quickstart-sap-hana/scripts/install-hana-worker.sh --output-document=/root/install/install-hana-worker.sh
wget ${DOWNLOADLINK}submodules/quickstart-sap-hana/scripts/reconcile-ips.py --output-document=/root/install/reconcile-ips.py
wget ${DOWNLOADLINK}submodules/quickstart-sap-hana/scripts/reconcile-ips.sh --output-document=/root/install/reconcile-ips.sh
wget ${DOWNLOADLINK}submodules/quickstart-sap-hana/scripts/wait-for-master.sh --output-document=/root/install/wait-for-master.sh
wget ${DOWNLOADLINK}submodules/quickstart-sap-hana/scripts/wait-for-workers.sh --output-document=/root/install/wait-for-workers.sh
wget ${DOWNLOADLINK}submodules/quickstart-sap-hana/scripts/config.sh --output-document=/root/install/config.sh
wget ${DOWNLOADLINK}submodules/quickstart-sap-hana/scripts/cleanup.sh --output-document=/root/install/cleanup.sh
wget ${DOWNLOADLINK}submodules/quickstart-sap-hana/scripts/fence-cluster.sh --output-document=/root/install/fence-cluster.sh
wget ${DOWNLOADLINK}submodules/quickstart-sap-hana/scripts/signal-complete.sh --output-document=/root/install/signal-complete.sh
wget ${DOWNLOADLINK}submodules/quickstart-sap-hana/scripts/signal-failure.sh --output-document=/root/install/signal-failure.sh
wget ${DOWNLOADLINK}submodules/quickstart-sap-hana/scripts/interruptq.sh --output-document=/root/install/interruptq.sh
wget ${DOWNLOADLINK}submodules/quickstart-sap-hana/scripts/os.sh --output-document=/root/install/os.sh
wget ${DOWNLOADLINK}scripts/sap-s4hana-std-install-validate-install.sh --output-document=/root/install/sap-s4hana-std-install-validate-install.sh
wget ${DOWNLOADLINK}submodules/quickstart-sap-hana/scripts/signalFinalStatus.sh --output-document=/root/install/signalFinalStatus.sh
wget ${DOWNLOADLINK}submodules/quickstart-sap-hana/scripts/writeconfig.sh --output-document=/root/install/writeconfig.sh
wget ${DOWNLOADLINK}submodules/quickstart-sap-hana/scripts/create-attach-volume.sh --output-document=/root/install/create-attach-volume.sh
wget ${DOWNLOADLINK}submodules/quickstart-sap-hana/scripts/configureVol.sh --output-document=/root/install/configureVol.sh
wget ${DOWNLOADLINK}submodules/quickstart-sap-hana/scripts/create-attach-single-volume.sh --output-document=/root/install/create-attach-single-volume.sh
wget ${DOWNLOADLINK}submodules/quickstart-sap-hana/scripts/storage.json --output-document=/root/install/storage.json

for f in download_media.py extract.sh get_advancedoptions.py postprocess.py signal-precheck-failure.sh signal-precheck-status.sh signal-precheck-success.sh build_storage.py
do
    wget ${DOWNLOADLINK}submodules/quickstart-sap-hana/scripts/${f} --output-document=/root/install/${f}
done
