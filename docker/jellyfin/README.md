docker-compose.yml located in /opt/jellyfin

From https://jellyfin.org/docs/general/post-install/transcoding/hardware-acceleration/intel/

```
getent group render | cut -d: -f3
```

Example docker-compose configuration file written in YAML:
```
services:
  jellyfin:
    image: jellyfin/jellyfin
    user: 1000:1000
    group_add:
      - '122' # Change this to match your "render" host group id and remove this comment
    network_mode: 'host'
    volumes:
      - /path/to/config:/config
      - /path/to/cache:/cache
      - /path/to/media:/media
    devices:
      - /dev/dri/renderD128:/dev/dri/renderD128
```