#!/bin/bash
#
#  Run this in an ArcGIS container to install and start the server
#
# Required ENV settings:
# HOSTNAME ESRI_VERSION

#  Run this in an ArcGIS container to start the Portal server
#  and configure it with the default admin/password and site
#
# Environment: HOSTNAME AGP_USERNAME AGP_PASSWORD PORTAL_CONTENT


source /app/bashrc
cp /app/bashrc /home/arcgis/.bashrc

PROPERTIES=".ESRI.properties.${HOSTNAME}.${ESRI_VERSION}"

# Clumsily wipe all log files so when we start
# there will only be one.
# TODO find the current logfile instead
# amd remove only old logs
LOGDIR=/home/arcgis/server/usr/logs/SERVER.LOCAL/server/
rm -rf $LOGDIR/*.log $LOGDIR/*.lck

# Has the server been installed yet?
SCRIPT="/home/arcgis/server/framework/etc/scripts/agsserver.sh"
if [ -f $SCRIPT ]; then
  # Starting ArcGIS Server
  $SCRIPT start
else
  echo "Installing ArcGIS Server."
  /app/Installer/Setup -m silent --verbose -l yes
fi

echo "Server info"
serverinfo

KEYCODES="/home/arcgis/server/framework/runtime/.wine/drive_c/Program\ Files/ESRI/License${ESRI_VERSION}/sysgen/keycodes"

# Has it been authorized?
if authorizeSoftware -s | grep arcsdeserver; then 
  authorizeSoftware -s | tail -6
else
  echo "Authorizing."
  authorizeSoftware -f /app/server.prvc
fi
echo ""

SERVER_URL="https://${HOSTNAME}:6443/arcgis/manager/"
echo -n "Waiting for ArcGIS Server to start..."
sleep 10 

# Has this server been configured? 
# This requires a running portal so I don't do it.
if false ; then
  curl --retry 6 -sS --insecure $SERVER_URL > /tmp/apphttp
  if [ $? != 0 ]; then
    echo "Server did not start. $?"
  else
    echo "okay!"
  fi
  configurebasedeployment.sh -f /app/configurebasedeployment.properties
fi

echo "Try reaching me at ${SERVER_URL}"

# I can start a process here that finds the current log file
# and tails it to STDOUT
# I don't have a way to start in "no daemon" mode
# so I need something to run here...
# Note there are many logs, this is the one for "server"
#tail -f $LOGDIR/*log

# portal start.sh

# Clumsily wipe all log files so when we start
# there will only be one.
# TODO find the current logfile instead
# amd remove only old logs
LOGDIR2="/home/arcgis/portal/usr/arcgisportal/logs"
rm -rf $LOGDIR2/PORTAL.LOCAL/portal/*.l??

# Well, maybe if this file is here then it's installed already?
SCRIPT2="/home/arcgis/portal/framework/etc/agsportal.sh"
if [ -f $SCRIPT2 ]; then 
  echo "Portal for ArcGIS is already installed."
else
  echo "Installing Portal"
  /app/InstallerPortal/Setup -m silent -d /home --verbose -l yes
fi

# Is it running already? 
if [ -f ${SCRIPT2} ]; then
  echo "Restarting Portal"
  ${SCRIPT2} restart
fi

PORTAL_URL="https://${HOSTNAME}:7443/arcgis/home/"
echo -n "Waiting for Portal to start.. "
sleep 10
curl --retry 6 -sS --insecure --head ${PORTAL_URL} > /tmp/apphttp
if [ $? != 0 ]; then
  echo "Portal not responding. $?"
else
  echo "okay!"
  portaldiag
fi

# Instead of spelling out all these options it is also
# possible to feed a properties file, for example see
# ~/portal/tools/createportal/createportal.properties
# Note that all of these arguments except -d are required, else the script fails 
createportal.sh -fn Site -ln Admin \
		-u ${AGP_USERNAME} -p ${AGP_PASSWORD} \
		-e ${ADMIN_EMAIL} \
		-d ${PORTAL_CONTENT} \
		-lf /app/portal_license.json

CONFIG_STORE="/home/arcgis/portal/framework/etc/config-store-connection.json"
if [ -f $CONFIG_STORE} ]; then
  CreateAdminAccount list
else
  echo "Portal is not configured."
fi

echo "Try reaching me at ${PORTAL_URL}"

tail -f ${LOGDIR2}/PORTAL.LOCAL/portal/*.log

