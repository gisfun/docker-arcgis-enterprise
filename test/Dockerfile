#FROM ubuntu-server:latest
FROM ubuntu-server:local
LABEL maintainer="brian@wildsong.biz"
ENV REFRESHED_AT=2025-08-01

RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
RUN chmod a+r /etc/apt/keyrings/docker.asc
RUN echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/nu
RUN apt-get update -y
RUN apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin sudo nginx-full
RUN usermod -aG docker arcgis
RUN usermod -aG sudo arcgis

RUN echo "arcgis ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/arcgis \
    && chmod 0440 /etc/sudoers.d/arcgis

# Remove the default Nginx configuration
RUN unlink /etc/nginx/sites-enabled/default

# Copy your custom Nginx configuration into the container
COPY nginx.docker.conf /etc/nginx/sites-available/docker.daemon

# Create a symlink for your custom configuration in sites-enabled
RUN ln -s /etc/nginx/sites-available/docker.daemon /etc/nginx/sites-enabled/docker.daemon

# Port information: https://enterprise.arcgis.com/en/notebook/latest/install/linux/install-arcgis-notebook-server.htm
EXPOSE 11443 30001-31000 2375

# Probably don't need this for Portal
# ADD limits.conf /etc/security/limits.conf

WORKDIR /app

ADD bashrc .
ADD start.sh .

# ESRI uses LOGNAME
ENV LOGNAME arcgis

WORKDIR ${HOME}

# The installer will not run as root.
USER arcgis

# Command that will be run by default when you do "docker run"
CMD /app/start.sh