#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# -e: immediately exit if any command has a non-zero exit status
# -o: prevents errors in a pipeline from being masked
# IFS new value is less likely to cause confusing bugs when looping arrays or arguments (e.g. $@)

usage() { echo "Usage: $0 -n <kubernetesNamespace>" 1>&2; exit 1; }

declare kubernetesNamespace="anonymous"

# Initialize parameters specified from command line
while getopts ":r:h" arg; do
	case "${arg}" in
		n)
			kubernetesNamespace=${OPTARG}
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

if [[ -z "$kubernetesNamespace" ]]; then
	echo "Enter a name for the Kubernetes Namespace:"
	read kubernetesNamespace
	[[ "${kubernetesNamespace:?}" ]]
fi

if [ -z "$kubernetesNamespace" ]; then
	echo "Either one of kubernetesNamespace is empty"
	usage
fi

set +e

kubectl apply -f kubernetes/kale-notebooks.yaml -n $kubernetesNamespace

