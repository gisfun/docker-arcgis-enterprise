@echo off

docker stop demo
docker rm demo

docker run -d --name demo ^
    --cap-add=NET_ADMIN ^
    --add-host=host.docker.internal:host-gateway ^
    -e REDSOCKS_PROXY_HOST=host.docker.internal ^
    -e REDSOCKS_PROXY_PORT=8889 ^
    -e REDSOCKS_PROXY_TYPE=socks5 ^
    -v "charles.pem:/tmp/charles.pem:ro" ^
    ubuntu-redsocks

docker exec demo toggle-redsocks.sh enable
echo "Wait for 2 seconds.."
timeout /t 2

docker exec demo curl -k https://www.google.com > NUL
echo "Check Charles UI - you should see the decrypted Google request."
