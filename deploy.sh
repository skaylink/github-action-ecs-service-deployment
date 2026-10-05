#!/bin/bash

set -e

if [ "${DEBUG:-0}" -eq 1 ]; then
    set -x
fi

# required variables
set -u
# redefine variables from ENV to prevent SC2154
# shellcheck disable=SC2153
image="${IMAGE}"
# shellcheck disable=SC2153
url="${URL}"
set +u
# shellcheck disable=SC2153
service="${SERVICE}"
# shellcheck disable=SC2153
task="${TASK}"
# shellcheck disable=SC2153
token="${TOKEN}"
# shellcheck disable=SC2153
client_id="${CLIENT_ID}"
# shellcheck disable=SC2153
client_secret="${CLIENT_SECRET}"

# optional variables
# shellcheck disable=SC2153
force="${FORCE}"
# shellcheck disable=SC2153
secret_arns="${SECRET_ARNS}"
# shellcheck disable=SC2153
schedule_expression="${SCHEDULE_EXPRESSION}"
# shellcheck disable=SC2153
detached="${DETACHED}"
# shellcheck disable=SC2153
timeout="${TIMEOUT:-10}"

### determine deployment target (service or task)
if [[ -n "${service}" && -z "${task}" ]]; then
    endpoint="${url}/v1/services/${service}"
    if [[ -n "${schedule_expression}" ]]; then
        printf "\n\e[1;31mschedule_expression is only supported for tasks\e[0m\n\n"
        exit 1
    fi
elif [[ -n "${task}" && -z "${service}" ]]; then
    endpoint="${url}/v1/tasks/${task}"
    if [[ -n "${secret_arns}" ]]; then
        printf "\n\e[1;31msecret_arns is only supported for services\e[0m\n\n"
        exit 1
    fi
else
    printf "\n\e[1;31mExactly one of service or task is required\e[0m\n\n"
    exit 1
fi

### authentication
if [[ -n "${token}" ]]; then
    _auth="x-api-key: ${token}"
fi

if [[ -z "${_auth}" && (-n "$client_id" && -n "$client_secret") ]]; then
    jo -o /tmp/token.json client_id="${client_id}" client_secret="${client_secret}"
    oauth_result="$(curl \
        -s \
        "${url}/token" \
        -H "accept: application/json" \
        -H "Content-Type: application/json" \
        -o /tmp/result.json \
        -w "%{http_code}" \
        -d@/tmp/token.json)"
    rm -f /tmp/token.json
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

### build request body
params=(image="${image}" force="${force}")
if [[ -n "${service}" ]]; then
    if [[ -n "${secret_arns}" ]]; then
        IFS=',' read -r -a _secret_arns <<<"${secret_arns}"
        jo -o /tmp/secret_arns.json -a "${_secret_arns[@]}"
    else
        echo "[]" >/tmp/secret_arns.json
    fi
    params+=(secret_arns=:/tmp/secret_arns.json)
elif [[ -n "${schedule_expression}" ]]; then
    params+=(schedule_expression="${schedule_expression}")
fi
jo -o /tmp/params.json "${params[@]}"

### start deployment
printf "\n\e[1;36mCreating deployment ...\e[0m\n\n"
deploy_result="$(curl \
    -s \
    -X "PATCH" \
    "${endpoint}" \
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
            --max-time "${timeout}" \
            -o /dev/null \
            -w "%{http_code}" \
            -H "${_auth}" "${endpoint}")"
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
