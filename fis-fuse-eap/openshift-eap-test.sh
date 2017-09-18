#!/bin/bash

function cleanUp() {
    local APP=$1
    echo "====================> Deleting ${APP}"
    oc delete all -l "application=${APP}"
}

echo "====================> Deploying AMQ"
oc new-app amq63-basic -p IMAGE_STREAM_NAMESPACE=jboss-fuse -p MQ_USERNAME=admin123 -p MQ_PASSWORD=admin123

while ! oc get pods -l 'application=broker' | grep '1/1'; do
    echo "====================> Waiting for AMQ pod to become ready..."
    sleep 5
done

echo "====================> Deploying s2i-eap-camel-amq"
oc new-app s2i-eap-camel-amq -p IMAGE_STREAM_NAMESPACE=jboss-fuse -p MQ_USERNAME=admin123 -p MQ_PASSWORD=admin123

while ! oc get pods -l 'app=s2i-eap-camel-amq' | grep '1/1'; do
    echo "====================> Waiting for s2i-eap-camel-amq pod to become ready..."
    sleep 5
done

URL="http://$(oc get route s2i-eap-camel-amq | tail -n+2 | awk '{print $2}')/orders"

echo "====================> Connecting to ${URL}"
if [[ "$(curl -s -o /dev/null -w '%{http_code}' ${URL})" != "200" ]]; then
    echo "====================> HTTP status code was not 200"
    cleanUp "s2i-eap-camel-amq"
    cleanUp "broker"
    exit 1
fi

cleanUp "s2i-eap-camel-amq"
cleanUp "broker"

###########################################################

echo "====================> Deploying s2i-eap-camel-cdi"
oc new-app s2i-eap-camel-cdi -p IMAGE_STREAM_NAMESPACE=jboss-fuse

while ! oc get pods -l 'app=s2i-eap-camel-cdi' | grep '1/1'; do
    echo "====================> Waiting for s2i-eap-camel-cdi pod to become ready..."
    sleep 5
done

URL="http://$(oc get route s2i-eap-camel-cdi | tail -n+2 | awk '{print $2}')"

echo "====================> Connecting to ${URL}"
if [[ "$(curl -s -o /dev/null -w '%{http_code}' ${URL})" != "200" ]]; then
    echo "====================> HTTP status code was not 200"
    cleanUp "s2i-eap-camel-cdi"
    exit 1
fi

cleanUp "s2i-eap-camel-cdi"


###########################################################

echo "====================> Deploying s2i-eap-camel-cxf-jaxrs"
oc new-app s2i-eap-camel-cxf-jaxrs -p IMAGE_STREAM_NAMESPACE=jboss-fuse

while ! oc get pods -l 'app=s2i-eap-camel-cxf-jaxrs' | grep '1/1'; do
    echo "====================> Waiting for s2i-eap-camel-cxf-jaxrs pod to become ready..."
    sleep 5
done

URL="http://$(oc get route s2i-eap-camel-cxf-jaxrs | tail -n+2 | awk '{print $2}')"

echo "====================> Connecting to ${URL}"
if [[ "$(curl -s -o /dev/null -w '%{http_code}' ${URL})" != "200" ]]; then
    echo "====================> HTTP status code was not 200"
    cleanUp "s2i-eap-camel-cxf-jaxrs"
    exit 1
fi

cleanUp "s2i-eap-camel-cxf-jaxrs"

###########################################################

echo "====================> Deploying s2i-eap-camel-cxf-jaxws"
oc new-app s2i-eap-camel-cxf-jaxws -p IMAGE_STREAM_NAMESPACE=jboss-fuse

while ! oc get pods -l 'app=s2i-eap-camel-cxf-jaxws' | grep '1/1'; do
    echo "====================> Waiting for s2i-eap-camel-cxf-jaxws pod to become ready..."
    sleep 5
done

URL="http://$(oc get route s2i-eap-camel-cxf-jaxws | tail -n+2 | awk '{print $2}')"

echo "====================> Connecting to ${URL}"
if [[ "$(curl -s -o /dev/null -w '%{http_code}' ${URL})" != "200" ]]; then
    echo "====================> HTTP status code was not 200"
    cleanUp "s2i-eap-camel-cxf-jaxws"
    exit 1
fi

cleanUp "s2i-eap-camel-cxf-jaxws"

###########################################################

echo "====================> Deploying s2i-eap-camel-jpa"
oc new-app s2i-eap-camel-jpa -p IMAGE_STREAM_NAMESPACE=jboss-fuse -p DB_USERNAME=foo -p DB_PASSWORD=bar

while ! oc get pods -l 'app=s2i-eap-camel-jpa' | grep '1/1'; do
    echo "====================> Waiting for s2i-eap-camel-jpa pod to become ready..."
    sleep 5
done

URL="http://$(oc get route s2i-eap-camel-jpa | tail -n+2 | awk '{print $2}')/rest/api/books"

echo "====================> Connecting to ${URL}"
if [[ "$(curl -s -o /dev/null -w '%{http_code}' ${URL})" != "200" ]]; then
    echo "====================> HTTP status code was not 200"
    cleanUp "s2i-eap-camel-jpa"
    exit 1
fi

cleanUp "s2i-eap-camel-jpa"
