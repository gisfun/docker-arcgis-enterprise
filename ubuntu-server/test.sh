#!/bin/bash

# docker run -it --rm \
#     --cap-add=NET_ADMIN \
#     -v "$(pwd)/charles.pem:/tmp/charles.pem:ro" \
#     -e REDSOCKS_PROXY_HOST=host.docker.internal \
#     -e REDSOCKS_PROXY_PORT=8888 \
#     my-redsocks \
#     bash -c '
#         enable-redsocks.sh on && \
#         echo ">>> REDSOCKS enabled – try: curl https://example.com" && \
#         exec bash'

docker stop demo
docker rm demo

docker run -d --name demo \
    --cap-add=NET_ADMIN \
    --add-host=host.docker.internal:host-gateway \
    -e REDSOCKS_PROXY_HOST=host.docker.internal \
    -e REDSOCKS_PROXY_PORT=8889 \
    -e REDSOCKS_PROXY_TYPE=socks5 \
    -v "$(pwd)/charles.pem:/tmp/charles.pem:ro" \
    ubuntu-redsocks sleep infinity

#     -v "$(pwd)/charles.pem:/tmp/charles.pem:ro" \

#docker exec demo toggle-redsocks.sh enable


# Inside the container
#docker exec demo curl -s https://ifconfig.me
# → The IP you see should be the public IP of the host (i.e. the
#   IP that Charles uses to reach the internet).

# A request that Charles will actually decrypt:
#docker exec demo curl -k https://www.google.com > /dev/null
# Open Charles → you will see the request under “SSL Proxying”.



# prompts

# design a Dockerfile that uses base image of Ubuntu 24.04 and install redsocks, set up iptables such that all outgoing internet traffic from the container can be intercepted by socks proxy running on the host

# The proxy host and port should be configurable, with the default value as host.docker.internal

# The forwarding should be disabled by default. Provide a script (toggle-redsocks.sh) to enable/disable the forwarding behavior. Also I would like to retain the default entrypoint from the base image.

# Place the initial setup in a called redsocks-entrypoint.sh. Incorporate the installation of charles proxy root cert into the entrypoint script, if charles.pem file is present. allow the cert to be passed in via -v "$(pwd)/charles.pem:/tmp/charles.pem:ro"

# Also, please show a working example using charles proxy running the host and being able intercept https traffic going out from the container.