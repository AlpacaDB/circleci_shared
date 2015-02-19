#!/bin/bash

# Template to install dependencies
# Needs to be called with the component name

repo=$1
mv * ~/$repo/dockerfiles/
cd ~/$repo/dockerfiles/

# Move src code to current dir
mv ../src/ .

# Clone etl_shared
git clone git@github.com:AlpacaDB/etl_shared.git
cd etl_shared && git checkout $GIT_BRANCH && cd ..

# Connect to remove docker registry
sudo cp registry.crt /usr/local/share/ca-certificates
sudo update-ca-certificates
sudo service docker restart
docker login -e $DOCKER_EMAIL -u $DOCKER_USER -p $DOCKER_PASS $EXTERNAL_REGISTRY_ENDPOINT

# Build repository
docker pull $EXTERNAL_REGISTRY_ENDPOINT/$repo
docker build -t $EXTERNAL_REGISTRY_ENDPOINT/$repo:$CIRCLE_SHA1 .

# Connect to remote kubernetes apiserver
wget https://storage.googleapis.com/kubernetes-release/release/v0.9.1/bin/linux/amd64/kubectl -O ~/kubectl
chmod +x ~/kubectl
cp kubeconfig ~/.kubeconfig
chmod +x deploy.sh
envsubst < ./kubernetes_auth.template > /home/ubuntu/.kubernetes_auth
