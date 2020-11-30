#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
# -e: immediately exit if any command has a non-zero exit status
# -o: prevents errors in a pipeline from being masked
# IFS new value is less likely to cause confusing bugs when looping arrays or arguments (e.g. $@)

declare DEPLOYMENT_NAME=""
declare ENTRY_SCRIPT="/scripts/score.py"
declare SERVICE_PRINCIPAL_ID=""
declare SERVICE_PRINCIPAL_PASSWORD=""
declare SUBSCRIPTION_ID=""
declare RESOURCE_GROUP=""
declare WORKSPACE=""
declare TENANT_ID=""
declare BASE_PATH="/mnt/azure"
declare DEPLOYMENT_CONFIG=""

while getopts ":n:e:s:p:u:r:w:t:b:d:" arg; do
    case "${arg}" in
        n) DEPLOYMENT_NAME=${OPTARG};;
        e) ENTRY_SCRIPT=${OPTARG};;
        s) SERVICE_PRINCIPAL_ID=${OPTARG};;
        p) SERVICE_PRINCIPAL_PASSWORD=${OPTARG};;
        u) SUBSCRIPTION_ID=${OPTARG};;
        r) RESOURCE_GROUP=${OPTARG};;
        w) WORKSPACE=${OPTARG};;
        t) TENANT_ID=${OPTARG};;
        b) BASE_PATH=${OPTARG};;
        d) DEPLOYMENT_CONFIG=${OPTARG};;
        ?) echo "Unknown option ${arg}";;
    esac
done
shift $((OPTIND-1))

echo "DEPLOYMENT_NAME => ${DEPLOYMENT_NAME}"
echo "ENTRY_SCRIPT => ${ENTRY_SCRIPT}"
echo "SERVICE_PRINCIPAL_ID => ${SERVICE_PRINCIPAL_ID}"
echo "SUBSCRIPTION_ID => ${SUBSCRIPTION_ID}"
echo "RESOURCE_GROUP => ${RESOURCE_GROUP}"
echo "WORKSPACE => ${WORKSPACE}"
echo "TENANT_ID => ${TENANT_ID}"
echo "DEPLOYMENT_CONFIG => ${DEPLOYMENT_CONFIG}"
echo "BASE_PATH => ${BASE_PATH}"

az login --service-principal --username ${SERVICE_PRINCIPAL_ID} --password ${SERVICE_PRINCIPAL_PASSWORD} -t $TENANT_ID

if [ -f "${BASE_PATH}/environment.json" ]; then
    echo "environment already registered, skipping"
else
    az ml environment register -g $RESOURCE_GROUP -w $WORKSPACE -d /scripts/env -t environment.json
    mv environment.json ${BASE_PATH}/environment.json
fi

az ml model deploy -n $DEPLOYMENT_NAME \
    -w $WORKSPACE -g $RESOURCE_GROUP \
    -f ${BASE_PATH}/model.json --es ${ENTRY_SCRIPT} \
    -e $(jq -r '.name' ${BASE_PATH}/environment.json) \
    --ev $(jq -r '.version' ${BASE_PATH}/environment.json) \
    --pi ${BASE_PATH}/myprofileresult.json \
    --dc ${DEPLOYMENT_CONFIG} \
    --overwrite -v
