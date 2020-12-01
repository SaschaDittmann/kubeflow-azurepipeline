#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# -e: immediately exit if any command has a non-zero exit status
# -o: prevents errors in a pipeline from being masked
# IFS new value is less likely to cause confusing bugs when looping arrays or arguments (e.g. $@)

usage() { echo "Usage: $0 -s <subscriptionId> -g <resourceGroupName> -n <kubernetesNamespace> -w <amlWorkspace>" 1>&2; exit 1; }

declare subscriptionId=""
declare resourceGroupName=""
declare kubernetesNamespace="anonymous"
declare amlWorkspace=""

if [ -f "logs/aks.json" ]; then
	resourceGroupName=$(jq -r '.resourceGroup' logs/aks.json)
fi
if [ -f "logs/spn.json" ]; then
	tenant=$(jq -r '.tenant' logs/spn.json)
	appId=$(jq -r '.appId' logs/spn.json)
    appPassword=$(jq -r '.password' logs/spn.json)
fi
if [ -f "logs/aml-workspace.json" ]; then
	amlWorkspace=$(jq -r '.friendlyName' logs/aml-workspace.json)
fi

# Initialize parameters specified from command line
while getopts ":s:g:r:w:h" arg; do
	case "${arg}" in
		s)
			subscriptionId=${OPTARG}
			;;
		g)
			resourceGroupName=${OPTARG}
			;;
		n)
			kubernetesNamespace=${OPTARG}
			;;
		w)
			amlWorkspace=${OPTARG}
			;;
		h)
			usage
			;;
		?) 
			echo "Unknown option ${arg}"
			;;
		esac
done
shift $((OPTIND-1))

#Prompt for parameters is some required parameters are missing
if [[ -z "$subscriptionId" ]]; then
	echo "Your subscription ID can be looked up with the CLI using: az account show --out json "
	echo "Enter your subscription ID:"
	read subscriptionId
	[[ "${subscriptionId:?}" ]]
fi

if [[ -z "$resourceGroupName" ]]; then
	echo "This script will look for an existing resource group, otherwise a new one will be created "
	echo "You can create new resource groups with the CLI using: az group create "
	echo "Enter a resource group name"
	read resourceGroupName
	[[ "${resourceGroupName:?}" ]]
fi

if [[ -z "$kubernetesNamespace" ]]; then
	echo "Enter a name for the Kubernetes Namespace:"
	read kubernetesNamespace
	[[ "${kubernetesNamespace:?}" ]]
fi

if [[ -z "$amlWorkspace" ]]; then
	echo "Enter a name for the Azure ML Workspace:"
	read amlWorkspace
	[[ "${amlWorkspace:?}" ]]
fi

if [ -z "$subscriptionId" ] || [ -z "$resourceGroupName" ] || [ -z "$kubernetesNamespace" ] || [ -z "$amlWorkspace" ]; then
	echo "Either one of subscriptionId, resourceGroupName, kubernetesNamespace, amlWorkspace is empty"
	usage
fi

#login to azure using your credentials
az account show 1> /dev/null

if [ $? != 0 ];
then
	az login
fi

#set the default subscription id
az account set --subscription $subscriptionId

set +e

#Check for existing RG
az group show --name $resourceGroupName 1> /dev/null

kubectl apply -f kubernetes/pvc-azuremanageddisk.yaml -n $kubernetesNamespace
kubectl apply -f kubernetes/pvc-azurefiles.yaml -n $kubernetesNamespace

cat kubernetes/pipeline.yaml | \
	sed "s/<tenant_id>/${tenant}/g" | \
	sed "s/<service_principal_id>/${appId}/g" | \
	sed "s/<service_principal_password>/${appPassword}/g" | \
	sed "s/<subscription_id>/${subscriptionId}/g" | \
	sed "s/<resource_group>/${resourceGroupName}/g" | \
	sed "s/<ml_workspace_name>/${amlWorkspace}/g" | \
	kubectl create -n $kubernetesNamespace -f -
