#!/bin/bash
#
#  Run this in an ArcGIS container to install and start the server
#
# Required ENV settings:
# HOSTNAME ESRI_VERSION

source /app/bashrc
cp /app/bashrc /home/arcgis/.bashrc


tail -f /var/log/*.log