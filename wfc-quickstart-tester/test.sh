#!/bin/bash

AMQ=~/Applications/apache-activemq-5.15.3
WF_VERSION=wildfly-11.0.0.Final
WFC_VERSION=5.1.0
SERVER=${WF_VERSION}.tar.gz
PATCH=~/.m2/repository/org/wildfly/camel/wildfly-camel-patch/${WFC_VERSION}/wildfly-camel-patch-${WFC_VERSION}.tar.gz
BRANCH=master
JBOSS_HOME=~/Desktop/wfce-tests/
CONFIG="standalone-full-camel.xml"
SOURCE=~/Projects/git/fork/wildfly-camel-examples
PID=""
DIR=$PWD

trap cleanup SIGHUP SIGINT SIGTERM

function cleanup() {
    kill -9 $(ps -ef | grep standalone | grep -v grep | awk '{print $2}') > /dev/null
    cd ${DIR}
}

if [[ "$1" == "--eap" ]]; then
    SERVER=wildfly-dist-7.1.1.GA-redhat-2.tar.gz
    SOURCE=~/Projects/git/master/wildfly-camel-examples
    WF_VERSION=jboss-eap-7.1
    WFC_VERSION=5.1.0.fuse-SNAPSHOT
    BRANCH=5.x-redhat
    CONFIG="standalone-full.xml"
fi

cd ~/Desktop
rm -rf ${JBOSS_HOME}
mkdir -p ${JBOSS_HOME}
cd ${JBOSS_HOME}
cp ~/Applications/${SERVER} .

tar xvfz ${SERVER} -C ${JBOSS_HOME}
if [[ "$?" != "0" ]]; then
    echo "Server installation failed"
    cleanup
    exit 1
fi

JBOSS_HOME=${JBOSS_HOME}/${WF_VERSION}


if [[ "$1" == "--eap" ]]; then
    java -jar ~/Downloads/fuse-eap-installer-7.0.0.fuse-000060.jar ${JBOSS_HOME}
else
    tar xvfz ${PATCH} -C ${JBOSS_HOME}
fi

if [[ "$?" != "0" ]]; then
    echo "Patch installation failed"
    cleanup
    exit 1
fi

echo "${JBOSS_HOME}/bin/standalone.sh -bmanagement 0.0.0.0 -c ${CONFIG}"

while ! pgrep standalone
do
    echo "Waiting for server start..."
    sleep 10
done

sleep 60

cd ${SOURCE}
mvn clean package -pl \!itests -pl \!distro
if [[ "$?" != "0" ]]; then
    echo "Failed to build quickstart projects"
    cleanup
    exit 1
fi

###########################################################################################################
pushd camel-activemq

${AMQ}/bin/activemq start

mvn install -Pdeploy-rar

${JBOSS_HOME}/bin/jboss-cli.sh --timeout=60000 --command-timeout=60000 --connect --file=configure-resource-adapter.cli
if [[ "$?" != "0" ]]; then
    echo "configure-resource-adapter.cli script failed"
    cleanup
    exit 1
fi

mvn install -Pdeploy
if [[ "$(curl -s -L -o /dev/null -w '%{http_code}' http://localhost:8080/example-camel-activemq/orders)" != "200" ]]; then
    echo "example-camel-activemq HTTP status code was not 200"
    ${AMQ}/bin/activemq stop
    cleanup
    exit 1
fi

cp src/main/resources/* ${JBOSS_HOME}/standalone/data/orders/

sleep 15

if ! curl http://localhost:8080/example-camel-activemq/orders | grep 'col-md-4' > /dev/null; then
    echo "example-camel-activemq order not created"
    ${AMQ}/bin/activemq stop
    cleanup
    exit 1
fi

mvn clean -Pdeploy
if [[ "$(curl -s -L -o /dev/null -w '%{http_code}' http://localhost:8080/example-camel-activemq/orders)" != "404" ]]; then
    echo "example-camel-activemq HTTP status code was not 404"
    ${AMQ}/bin/activemq stop
    cleanup
    exit 1
fi

 ${JBOSS_HOME}/bin/jboss-cli.sh --timeout=60000 --command-timeout=60000 --connect --file=remove-resource-adapter.cli
if [[ "$?" != "0" ]]; then
    echo "remove-resource-adapter.cli script failed"
    ${AMQ}/bin/activemq stop
    cleanup
    exit 1
fi

${AMQ}/bin/activemq stop

rm -rf ${JBOSS_HOME}/standalone/data/orders/

popd
###########################################################################################################


############################################################################################################
pushd camel-cdi

mvn install -Pdeploy
if [[ "$(curl -s -L -o /dev/null -w '%{http_code}' http://localhost:8080/example-camel-cdi)" != "200" ]]; then
    echo "example-camel-cdi HTTP status code was not 200"
    cleanup
    exit 1
fi

if [[ "$(curl -s http://localhost:8080/example-camel-cdi)" != "Hello world from 127.0.0.1" ]]; then
    echo "example-camel-cdi response was not Hello world"
    cleanup
    exit 1
fi

mvn clean -Pdeploy
if [[ "$(curl -s -L -o /dev/null -w '%{http_code}' http://localhost:8080/example-camel-cdi)" != "404" ]]; then
    echo "example-camel-cdi HTTP status code was not 404"
    cleanup
    exit 1
fi

popd
############################################################################################################


############################################################################################################
pushd camel-cxf-jaxrs

mvn install -Pdeploy
if [[ "$(curl -s -L -o /dev/null -w '%{http_code}' http://localhost:8080/example-camel-cxf-jaxrs)" != "200" ]]; then
    echo "example-camel-cxf-jaxrs HTTP status code was not 200"
    cleanup
    exit 1
fi

if ! curl -X POST -d 'name=Kermit' --header 'Content-Type: application/x-www-form-urlencoded' http://localhost:8080/example-camel-cxf-jaxrs/cxf | grep "Hello Kermit" > /dev/null; then
    echo "example-camel-cxf-jaxrs response was not hello kermit from 127.0.0.1"
    cleanup
    exit 1
fi

mvn clean -Pdeploy
if [[ "$(curl -s -L -o /dev/null -w '%{http_code}' http://localhost:8080/example-camel-cxf-jaxrs)" != "404" ]]; then
    echo "example-camel-cxf-jaxrs HTTP status code was not 404"
    cleanup
    exit 1
fi

popd
############################################################################################################


############################################################################################################
pushd camel-cxf-jaxws

mvn install -Pdeploy
if [[ "$(curl -s -L -o /dev/null -w '%{http_code}' http://localhost:8080/example-camel-cxf-jaxws)" != "200" ]]; then
    echo "example-camel-cxf-jaxws HTTP status code was not 200"
    cleanup
    exit 1
fi

if ! curl -X POST -d 'message=Hello&name=Kermit' --header 'Content-Type: application/x-www-form-urlencoded' http://localhost:8080/example-camel-cxf-jaxws/cxf | grep "Hello Kermit" > /dev/null; then
    echo "example-camel-cxf-jaxws response was not hello kermit"
    cleanup
    exit 1
fi

mvn clean -Pdeploy
if [[ "$(curl -s -L -o /dev/null -w '%{http_code}' http://localhost:8080/example-camel-cxf-jaxws)" != "404" ]]; then
    echo "example-camel-cxf-jaxws HTTP status code was not 404"
    cleanup
    exit 1
fi

popd
############################################################################################################


############################################################################################################
pushd camel-cxf-jaxws-cdi-secure

curl -s http://localhost:8443 > /dev/null

${JBOSS_HOME}/bin/add-user.sh -a -u CN=localhost -p testPassword1+ -g testRole

${JBOSS_HOME}/bin/jboss-cli.sh --timeout=60000 --command-timeout=60000 --connect --file=configure-tls-security.cli
if [[ "$?" != "0" ]]; then
    echo "configure-tls-security.cli script failed"
    cleanup
    exit 1
fi

mvn install -Pdeploy
if [[ "$(curl -s -L -o /dev/null -w '%{http_code}' http://localhost:8080/example-camel-cxf-jaxws-cdi-secure)" != "200" ]]; then
    echo "example-camel-cxf-jaxws-cdi-secure HTTP status code was not 200"
    cleanup
    exit 1
fi

if ! curl -X POST -d 'message=Hello&name=Kermit' --header 'Content-Type: application/x-www-form-urlencoded' http://localhost:8080/example-camel-cxf-jaxws-cdi-secure/cxf | grep "Hello Kermit" > /dev/null; then
    echo "example-camel-cxf-jaxws-cdi-secure response was not hello kermit"
    cleanup
    exit 1
fi

mvn clean -Pdeploy
if [[ "$(curl -s -L -o /dev/null -w '%{http_code}' http://localhost:8080/example-camel-cxf-jaxws-cdi-secure)" != "404" ]]; then
    echo "example-camel-cxf-jaxws-cdi-secure HTTP status code was not 404"
    cleanup
    exit 1
fi

${JBOSS_HOME}/bin/jboss-cli.sh --timeout=60000 --command-timeout=60000 --connect --file=remove-tls-security.cli
if [[ "$?" != "0" ]]; then
    echo "configure-tls-security.cli script failed"
    cleanup
    exit 1
fi

popd
############################################################################################################


############################################################################################################
pushd camel-cxf-jaxws-cdi-xml

mvn install -Pdeploy
if [[ "$(curl -s -L -o /dev/null -w '%{http_code}' http://localhost:8080/example-camel-cxf-jaxws-cdi-xml)" != "200" ]]; then
    echo "example-camel-cxf-jaxws-cdi-xml HTTP status code was not 200"
    cleanup
    exit 1
fi

if ! curl -X POST -d 'message=Hello&name=Kermit' --header 'Content-Type: application/x-www-form-urlencoded' http://localhost:8080/example-camel-cxf-jaxws-cdi-xml/cxf | grep "Hello Kermit" > /dev/null; then
    echo "example-camel-cxf-jaxws-cdi-xml response was not hello kermit"
    cleanup
    exit 1
fi

mvn clean -Pdeploy
if [[ "$(curl -s -L -o /dev/null -w '%{http_code}' http://localhost:8080/example-camel-cxf-jaxws-cdi-xml)" != "404" ]]; then
    echo "example-camel-cxf-jaxws-cdi-xml HTTP status code was not 404"
    cleanup
    exit 1
fi

popd
############################################################################################################


############################################################################################################
pushd camel-cxf-jaxws-secure

${JBOSS_HOME}/bin/add-user.sh -a -u testUser -p testPassword1+ -g testRole
if [[ "$?" != "0" ]]; then
    echo "add-user.sh script failed"
    cleanup
    exit 1
fi

mvn install -Pdeploy
if [[ "$(curl -s -L -o /dev/null -w '%{http_code}' http://localhost:8080/example-camel-cxf-jaxws-secure)" != "200" ]]; then
    echo "example-camel-cxf-jaxws-secure HTTP status code was not 200"
    cleanup
    exit 1
fi

if ! curl -X POST -d 'message=Hello&name=Kermit' --header 'Content-Type: application/x-www-form-urlencoded' http://localhost:8080/example-camel-cxf-jaxws-secure/cxf | grep "Hello Kermit" > /dev/null; then
    echo "example-camel-cxf-jaxws-secure response was not hello kermit"
    cleanup
    exit 1
fi

mvn clean -Pdeploy
if [[ "$(curl -s -L -o /dev/null -w '%{http_code}' http://localhost:8080/example-camel-cxf-jaxws-secure)" != "404" ]]; then
    echo "example-camel-cxf-jaxws-secure HTTP status code was not 404"
    cleanup
    exit 1
fi

popd
############################################################################################################

############################################################################################################
pushd camel-jms

${JBOSS_HOME}/bin/jboss-cli.sh --timeout=60000 --command-timeout=60000 --connect --file=configure-jms-queues.cli
if [[ "$?" != "0" ]]; then
    echo "configure-jms-queues.cli script failed"
    cleanup
    exit 1
fi

mvn install -Pdeploy
if [[ "$(curl -s -L -o /dev/null -w '%{http_code}' http://localhost:8080/example-camel-jms/orders)" != "200" ]]; then
    echo "example-camel-jms HTTP status code was not 200"
    cleanup
    exit 1
fi

cp src/main/resources/* ${JBOSS_HOME}/standalone/data/orders/

sleep 15

if ! curl http://localhost:8080/example-camel-jms/orders | grep 'col-md-4' > /dev/null; then
    echo "example-camel-jms order not created"
    cleanup
    exit 1
fi

mvn clean -Pdeploy
if [[ "$(curl -s -L -o /dev/null -w '%{http_code}' http://localhost:8080/example-camel-jms/orders)" != "404" ]]; then
    echo "example-camel-jms HTTP status code was not 404"
    cleanup
    exit 1
fi

${JBOSS_HOME}/bin/jboss-cli.sh --timeout=60000 --command-timeout=60000 --connect --file=remove-jms-queues.cli
if [[ "$?" != "0" ]]; then
    echo "remove-jms-queues.cli script failed"
    cleanup
    exit 1
fi

rm -rf ${JBOSS_HOME}/standalone/data/orders/

popd
############################################################################################################


############################################################################################################
pushd camel-jms-mdb

${JBOSS_HOME}/bin/jboss-cli.sh --timeout=60000 --command-timeout=60000 --connect --file=configure-jms-queues.cli
if [[ "$?" != "0" ]]; then
    echo "configure-jms-queues.cli script failed"
    cleanup
    exit 1
fi

mvn install -Pdeploy
if [[ "$?" != "0" ]]; then
    echo "example-camel-jms-mdb deploy failed"
    cleanup
    exit 1
fi

sleep 15

if ! grep 'Received message: Message' ${JBOSS_HOME}/standalone/log/server.log > /dev/null; then
    echo "example-camel-jms-mdb no messsages receieved"
    cleanup
    exit 1
fi

mvn clean -Pdeploy
if [[ "$?" != "0" ]]; then
    echo "example-camel-jms-mdb undeploy failed"
    cleanup
    exit 1
fi

${JBOSS_HOME}/bin/jboss-cli.sh --timeout=60000 --command-timeout=60000 --connect --file=remove-jms-queues.cli
if [[ "$?" != "0" ]]; then
    echo "remove-jms-queues.cli script failed"
    cleanup
    exit 1
fi

popd
############################################################################################################


############################################################################################################
pushd camel-jms-spring

${JBOSS_HOME}/bin/jboss-cli.sh --timeout=60000 --command-timeout=60000 --connect --file=configure-jms-queues.cli
if [[ "$?" != "0" ]]; then
    echo "configure-jms-queues.cli script failed"
    cleanup
    exit 1
fi

mvn install -Pdeploy
if [[ "$(curl -s -L -o /dev/null -w '%{http_code}' http://localhost:8080/example-camel-jms-spring/orders)" != "200" ]]; then
    echo "example-camel-jms-spring HTTP status code was not 200"
    cleanup
    exit 1
fi

cp src/main/resources/* ${JBOSS_HOME}/standalone/data/orders/

sleep 15

if ! curl http://localhost:8080/example-camel-jms-spring/orders | grep 'col-md-4' > /dev/null; then
    echo "example-camel-jms-spring order not created"
    cleanup
    exit 1
fi

mvn clean -Pdeploy
if [[ "$(curl -s -L -o /dev/null -w '%{http_code}' http://localhost:8080/example-camel-jms-spring/orders)" != "404" ]]; then
    echo "example-camel-jms-spring HTTP status code was not 404"
    cleanup
    exit 1
fi

${JBOSS_HOME}/bin/jboss-cli.sh --timeout=60000 --command-timeout=60000 --connect --file=remove-jms-queues.cli
if [[ "$?" != "0" ]]; then
    echo "remove-jms-queues.cli script failed"
    cleanup
    exit 1
fi

rm -rf ${JBOSS_HOME}/standalone/data/orders/

popd
############################################################################################################


############################################################################################################
pushd camel-jms-tx

${JBOSS_HOME}/bin/jboss-cli.sh --timeout=60000 --command-timeout=60000 --connect --file=configure-jms-queues.cli
if [[ "$?" != "0" ]]; then
    echo "configure-jms-queues.cli script failed"
    cleanup
    exit 1
fi

mvn install -Pdeploy
if [[ "$(curl -s -L -o /dev/null -w '%{http_code}' http://localhost:8080/example-camel-jms-tx/orders)" != "200" ]]; then
    echo "example-camel-jms-tx HTTP status code was not 200"
    cleanup
    exit 1
fi

cp src/main/resources/orders/* ${JBOSS_HOME}/standalone/data/orders/

sleep 15

if ! curl http://localhost:8080/example-camel-jms-tx/orders | grep 'Order ID' > /dev/null; then
    echo "example-jms-tx order not created"
    cleanup
    exit 1
fi

mvn clean -Pdeploy
if [[ "$(curl -s -L -o /dev/null -w '%{http_code}' http://localhost:8080/example-camel-jms-tx/orders)" != "404" ]]; then
    echo "example-camel-jms-tx HTTP status code was not 404"
    cleanup
    exit 1
fi

${JBOSS_HOME}/bin/jboss-cli.sh --timeout=60000 --command-timeout=60000 --connect --file=remove-jms-queues.cli
if [[ "$?" != "0" ]]; then
    echo "remove-jms-queues.cli script failed"
    cleanup
    exit 1
fi

rm -rf ${JBOSS_HOME}/standalone/data/orders/

popd
############################################################################################################


############################################################################################################
pushd camel-jms-tx-spring

${JBOSS_HOME}/bin/jboss-cli.sh --timeout=60000 --command-timeout=60000 --connect --file=configure-jms-queues.cli
if [[ "$?" != "0" ]]; then
    echo "configure-jms-queues.cli script failed"
    cleanup
    exit 1
fi

mvn install -Pdeploy
if [[ "$(curl -s -L -o /dev/null -w '%{http_code}' http://localhost:8080/example-camel-jms-tx-spring/orders)" != "200" ]]; then
    echo "example-camel-jms-tx-spring HTTP status code was not 200"
    cleanup
    exit 1
fi

cp src/main/resources/orders/* ${JBOSS_HOME}/standalone/data/orders/

sleep 15

if ! curl http://localhost:8080/example-camel-jms-tx-spring/orders | grep 'Order ID' > /dev/null; then
    echo "example-jms-tx-spring order not created"
    cleanup
    exit 1
fi

mvn clean -Pdeploy
if [[ "$(curl -s -L -o /dev/null -w '%{http_code}' http://localhost:8080/example-camel-jms-tx-spring/orders)" != "404" ]]; then
    echo "example-camel-jms-tx-spring HTTP status code was not 404"
    cleanup
    exit 1
fi

${JBOSS_HOME}/bin/jboss-cli.sh --timeout=60000 --command-timeout=60000 --connect --file=remove-jms-queues.cli
if [[ "$?" != "0" ]]; then
    echo "remove-jms-queues.cli script failed"
    cleanup
    exit 1
fi

rm -rf ${JBOSS_HOME}/standalone/data/orders/

popd
############################################################################################################


############################################################################################################
pushd camel-jpa

mvn install -Pdeploy

sleep 15

if [[ "$(curl -s -L -o /dev/null -w '%{http_code}' http://localhost:8080/rest/api/books/order/1)" != "200" ]]; then
    echo "/rest/api/books/order/1 HTTP status code was not 200"
    cleanup
    exit 1
fi

mvn clean -Pdeploy
if [[ "$(curl -s -L -o /dev/null -w '%{http_code}' http://localhost:8080/example-camel-jpa)" != "404" ]]; then
    echo "example-camel-jpa HTTP status code was not 404"
    cleanup
    exit 1
fi

popd
############################################################################################################


############################################################################################################
pushd camel-jpa-spring

mvn install -Pdeploy
sleep 15

if [[ "$(curl -s -L -o /dev/null -w '%{http_code}' http://localhost:8080/rest/api/books/order/1)" != "200" ]]; then
    echo "/rest/api/books/order/1 HTTP status code was not 200"
    cleanup
    exit 1
fi

mvn clean -Pdeploy
if [[ "$(curl -s -L -o /dev/null -w '%{http_code}' http://localhost:8080/example-camel-jpa-spring)" != "404" ]]; then
    echo "example-camel-jpa-spring HTTP status code was not 404"
    cleanup
    exit 1
fi

popd
############################################################################################################


############################################################################################################
pushd camel-mail

${JBOSS_HOME}/bin/jboss-cli.sh --timeout=60000 --command-timeout=60000 --connect --file=configure-mail.cli
if [[ "$?" != "0" ]]; then
    echo "configure-mail.cli script failed"
    cleanup
    exit 1
fi

mvn install -Pdeploy
if [[ "$(curl -s -L -o /dev/null -w '%{http_code}' http://localhost:8080/example-camel-mail)" != "200" ]]; then
    echo "example-camel-mail HTTP status code was not 200"
    cleanup
    exit 1
fi

if [[ "$(curl -s -L -o /dev/null -w '%{http_code}' -X POST -d 'from=user1@localhost&to=user2@localhost&subject=Greetings&message=Hello' --header 'Content-Type: application/x-www-form-urlencoded' http://localhost:8080/example-camel-mail/send)" != "200" ]]; then
    echo "example-camel-mail POST HTTP status code was not 200"
    cleanup
    exit 1
fi

mvn clean -Pdeploy
if [[ "$(curl -s -L -o /dev/null -w '%{http_code}' http://localhost:8080/example-camel-mail)" != "404" ]]; then
    echo "example-camel-mail HTTP status code was not 404"
    cleanup
    exit 1
fi

${JBOSS_HOME}/bin/jboss-cli.sh --timeout=60000 --command-timeout=60000 --connect --file=remove-mail.cli
if [[ "$?" != "0" ]]; then
    echo "remove-mail.cli script failed"
    cleanup
    exit 1
fi

popd
############################################################################################################


############################################################################################################
pushd camel-mail-spring

${JBOSS_HOME}/bin/jboss-cli.sh --timeout=60000 --command-timeout=60000 --connect --file=configure-mail.cli
if [[ "$?" != "0" ]]; then
    echo "configure-mail.cli script failed"
    cleanup
    exit 1
fi

mvn install -Pdeploy
if [[ "$(curl -s -L -o /dev/null -w '%{http_code}' http://localhost:8080/example-camel-mail-spring)" != "200" ]]; then
    echo "example-camel-mail-spring HTTP status code was not 200"
    cleanup
    exit 1
fi

if [[ "$(curl -s -L -o /dev/null -w '%{http_code}' -X POST -d 'from=user1@localhost&to=user2@localhost&subject=Greetings&message=Hello' --header 'Content-Type: application/x-www-form-urlencoded' http://localhost:8080/example-camel-mail-spring/send)" != "200" ]]; then
    echo "example-camel-mail-spring POST HTTP status code was not 200"
    cleanup
    exit 1
fi

mvn clean -Pdeploy
if [[ "$(curl -s -L -o /dev/null -w '%{http_code}' http://localhost:8080/example-camel-mail-spring)" != "404" ]]; then
    echo "example-camel-mail-spring HTTP status code was not 404"
    cleanup
    exit 1
fi

${JBOSS_HOME}/bin/jboss-cli.sh --timeout=60000 --command-timeout=60000 --connect --file=remove-mail.cli
if [[ "$?" != "0" ]]; then
    echo "remove-mail.cli script failed"
    cleanup
    exit 1
fi

popd
############################################################################################################


############################################################################################################
pushd camel-rest-swagger

mvn install -Pdeploy
if [[ "$(curl -s -L -o /dev/null -w '%{http_code}' http://localhost:8080/example-camel-rest-swagger)" != "200" ]]; then
    echo "example-camel-rest-swagger HTTP status code was not 200"
    cleanup
    exit 1
fi

mvn clean -Pdeploy
if [[ "$(curl -s -L -o /dev/null -w '%{http_code}' http://localhost:8080/example-camel-rest-swagger)" != "404" ]]; then
    echo "example-camel-rest-swagger HTTP status code was not 404"
    cleanup
    exit 1
fi

popd
############################################################################################################

cleanup
echo "============================> SUCCESS <============================"
