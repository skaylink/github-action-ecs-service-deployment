#!/bin/bash

set -e

if [ "${DEBUG:-0}" -eq 1 ]; then
    set -x
fi

# required variables
set -u
# redefine variables from ENV to prevent SC2154
# shellcheck disable=SC2153
service="${SERVICE}"
# shellcheck disable=SC2153
image="${IMAGE}"
# shellcheck disable=SC2153
url="${URL}"
set +u
# shellcheck disable=SC2153
token="${TOKEN}"
# shellcheck disable=SC2153
client_id="${CLIENT_ID}"
# shellcheck disable=SC2153
client_secret="${CLIENT_SECRET}"

if [[ -n "${token}" ]]; then
    _auth="x-api-key: ${token}"
fi

if [[ -z "${auth}" && (-n "$client_id" && -n "$client_secret") ]]; then
    oauth_result="$(curl \
        -s \
        "${url}/token" \
        -H "accept: application/json" \
        -H "Content-Type: application/json" \
        -o /tmp/result.json \
        -w "%{http_code}" \
        -d'{"client_id": "'"${client_id}"'", "client_secret": "'"${client_secret}"'"}')"
    if [ "${oauth_result}" -ne 201 ]; then
        printf "\n\e[1;31mUnable to login via OAuth\e[0m\n\n"
        echo ""
        jq . /tmp/result.json 2>/dev/null || cat /tmp/result.json | tee -a "${GITHUB_OUTPUT}"
        echo ""
        exit 1
    fi
    access_token="$(jq -r .access_token </tmp/result.json)"
    _auth="Authorization: Bearer ${access_token}"
fi

if [[ -z "${_auth}" ]]; then
    printf "\n\e[1;31mNo suitable authentication method found\e[0m\n\n"
    exit 1
fi

# optional variables
# shellcheck disable=SC2153
force="${FORCE}"
# shellcheck disable=SC2153
secret_arns="${SECRET_ARNS}"
# shellcheck disable=SC2153
detached="${DETACHED}"

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
    -s \
    -X "PATCH" \
    "${url}/v1/services/${service}" \
    -H "accept: application/json" \
    -H "${_auth}" \
    -H "Content-Type: application/json" \
    -o /tmp/result.json \
    -w "%{http_code}" \
    -d@/tmp/params.json)"
if [ "${deploy_result}" -ne 201 ]; then
    printf "\n\e[1;31mDeployment failed to start\e[0m\n\n"
    echo ""
    jq . /tmp/result.json 2>/dev/null || cat /tmp/result.json | tee -a "${GITHUB_OUTPUT}"
    echo ""
    exit 1
fi

### wait for deployment status
if [[ "${detached}" == "false" ]]; then
    while true; do
        status="$(curl \
            -s \
            --max-time 5 \
            -o /dev/null \
            -w "%{http_code}" \
            -H "${_auth}" "${url}/v1/services/${service}/")"
        if [ "${status}" -eq 202 ]; then
            printf "\n\e[0;36mDeployment in progress ...\e[0m\n\n"
            sleep 5
            continue
        fi
        if [ "${status}" -eq 200 ]; then
            printf "\n\e[1;32mDeployment succeeded\e[0m\n\n"
            exit 0
        fi
        printf "\n\e[1;31mDeployment failed\e[0m\n\n"
        exit 1
    done
fi
