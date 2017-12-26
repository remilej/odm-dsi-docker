#!/bin/bash

# This script is sending an event to DSI Runtime which creates
# an entity Person.
#
# First argument is the hostname of the DSI Runtime.
# Second argument is the name of the person.

set -e

function print_usage {
        echo "USAGE: $0 <PERSON_NAME>"
}


#DSI_HOSTNAME=`docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' dsi-runtime-inbound`
DSI_PORT=`docker inspect -f '{{ (index (index .NetworkSettings.Ports "9443/tcp") 0).HostPort }}' dsi-runtime-inbound`

#echo "INBOUND IP: $DSI_HOSTNAME"
echo "INBOUND PORT: $DSI_PORT"

if [ -z "$1" ]; then
        PERSON="jean"
else
        PERSON="$1"
fi

cp ./create_person.xml /tmp/$$.tmp

if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i'' -e "s/ID/$PERSON/" /tmp/$$.tmp
else
    sed -i "s/ID/$PERSON/" /tmp/$$.tmp
fi

URL=https://localhost:$DSI_PORT/in/simple

echo "Endpoint URL: $URL"

cat /tmp/$$.tmp

curl --user tester:tester -k -H "Content-Type: application/xml" -d @/tmp/$$.tmp -X POST $URL

rm /tmp/$$.tmp
