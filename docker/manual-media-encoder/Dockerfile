FROM docker.io/ubuntu:24.04

# Install HandBrake and its dependencies
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get -qy update && \
    apt-get -qy install handbrake handbrake-cli libdvd-pkg && \
    apt-get -qy clean && \
    rm -rf /var/lib/apt/lists/* /usr/share/doc /usr/share/man

# Set a working directory
# This is where HandBrake will look for input/output files by default.
WORKDIR /data

# Default to bash for interactive CLI use
CMD ["bash"]
