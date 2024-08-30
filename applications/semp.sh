# bin/bash

### module options
enable_distributed_tracing=true


### Global Variables!

admin="admin:admin"
server="http://localhost:8080"
vpn="default"
default_profile="default"

semp=$server"/SEMP/v2"
semp_config=$semp"/config"
semp_vpn=$semp_config"/msgVpns/"$vpn


### Functions

print_http_status() {

    WARN='\033[1;31m'
    GOOD='\033[0;32m'
    NORM='\033[0m'

    if [[ "$1" -ne 200 ]] ; then
        echo "${WARN}$1${NORM}"
    else
        echo "${GOOD}$1${NORM}"
    fi
}

semp() {
    local verb=${1}
    local endpoint=${2}
    local payload=${3}
    
    status=$(curl -ks -w "%{http_code}" -o /dev/null -u $admin -X $verb $endpoint -H "Content-Type: application/json" -H "Accept: application/json" -d "$payload")
    print_http_status $status
}

patch_semp() {
    local endpoint=${1}
    local payload=${2}

    semp "PATCH" ${endpoint} "$payload"
}

post_config() {
    local endpoint=${1}
    local payload=${2}

    semp "POST" ${semp_config}${endpoint} "$payload"
}

post_semp() {
    local endpoint=${1}
    local payload=${2}

    semp "POST" ${semp_vpn}${endpoint} "$payload"
}

create_queue() {
    printf "Creating queue ${1}...  "
    post_semp "/queues" \
              '{
                    "queueName": "'${1}'",
                    "egressEnabled": true,
                    "ingressEnabled": true,
                    "maxMsgSpoolUsage": '${2:-5000}',
                    "permission": "consume"
               }'
}

create_queue_subscription() {
    printf "Adding subscription ${2} to ${1}...  "
    post_semp "/queues/${1}/subscriptions" \
              '{
                    "subscriptionTopic": "'$2'"
               }'
}

create_acl_profile() {
    printf "Creating ACL profile ${1}...  "
    post_semp "/aclProfiles" \
              '{ 
                    "aclProfileName": "'$1'",
                    "clientConnectDefaultAction": "'$2'",
                    "publishTopicDefaultAction": "'$3'",
                    "subscribeShareNameDefaultAction": "'$4'",
                    "subscribeTopicDefaultAction": "'$5'"
                }'
}

create_client_profile() {
    printf "Creating client profile ${1}...  "
    post_semp "/clientProfiles" \
              '{ 
                    "clientProfileName": "'$1'",
                    "allowGuaranteedEndpointCreateDurability": "all",
                    "allowGuaranteedMsgReceiveEnabled": true,
                    "allowGuaranteedMsgSendEnabled": true,
                    "rejectMsgToSenderOnNoSubscriptionMatchEnabled": '$2'
               }'
}

create_client_username() {
    printf "Creating client username ${1}...  "
    post_semp "/clientUsernames" \
              '{ 
                    "clientUsername": "'$1'",
                    "password": "'$2'",
                    "aclProfileName": "'$3'",
                    "clientProfileName": "'$4'",
                    "enabled": true
               }'
}


### Actual calls


echo
printf "Waiting for PubSub+ to come online"
until [ \
  "$(curl -ks -w '%{http_code}' -o /dev/null -u $admin $semp/monitor/)" -eq 200 ]
do
  printf "."
  sleep 1  # retry in 1 second
done
printf "\n\n"


##### Initialize

printf "Set System Max Spool Usage...  "
patch_semp $semp_config '{ "guaranteedMsgingMaxMsgSpoolUsage": 15000 }'

printf "Set Max Message Spool and Authentication Type...  "
patch_semp $semp_vpn '{ "authenticationBasicType": "internal", "maxMsgSpoolUsage": 15000 }'
echo

printf "Set Default User Password...  "
patch_semp "$semp_vpn/clientUsernames/$default_profile" '{ "password": "default" }'

printf "Set default user client profile...  "
patch_semp "$semp_vpn/clientProfiles/$default_profile" \
           '{ 
                "allowGuaranteedMsgReceiveEnabled": true,
                "allowGuaranteedMsgSendEnabled": true
            }'
echo


##### Distributed Tracing

if [ "$enable_distributed_tracing" = true ]; then

otel_profile="trace"
queue="q"

printf "Create telemetry profile...  "
post_semp "/telemetryProfiles" \
          '{
                "msgVpnName": "'$vpn'",
                "receiverAclConnectDefaultAction": "allow",
                "receiverEnabled": true,
                "telemetryProfileName": "'$otel_profile'",
                "traceEnabled": true
           }'

printf "Create trace filter...  "
post_semp "/telemetryProfiles/$otel_profile/traceFilters" \
          '{ 
                "enabled": true,
                "traceFilterName": "default"
           }'

printf "Create trace filter subscription...  "
post_semp "/telemetryProfiles/$otel_profile/traceFilters/default/subscriptions" \
          '{ 
                "subscription": ">",
                "subscriptionSyntax": "smf"
           }'
echo

create_client_username "trace" "trace" "#telemetry-trace" "#telemetry-trace"

# Create Queue

create_queue $queue
create_queue_subscription $queue "solace/tracing"
echo

fi
