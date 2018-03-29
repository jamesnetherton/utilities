#!/bin/bash

README=$1

sed -i -e 's/WildFly Camel susbsystem/Red Hat Fuse on EAP/g' \
       -e 's/WildFly Camel susbsystem/Red Hat Fuse on EAP/g' \
       -e 's/WildFly Camel Subsystem/Red Hat Fuse on EAP/g' \
       -e 's/the EAP Camel subsystem/Red Hat Fuse on EAP/g' \
       -e 's/the wildfly-camel subsystem installed/Red Hat Fuse installed/g' \
       -e 's/JBoss Fuse/Red Hat Fuse/g' \
       -e 's/standalone-full-camel.xml/standalone-full.xml/g' \
       -e 's/WildFly/EAP/g' \
    ${README}
