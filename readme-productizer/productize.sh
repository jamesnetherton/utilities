#!/bin/bash

README=$1

sed -i -e 's/WildFly Camel susbsystem/JBoss Fuse on EAP/g' \
       -e 's/WildFly Camel susbsystem/JBoss Fuse on EAP/g' \
       -e 's/WildFly Camel Subsystem/JBoss Fuse on EAP/g' \
       -e 's/the wildfly-camel subsystem installed/JBoss Fuse installed/g' \
       -e 's/standalone-full-camel.xml/standalone-full.xml/g' \
       -e '/Learn more/,+20d' \
       -e 's/WildFly/EAP/g' \
    ${README}
