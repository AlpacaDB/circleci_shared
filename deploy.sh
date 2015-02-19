#!/bin/bash

# Template to deploy a component
# Needs to be parsed, and REPOSITORY renamed with the component name

# Exit on any error
set -e
cd

repo=REPOSITORY
service=$(echo $repo|tr '_' '-')

# Works with the certificate & docker login
docker push $EXTERNAL_REGISTRY_ENDPOINT/$repo:$CIRCLE_SHA1

internal_registry=$(./kubectl get --no-headers services registry-service| awk '{print $4}')
controller=$repo/cfg/$repo-controller.yml
sed -i "s/REGISTRY/$internal_registry/g" $controller
sed -i "s/VERSION/$CIRCLE_SHA1/g" $controller

old_controller_name=$(./kubectl get --no-headers -l "name=$service" \
    replicationControllers | grep version | awk '{print $1}')
if [[ -z "$old_controller_name" ]]
then
    ./kubectl create -f $repo/cfg/$repo-service.yml
    ./kubectl create -f $controller
else
    # This should work because of ./.kubeconfig and ~/.kubernetes_auth
    ./kubectl rollingupdate $old_controller_name -f $controller
fi
