#!/bin/bash
#
#  Run this in an ArcGIS container to install and start the server
#
# Required ENV settings:
# HOSTNAME ESRI_VERSION

source /app/bashrc
cp /app/bashrc /home/arcgis/.bashrc

sudo chgrp docker /var/run/docker.sock

SCRIPT="/home/arcgis/notebookserver/startnotebookserver.sh"
if [ -f $SCRIPT ]; then
  # Starting ArcGIS Server
  $SCRIPT
else
  echo "Installing Notebook"
  /app/Installers/NotebookServer_Linux/Setup -m silent -d /home --verbose -l yes -a /app/licenses/keycodes.ecp
fi

# 1050:100
sudo chown -R arcgis:users /home/arcgis/arcgisnotebookserver/directories

tail -f /var/log/*.log /home/arcgis/arcgisnotebookserver/logs/**/*.log
