#!/bin/bash

oc login -u developer -p developer https://$(minishift ip):8443
if ! oc status | grep "192." > /dev/null
then
    echo "oc is not pointing at local server"
    exit 1
fi

oc new-project jboss-fuse
oc apply -f ./fis-dev-imagestreams.json
oc apply -f https://raw.githubusercontent.com/jboss-openshift/application-templates/master/jboss-image-streams.json
oc apply -f https://raw.githubusercontent.com/jboss-openshift/application-templates/master/amq/amq63-basic.json

for TEMPLATE in $(ls ~/Projects/git/master/application-templates/quickstarts/eap*)
do
    oc apply -f ${TEMPLATE}
done

oc import-image mysql:5.7 --from=registry.access.redhat.com/rhscl/mysql-57-rhel7 --confirm
