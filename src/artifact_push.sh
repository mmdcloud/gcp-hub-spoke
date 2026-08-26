#!/bin/bash
mkdir code
cp -r ../src/* code/
cd code

gcloud auth configure-docker "${1}-docker.pkg.dev" --quiet

docker buildx build --tag nodeapp --file ./Dockerfile .
docker tag nodeapp:latest $1-docker.pkg.dev/$2/nodeapp/nodeapp:latest
docker push $1-docker.pkg.dev/$2/nodeapp/nodeapp:latest