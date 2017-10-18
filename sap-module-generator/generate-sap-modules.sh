# Assemble SAP modules
SAP_TMP_DIR=/tmp/sap
MODULE_CAMEL_EXTRAS=${SAP_TMP_DIR}/modules/org/wildfly/camel/extras/main
MODULE_SAP=${SAP_TMP_DIR}/modules/com/sap/conn/jco/main
MODULE_SAP_LIB=${MODULE_SAP}/lib/linux-$(uname -i)
SAP_JCO_VERSION=3.0.11
SAP_IDOC_VERSION=3.0.10

if [[ -d ${SAP_TMP_DIR} ]]; then
  exit 0
fi

if [[ -z "${NEXUS_USER}" ]] || [[ -z "${NEXUS_PASSWORD}" ]]; then
  echo "NEXUS_USER and NEXUS_PASSWORD variables are not set"
  exit 1
fi

mkdir -p ${MODULE_CAMEL_EXTRAS} ${MODULE_SAP} ${MODULE_SAP_LIB}

# Add SAP module to extras
cat << EOF > ${MODULE_CAMEL_EXTRAS}/module.xml
<?xml version="1.0" encoding="UTF-8"?>
<module xmlns="urn:jboss:module:1.1" name="org.wildfly.camel.extras">

    <dependencies>
        <module name="org.fusesource.camel.component.sap" export="true" services="export" />
    </dependencies>

</module>
EOF

# Fetch dependencies
curl -u ${NEXUS_USER}:${NEXUS_PASSWORD} https://repository.jboss.org/nexus/service/local/repositories/fs-maven2-all/content/com/sap/conn/jco/sapjco3/${SAP_JCO_VERSION}/sapjco3-${SAP_JCO_VERSION}.jar > ${MODULE_SAP}/sapjco3.jar
curl -u ${NEXUS_USER}:${NEXUS_PASSWORD} https://repository.jboss.org/nexus/service/local/repositories/fs-maven2-all/content/com/sap/conn/idoc/sapidoc3/${SAP_IDOC_VERSION}/sapidoc3-${SAP_IDOC_VERSION}.jar > ${MODULE_SAP}/sapidoc3.jar
curl -u ${NEXUS_USER}:${NEXUS_PASSWORD} https://repository.jboss.org/nexus/service/local/repositories/fs-maven2-all/content/com/sap/conn/jco/sapjco3/${SAP_JCO_VERSION}/sapjco3-${SAP_JCO_VERSION}-linux-x86_64.so > ${MODULE_SAP_LIB}/libsapjco3.so

