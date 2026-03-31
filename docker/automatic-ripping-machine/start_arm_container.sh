#!/bin/bash
docker run -d \
    -p "8080:8080" \
    -e ARM_UID="1001" \
    -e ARM_GID="1001" \
    -e TZ=America/Phoenix \
    -v "/home/arm:/home/arm" \
    -v "/home/arm/db:/home/arm/db" \
    -v "/home/arm/music:/home/arm/music" \
    -v "/home/arm/logs:/home/arm/logs" \
    -v "/home/arm/media:/home/arm/media" \
    -v "/home/arm/config:/etc/arm/config" \
    --device="/dev/sr0:/dev/sr0" \
    --device="/dev/dri:/dev/dri" \
    --privileged \
    --restart "no" \
    --name "automatic-ripping-machine" \
    --cpuset-cpus="0-2" \
    automaticrippingmachine/automatic-ripping-machine:latest
