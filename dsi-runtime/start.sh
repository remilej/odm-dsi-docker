#!/bin/bash

# This script is called when the docker container of DSI Runtime is started.
# It creates the server configuration files from a WLP configuration template.
# The first argument of the script is the name of the template. By default,
# it is 'dsi-runtime'.
# The second argument is the hostname of the catalog server.

set -e

function jprofile_enable {
        echo "JProfiler enable"

        wget http://download-keycdn.ej-technologies.com/jprofiler/jprofiler_linux_9_2.tar.gz -P /tmp/

        pushd /tmp
        tar -xvf jprofiler_linux_9_2.tar.gz
        popd

        rm /tmp/jprofiler_linux_9_2.tar.gz

        JPROFILER_AGENT="-agentpath:/tmp/jprofiler9/bin/linux-x64/libjprofilerti.so=offline,id=108,config=/root/jprofiler_config.xml"
        echo "$JPROFILER_AGENT" >> /opt/dsi/runtime/wlp/usr/servers/$DSI_TEMPLATE/jvm.options
}

DSI_HOME="/opt/dsi"

if [ -z "$JAVA_HOME" ]; then
        export JAVA_HOME="$DSI_HOME/jdk/jre"
fi

echo "JAVA_HOME=$JAVA_HOME"
export PATH=$JAVA_HOME/bin:$PATH

if [ -z "$1" ]; then
        DSI_TEMPLATE="dsi-runtime"
else
        DSI_TEMPLATE="$1"
fi

if [ ! -z "$2" ]; then
        DSI_CATALOG_HOSTNAME="$2"
fi

echo "The DSI template $DSI_TEMPLATE is going to be used."

SRV_XML="/opt/dsi/runtime/wlp/usr/servers/$DSI_TEMPLATE/server.xml"

INTERNAL_IP=`hostname -I| sed 's/ //g'`

if [ ! -f "$SRV_XML" ]; then
        echo "Create the DSI server $DSI_TEMPLATE"
        echo "JAVA_HOME=$JAVA_HOME" > /opt/dsi/runtime/wlp/etc/server.env
        /opt/dsi/runtime/wlp/bin/server create $DSI_TEMPLATE --template=$DSI_TEMPLATE || echo "$DSI_TEMPLATE was already created"
        echo "WLP server $DSI_TEMPLATE has been created"

        echo "" >> /opt/dsi/runtime/wlp/usr/servers/$DSI_TEMPLATE/server.env
        echo "JAVA_HOME=$JAVA_HOME" >> /opt/dsi/runtime/wlp/usr/servers/$DSI_TEMPLATE/server.env

        if [ ! -z "$DSI_DB_HOSTNAME" ]; then
                echo "Update DSI_DB_HOSTNAME to $DSI_DB_HOSTNAME in $SRV_XML"
                sed -i "s/\$DSI_DB_HOSTNAME/$DSI_DB_HOSTNAME/g" "$SRV_XML"
        fi
        if [ ! -z "$DSI_DB_USER" ]; then
                echo "Update DSI_DB_USER to $DSI_DB_USER in $SRV_XML"
                sed -i "s/\$DSI_DB_USER/$DSI_DB_USER/g" "$SRV_XML"
        fi
        if [ ! -z "$DSI_DB_PASSWORD" ]; then
                echo "Update DSI_DB_PASSWORD to $DSI_DB_PASSWORD in $SRV_XML"
                sed -i "s/\$DSI_DB_PASSWORD/$DSI_DB_PASSWORD/g" "$SRV_XML"
        fi

        if [ ! -z "$DSI_JPROFILER" ]; then
                jprofile_enable
        fi
else
        echo "$SRV_XML already exist"
fi

if [ ! -z "$DSI_CATALOG_HOSTNAME" ]; then
        BOOTSTRAP_FILE=/opt/dsi/runtime/wlp/usr/servers/$DSI_TEMPLATE/bootstrap.properties
        echo "Modifying $BOOTSTRAP_FILE"
        sed -i "s/ia.bootstrapEndpoints=localhost:2809/ia.bootstrapEndpoints=$DSI_CATALOG_HOSTNAME:2809/g" $BOOTSTRAP_FILE
fi

if [ ! -z "$2" ]; then
        if [ "$DSI_TEMPLATE" == "dsi-runtime-container" ] ; then
                CATALOG_TEST_RESULT=0
                until [ "$CATALOG_TEST_RESULT" -eq 1 ] ; do
                        sleep 5
                        echo Testing availability of catalog server $DSI_CATALOG_HOSTNAME before starting runtime container
                        CATALOG_TEST_RESULT=`/opt/dsi/runtime/wlp/bin/xscmd.sh -c showPrimaryCatalogServer --catalogEndPoints $DSI_CATALOG_HOSTNAME:2809 | egrep $DSI_CATALOG_HOSTNAME.*TRUE | wc -l`
                done
        else
                CONTAINER_TEST_RESULT=0
                until [ "$CONTAINER_TEST_RESULT" -eq 1 ] ; do
                        sleep 10 
                        echo "Testing availability of runtime containers before starting connectivity (looking for the first container referenced by catalog)"
                        CONTAINER=`/opt/dsi/runtime/wlp/bin/xscmd.sh -c getStatsSpec --catalogEndPoints $DSI_CATALOG_HOSTNAME:2809 | egrep dsi-runtime-container | sed "s/-dsi-runtime-container.*$//"| head -1`
                        CONTAINER_TEST_RESULT=`echo "$CONTAINER" | egrep "\." | wc -l`
                done
                echo found container $CONTAINER
                GRID_ONLINE=0
                until [ "$GRID_ONLINE" -eq 1 ] ; do
                        sleep 10
                        echo "Testing availability of runtime containers before starting connectivity (checking that grid is online)"
                        GRID_ONLINE=`/opt/dsi/runtime/ia/bin/serverManager isonline --host=$CONTAINER --disableSSLHostnameVerification=true --disableServerCertificateVerification=true | egrep "is online" | wc -l`
                done        
        fi
fi



echo "The IP of the DSI server is $INTERNAL_IP"

if [ -f "$BOOTSTRAP_FILE" ]; then
        sed -i "s/ia\.host\=localhost/ia\.host\=$INTERNAL_IP/" $BOOTSTRAP_FILE
        echo "Internal IP: $INTERNAL_IP"
fi

/opt/dsi/runtime/wlp/bin/server run $DSI_TEMPLATE
