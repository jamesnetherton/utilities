#!/bin/bash


function buildAndPush() {
    local image=$1

    pushd /home/james/Projects/git/fork/s2i/${image}

    fish-pepper

    pushd /home/james/Projects/git/fork/s2i/${image}/images/rhel

    docker build -t 192.168.1.245:5000/jboss-fuse-7/fuse-${image}-openshift:1.0 .
    docker push 192.168.1.245:5000/jboss-fuse-7/fuse-${image}-openshift:1.0

    popd
    popd
}

for type in java karaf; do
    buildAndPush ${type}
done

oc delete is --all
oc apply -f fuse-7-dev-image-streams.json
