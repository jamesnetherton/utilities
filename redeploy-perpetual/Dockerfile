FROM fedora:maven-3.3.9

RUN useradd -m -d /home/maven -s /bin/bash maven

USER maven

COPY ./target/redeploy-perpetual-1.0-SNAPSHOT.jar /home/maven/redeploy-perpetual.jar

ENTRYPOINT [ "java", "-jar", "/home/maven/redeploy-perpetual.jar" ]


