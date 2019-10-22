#!/bin/bash

set -ex

globalNamespace=`oc -n openshift-operator-lifecycle-manager get deployments catalog-operator -o jsonpath='{.spec.template.spec.containers[].args[1]}'`
echo "Global Namespace: ${globalNamespace}"

TARGET_NAMESPACE="${TARGET_NAMESPACE:-openshift-cnv}"
MARKETPLACE_NAMESPACE="${MARKETPLACE_NAMESPACE:-$globalNamespace}"
HCO_BUNDLE_REGISTRY_TAG="${HCO_BUNDLE_REGISTRY_TAG:-v2.1.0}"  # Setting to latest
POD_TIMEOUT="${POD_TIMEOUT:-360s}"
CHANNEL="${CHANNEL:-2.1}"
CNV_VERSION="${CNV_VERSION:-2.1.0}"
CNV_CHANNEL="${CNV_VERSION:0:3}"

# Use overides in the future
# https://github.com/openshift/cluster-version-operator/blob/master/docs/dev/clusterversion.md#setting-objects-unmanaged
oc scale --replicas 0 -n openshift-cluster-version deployments/cluster-version-operator

echo "Let the CVO scale down..."
sleep 10

oc delete operatorsource redhat-operators -n openshift-marketplace || true

# Create the namespace for the HCO
oc create ns $TARGET_NAMESPACE || true

# Create an OperatorGroup
cat <<EOF | oc create -f -
apiVersion: operators.coreos.com/v1alpha2
kind: OperatorGroup
metadata:
  name: hco-operatorgroup
  namespace: "${TARGET_NAMESPACE}"
EOF

# Create a Catalog Source backed by a grpc registry
cat <<EOF | oc create -f -
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: hco-catalogsource
  namespace: "${MARKETPLACE_NAMESPACE}"
  imagePullPolicy: Always
spec:
  sourceType: grpc
  image: registry-proxy.engineering.redhat.com/rh-osbs/container-native-virtualization-hco-bundle-registry:${HCO_BUNDLE_REGISTRY_TAG}
  displayName: KubeVirt HyperConverged
  publisher: Red Hat
EOF

echo "Waiting up to ${POD_TIMEOUT} for catalogsource to appear..."
sleep 5
oc wait pods -n "${MARKETPLACE_NAMESPACE}" -l olm.catalogSource=hco-catalogsource --for condition=Ready --timeout="${POD_TIMEOUT}"

# Create a subscription
cat <<EOF | oc create -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: hco-subscription
  namespace: "${TARGET_NAMESPACE}"
spec:
  source: hco-catalogsource
  sourceNamespace: "${MARKETPLACE_NAMESPACE}"
  name: kubevirt-hyperconverged
  startingCSV: "kubevirt-hyperconverged-operator.v${CNV_VERSION}"
  channel: "${CNV_CHANNEL}"
  installPlanApproval: Manual
EOF

echo "Give the operators some time to start..."
sleep ${OPERATORS_SLEEP:=60}

oc get installplan -o yaml -n "${TARGET_NAMESPACE}" $(oc get installplan -n "${TARGET_NAMESPACE}" --no-headers | grep kubevirt-hyperconverged-operator.v"${CNV_VERSION}" | awk '{print $1}') | sed 's/approved: false/approved: true/' | oc apply -n "${TARGET_NAMESPACE}" -f -

echo "Give OLM 60 seconds to process the installplan..."
sleep 60

VIRT_POD=`oc get pods -n "${TARGET_NAMESPACE}" | grep virt-operator | head -1 | awk '{ print $1 }'`
CDI_POD=`oc get pods -n "${TARGET_NAMESPACE}" | grep cdi-operator | head -1 | awk '{ print $1 }'`
NETWORK_ADDONS_POD=`oc get pods -n "${TARGET_NAMESPACE}" | grep cluster-network-addons-operator | head -1 | awk '{ print $1 }'`
oc wait pod $VIRT_POD --for condition=Ready -n "${TARGET_NAMESPACE}" --timeout="${POD_TIMEOUT}"
oc wait pod $CDI_POD --for condition=Ready -n "${TARGET_NAMESPACE}" --timeout="${POD_TIMEOUT}"
oc wait pod $NETWORK_ADDONS_POD --for condition=Ready -n "${TARGET_NAMESPACE}" --timeout="${POD_TIMEOUT}"

echo "Launching CNV..."
cat <<EOF | oc create -f -
apiVersion: hco.kubevirt.io/v1alpha1
kind: HyperConverged
metadata:
  name: hyperconverged-cluster
  namespace: "${TARGET_NAMESPACE}"
EOF
