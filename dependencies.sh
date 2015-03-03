#!/bin/bash

# Template to install dependencies
# Needs to be called with the component name

repo=$1
mv circleci_shared/* .

# Connect to remove docker registry
sudo cp registry.crt /usr/local/share/ca-certificates
sudo update-ca-certificates
sudo service docker restart
docker login -e $DOCKER_EMAIL -u $DOCKER_USER -p $DOCKER_PASS $EXTERNAL_REGISTRY_ENDPOINT

# Build docker image
./make build
# Create tag for the docker image
docker tag $repo $EXTERNAL_REGISTRY_ENDPOINT/$repo:$CIRCLE_SHA1

# Connect to remote kubernetes apiserver
wget https://storage.googleapis.com/kubernetes-release/release/v0.9.1/bin/linux/amd64/kubectl -O ~/kubectl
chmod +x ~/kubectl
cp kubeconfig ~/.kubeconfig
chmod +x deploy.sh
mv apiserver* /srv/
envsubst < ./kubernetes_auth.template > /home/ubuntu/.kubernetes_auth
