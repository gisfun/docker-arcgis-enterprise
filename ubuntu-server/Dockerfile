# https://hub.docker.com/_/ubuntu
#From ubuntu:jammy
FROM ubuntu:noble-20250805
LABEL maintainer="brian@wildsong.biz"
ENV REFRESHED_AT=2025-09-01

ENV RELEASE=noble
#ENV RELEASE=jammy
# "jammy" is version 22.04.4.LTS which is the latest LTS (Long Term Support) release.
# It's also the newest version supported by Esri.

RUN apt-get update && apt-get -y install apt-utils locales

# Set up the locale.
RUN locale-gen en_US.UTF-8
ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

# The gettext package is needed to install ArcGIS Server,
# Others can be convenient
RUN apt-get -y install gettext less vim net-tools unzip

# Some useful tools; can't go far without python.
RUN apt-get -y install bind9-host procps iproute2 iputils-ping wget python3 python3-pip python3-requests
RUN ln -s /etc/alternatives/python /usr/bin/python &&\
    ln -s /usr/bin/python3 /etc/alternatives/python

#RUN pip install --upgrade pip && pip install requests


# ---- Install everything we need --------------------------------
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get install -y --no-install-recommends \
        redsocks iptables ca-certificates curl nano gnupg
#    rm -rf /var/lib/apt/lists/*

# ---- Add the helper scripts & template -------------------------
COPY redsocks-entrypoint.sh   /usr/local/bin/redsocks-entrypoint.sh
COPY toggle-redsocks.sh       /usr/local/bin/toggle-redsocks.sh
COPY redsocks.conf.template   /etc/redsocks.conf.template

# ---- Permissions ------------------------------------------------
RUN chmod +x /usr/local/bin/redsocks-entrypoint.sh \
    && chmod +x /usr/local/bin/toggle-redsocks.sh

# ---- Default environment variables -------------------------------
# These can be overridden at `docker run -e …`
ENV REDSOCKS_PROXY_HOST=host.docker.internal
ENV REDSOCKS_PROXY_PORT=1080
ENV REDSOCKS_PROXY_TYPE=socks5
# socks4 / socks5 / http

# ---- Keep the original entrypoint behaviour --------------------
# below is not needed if toggle-redsocks can work without it
#ENTRYPOINT ["/usr/local/bin/redsocks-entrypoint.sh"]
# No CMD – the container will run whatever you pass (`bash`, `myapp`, …)

# This will make the system work better and eliminate warnings from the temporal store checks
COPY arcgis.conf /etc/sysctl.d/

# These are needed by Portal For ArcGIS
RUN apt-get -y install libice6 libsm6 libxtst6 libxrender1 dos2unix

# Create the user/group who will run ArcGIS services
# I set them to my own UID/GID so that the VOLUMES I create will be read/write
RUN groupadd -g 1001 arcgis && useradd -m -r arcgis -g arcgis -u 1001
ENV HOME=/home/arcgis

RUN chown arcgis.arcgis /home/arcgis
WORKDIR /home/arcgis
VOLUME /home/arcgis

# Note the user is still set to root here, we want this so that
# containers that pull from this one still have root when they start.
