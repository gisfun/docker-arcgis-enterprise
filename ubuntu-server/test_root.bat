@echo off

set CONT=docker-arcgis-enterprise-server-1
docker exec -u root %CONT% toggle-redsocks.sh enable
docker exec %CONT% curl -k https://www.google.com > NUL
echo "Check Charles UI - you should see the decrypted Google request."
