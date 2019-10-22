#!/bin/bash

set -ex

CNV_VERSION="${CNV_VERSION:-2.1.0}"
TARGET_NAMESPACE="${TARGET_NAMESPACE:-openshift-cnv}"

upgrade_ip=$(oc get installplan -n ${TARGET_NAMESPACE} --no-headers | grep -v alpha | grep kubevirt-hyperconverged-operator.v${CNV_VERSION} | awk '{print $1}')
oc get installplan -o yaml -n ${TARGET_NAMESPACE} ${upgrade_ip} | sed 's/approved: false/approved: true/' | oc apply -n openshift-cnv -f -

echo "Waiting for the installplan to reach complete status"
echo "This could take up to 10 minutes..."

while [ -z "$(oc get installplan -n ${TARGET_NAMESPACE} ${upgrade_ip} -o=jsonpath={.status.phase} | grep Complete)" ]; do
    echo "Waiting for ${upgrade_ip} InstallPlan to be in 'Complete'..."
    sleep 10
done
