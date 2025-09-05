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
    ubuntu-redsocks2 sleep infinity

docker exec demo toggle-redsocks.sh enable
echo "Wait for 2 seconds.."
timeout /t 2

rem docker exec demo curl -k https://www.google.com > NUL
docker exec -it demo ^
    curl -k -X GET "https://postman-echo.com/get?foo1=bar1&foo2=bar2"

echo "Check Charles UI - you should see the decrypted GET request."

docker exec demo ^
  curl -k -s -X POST ^
       -H "Content-Type: application/json" ^
       -d '{"msg":"hello"}' ^
       https://postman-echo.com/post
echo "Check Charles UI - you should see the decrypted POST request."
