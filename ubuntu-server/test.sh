#!/usr/bin/env bash
set -euo pipefail

# --------------------------------------------------------------
# 1) Build the image (once)
# --------------------------------------------------------------
docker build -t ubuntu-redsocks .

# --------------------------------------------------------------
# 2) Run a container with the Charles cert mounted
# --------------------------------------------------------------
# docker run -d --name demo \
#     -e REDSOCKS_PROXY_HOST=host.docker.internal \
#     -e REDSOCKS_PROXY_PORT=8889 \
#     -e REDSOCKS_PROXY_TYPE=socks5 \
#     -v "$(pwd)/charles.pem:/tmp/charles.pem:ro" \
#     ubuntu-redsocks sleep infinity

docker stop demo
docker rm demo

docker run -d --name demo \
    --cap-add=NET_ADMIN \
    --add-host=host.docker.internal:host-gateway \
    -e REDSOCKS_PROXY_HOST=host.docker.internal \
    -e REDSOCKS_PROXY_PORT=8889 \
    -e REDSOCKS_PROXY_TYPE=socks5 \
    -v "$(pwd)/charles.pem:/tmp/charles.pem:ro" \
    ubuntu-redsocks
#    ubuntu-redsocks sleep infinity

# --------------------------------------------------------------
# 3) Enable forwarding
# --------------------------------------------------------------
docker exec demo toggle-redsocks.sh enable
echo "Wait for 2 seconds.."
sleep 2
# --------------------------------------------------------------
# 4) Verify that traffic goes through Charles (HTTPS example)
# --------------------------------------------------------------
docker exec demo curl -k https://www.google.com > /dev/null
echo "Check Charles UI – you should see the decrypted Google request."
docker exec demo \
  curl -k -s -X POST \
       -H "Content-Type: application/json" \
       -d '{"msg":"hello"}' \
       https://postman-echo.com/post
echo "Check Charles UI – you should see the decrypted Postman request."

# prompts

# design a Dockerfile that uses base image of Ubuntu 24.04 and install redsocks, set up iptables such that all outgoing internet traffic from the container can be intercepted by socks proxy running on the host

# The proxy host and port should be configurable, with the default value as host.docker.internal

# The forwarding should be disabled by default. Provide a script (toggle-redsocks.sh) to enable/disable the forwarding behavior. Also I would like to retain the default entrypoint from the base image.

# Place the initial setup in a called redsocks-entrypoint.sh. Incorporate the installation of charles proxy root cert into the entrypoint script, if charles.pem file is present. allow the cert to be passed in via -v "$(pwd)/charles.pem:/tmp/charles.pem:ro"

# Also, please show a working example using charles proxy running the host and being able intercept https traffic going out from the container.