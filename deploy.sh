#!/bin/bash

# Template to deploy a component
# Needs to be called with the component name

# Exit on any error
set -e
cd


if ! curl -s -k https://$KUBE_MASTER_IP &>/dev/null
then
    echo "No cluster is running, ignoring deploy"
    exit 0
fi

repo=$1
name=$(echo $repo|tr '_' '-')

# Works with the certificate & docker login
docker login -e $DOCKER_EMAIL -u $DOCKER_USER -p $DOCKER_PASS $EXTERNAL_REGISTRY_ENDPOINT
docker push $EXTERNAL_REGISTRY_ENDPOINT/$repo:$CIRCLE_SHA1

echo "Update controller registry & version"
internal_registry=$(./kubectl get --no-headers services registry-service| awk '{print $4}')
controller=~/$repo/cfg/$repo-controller.yml
sed -i "s/REGISTRY/$internal_registry/g" $controller
sed -i "s/VERSION/$CIRCLE_SHA1/g" $controller
service=~/$repo/cfg/$repo-service.yml

echo "get old controller name"
old_controller_name=$(./kubectl get --no-headers -l "name=$name" \
    replicationControllers | grep version | awk '{print $1}')


echo "update cluster"
message="*$repo*"   # message to send to slack
submessage=""
if [[ -z "$old_controller_name" ]]
then
    if [[ -f $service ]]; then
        ./kubectl create -f $service
        service_ip=$(./kubectl get services | grep logger | awk '{print $4}')
        submessage+=":new: service started [$service_ip]\n"
    fi
    ./kubectl create -f $controller
    submessage+=":new: controller created: $name -> $CIRCLE_SHA1"
elif [[ "$old_controller_name" == "$name-$CIRCLE_SHA1" ]]; then
    echo "The controller is already running under the same version. Ignoring"
    exit 0
else
    # This should work because of ./.kubeconfig and ~/.kubernetes_auth
    ./kubectl rollingupdate $old_controller_name -f $controller
    submessage+=":repeat_one: controller updated: $old_controller_name -> $name-$CIRCLE_SHA1"
fi
replicas=$(./kubectl get replicationControllers | grep skydns| awk '{print $5}')
message+=" [$replicas replicas]\n"
message+=$submessage


echo "Send notification to slack"
curl -X POST --data-urlencode 'payload={"channel": "#ops", "username": "KubeCI", "text": "'"$message"'", "icon_emoji": ":kube:"}' \
    https://hooks.slack.com/services/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
