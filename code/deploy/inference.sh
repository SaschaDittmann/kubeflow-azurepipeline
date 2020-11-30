#!/bin/bash
set -euo pipefail
IFS=$'\n\t'
# -e: immediately exit if any command has a non-zero exit status
# -o: prevents errors in a pipeline from being masked
# IFS new value is less likely to cause confusing bugs when looping arrays or arguments (e.g. $@)

declare DEPLOYMENT_NAME=""
declare WORKSPACE=""
declare RESOURCE_GROUP=""

while getopts ":n:w:g:" arg; do
    case "${arg}" in
        n) DEPLOYMENT_NAME=${OPTARG};;
        w) WORKSPACE=${OPTARG};;
        g) RESOURCE_GROUP=${OPTARG};;
        ?) echo "Unknown option ${arg}";;
    esac
done
shift $((OPTIND-1))

echo "test the deployment with a taco image"
az ml service run -n ${DEPLOYMENT_NAME} -d '"https://c1.staticflickr.com/5/4022/4401140214_f489c708f0_b.jpg"' -w ${WORKSPACE} -g ${RESOURCE_GROUP}

echo "test the deployment with a burrito image"
az ml service run -n ${DEPLOYMENT_NAME} -d '"https://www.exploreveg.org/files/2015/05/sofritas-burrito.jpeg"' -w ${WORKSPACE} -g ${RESOURCE_GROUP}
