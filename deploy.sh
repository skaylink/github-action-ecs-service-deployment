#!/bin/bash

set -e

# required variables
set -u
# redefine variables from ENV to prevent SC2154
# shellcheck disable=SC2153
service="${SERVICE}"
# shellcheck disable=SC2153
image="${IMAGE}"
# shellcheck disable=SC2153
token="${TOKEN}"
# shellcheck disable=SC2153
url="${URL}"
set +u

# optional variables
# shellcheck disable=SC2153
force="${FORCE}"
# shellcheck disable=SC2153
secret_arns="${SECRET_ARNS}"
# shellcheck disable=SC2153
detached="${DETACHED}"

printf "\n\e[1;36mPreparing upload ...\e[0m\n\n"

### start deployment
printf "\n\e[1;36mCreating deployment ...\e[0m\n\n"
if [[ -n "${secret_arns}" ]]; then
    IFS=',' read -r -a _secret_arns <<<"${secret_arns}"
    # shellcheck disable=SC2048,SC2068
    jo -o /tmp/secret_arns.json -a ${_secret_arns[@]}
else
    echo "[]" >/tmp/secret_arns.json
fi

jo -o /tmp/params.json image="${image}" force="${force}" secret_arns=:/tmp/secret_arns.json

deploy_result="$(curl \
    -sf \
    -X "PATCH" \
    "${url}/v1/services/${service}" \
    -H "accept: application/json" \
    -H "x-api-token: ${token}" \
    -H "Content-Type: application/json" \
    -o /tmp/result.json \
    -w "%{http_code}" \
    -d@/tmp/params.json)"
if [ "${deploy_result}" -ne 201 ]; then
    printf "\n\e[1;31mDeployment failed ...\e[0m\n\n"
    jq -C . /tmp/result.json
    exit 1
fi

### wait for deployment status
if [[ "${detached}" == "false" ]]; then
    while true; do
        status="$(curl \
            -sf \
            --max-time 5 \
            -o /dev/null \
            -w "%{http_code}" \
            -H "x-api-token: ${token}" "${url}/v1/services/${service}/")"
        if [ "${status}" -ne 202 ]; then
            printf "\n\e[0;36mDeployment in progress ...\e[0m\n\n"
            sleep 5
            continue
        fi
        if [ "${status}" -eq 200 ]; then
            printf "\n\e[1;32mDeployment succeeded ...\e[0m\n\n"
            exit 0
        fi
        printf "\n\e[1;31mDeployment failed ...\e[0m\n\n"
        exit 1
    done
fi
