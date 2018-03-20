#!/bin/bash

PROJECT=$1
FROM_TAG=$2
TO_TAG=$3
WFC_VERSION=$4
VERSION=${3:23}

if [[ $# -ne 4 ]]; then
    echo "Usage make-tag.sh <project dir> <from tag name> <to tag name> <wildfly-camel version>"
fi

pushd ${PROJECT} > /dev/null

git reset --hard HEAD
git checkout master
git branch -D temp-${TO_TAG} > /dev/null
git fetch --tags > /dev/null
git tag -d ${TO_TAG} > /dev/null
git checkout -b temp-${TO_TAG} ${FROM_TAG} > /dev/null

mvn versions:set -DnewVersion=${VERSION}
if [[ "$?" != "0" ]]; then
    echo "Problem changing project version"
    popd
    exit 1
fi

mvn versions:commit
if [[ "$?" != "0" ]]; then
    echo "Problem committing project version"
    popd
    exit 1
fi

sed -i "s/<\(version.wildfly.camel\)>.*<\/\1>/<\1>${WFC_VERSION}<\/\1>/g" pom.xml
if [[ "$?" != "0" ]]; then
    echo "Problem updating version.wildfly.camel property"
    popd
    exit 1
fi

curl -S -L https://gist.githubusercontent.com/jamesnetherton/d0073a08b46590724da9b6a57193298c/raw/afe154fd9c9f7abfb8bbce99d7e3e58d6b3fc557/rh-settings.xml > /tmp/settings.xml
if [[ "$?" == "0" ]]; then
    for SETTINGS_XML in $(find . -name settings.xml)
    do
        cp /tmp/settings.xml ${SETTINGS_XML}
    done
else
    echo "Problem downloading settings.xml file"
    exit 1
fi

AUTHOR=$(echo $(git --no-pager log -1 | grep Author | cut -f2 -d:))
DATE=$(echo $(echo $(git --no-pager log -1 --pretty=%ad)))
MESSAGE=$(echo $(git --no-pager log -1 --pretty=%B))

git commit -am "WIP"
git reset --soft HEAD~2
git commit -m "${MESSAGE}" --author="${AUTHOR}" --date="${DATE}"

if [[ "$?" != "0" ]]; then
    echo "Problem committing changes"
    exit 1
    popd
fi

git tag ${TO_TAG}

popd
