# operator-scripts
Automation for testing CNV's operators

## Scripts

- Install using Marketplace:   `./marketplace-testing.sh`
- Install using OLM:           `./olm-testing.sh`
- Upgrade an installion:       `./upgrade.sh`
- Get a Quay.io token:         `./token.sh`
- Cleanup:                     `./cleanup.sh`

## Generic script to deploy operators to target cluster using OLM 

`olm-install.sh` is derivative of `cnv-2.1.0.sh` script with goal to facilitate automated deployment of any operator using OLM 

Variables:
```bash
# The Namespace and Version of CNV
TARGET_NAMESPACE="${TARGET_NAMESPACE:-openshift-cnv}"
CNV_VERSION="${CNV_VERSION:-2.1.0}"

WAIT_FOR_OBJECT_CREATION=${WAIT_FOR_OBJECT_CREATION:-60}

# Registry Auth
QUAY_TOKEN=${QUAY_TOKEN}
```
_QUAY_TOKEN_ can be generated using one of the following methods: 

1. From command line using base64 utility : ```echo "basic $(echo '${QUAY_USERNAME}:${QUAY_PASSWORD}' |base64 )"```
2. Get your pull secret from: https://cloud.redhat.com/openshift/install#pull-secret
```$ export TOKEN=$(cat <pull-secret-file> | jq -r .auths.\"quay.io\".auth)```
3. You can also get the token with a user and password:
```$ curl https://raw.githubusercontent.com/kubevirt/hyperconverged-cluster-operator/master/tools/token.sh | bash```

Variables can be defined in bash profile or added to `myenv.sh` file placed in the same directory as `olm-install.sh`. If file `myenv.sh` present, script will set variables from the file overriding default values. 

Script also allows to trigger operator driven application deployment once operator itself has been installed using kustomize feature of oc client. If ./kustomize/${OPERATOR_NAME}/ directory is present `olm-install.sh` script will first try to replace variables in `kustomization.yaml.templ` template creating kustomization.yaml file that will be used as a source for `oc apply -k` 