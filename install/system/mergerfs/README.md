
### Notes

Example `/etc/fstab` contents

```
# /etc/fstab: static file system information.
#
# Use 'blkid' to print the universally unique identifier for a
# device; this may be used with UUID= as a more robust way to name devices
# that works even if disks are added and removed. See fstab(5).
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
# / was on /dev/ubuntu-vg/ubuntu-lv during curtin installation
/dev/disk/by-id/dm-uuid-LVM-8oyRChaaYHPOo3MZur7d5HuZHkA21LddHsuaxIfsC8V2OPlpfCyjyHUgoVblnxa4 / ext4 defaults 0 1
# /boot was on /dev/nvme0n1p2 during curtin installation
/dev/disk/by-uuid/ad846fc5-8d14-4c2c-b4cf-26e78a6effff /boot ext4 defaults 0 1
/swap.img       none    swap    sw      0       0

# SSD Drive Samsung 860 m.2 SATA SSD 1Tb
UUID=d64db791-e897-4fd9-afb1-740f9c358907 /mnt/1TbSSD ext4 defaults 0 2

# Data Drive 1
UUID=5d4ad7cd-629e-4bf8-ba50-7191a1f0e7ba /mnt/8TbHd ext4 nosuid,nodev,nofail,x-gvfs-show,x-gvfs-name=8TbHd 0 2

# Data Drive 2
UUID=3efc85b3-3a06-4e35-8ac4-243be751308e /mnt/8TbHd_1 ext4 nosuid,nodev,nofail,x-gvfs-show,x-gvfs-name=8TbHd_1 0 2

# Data Drive 3
UUID=598f96fe-808f-4315-875f-05135469db73 /mnt/8TbHd_2 ext4 nosuid,nodev,nofail,x-gvfs-show,x-gvfs-name=8TbHd_2 0 2

# Parity Drive for SnapRAID
UUID=0d62a261-aa71-4a28-a25f-cc3d7be0bdaf /mnt/8TbHd_Parity ext4 nosuid,nodev,nofail,x-gvfs-show,x-gvfs-name=8TbHd_Parity 0 2

# 20 TB USB backup drive (ext4)
UUID=ecbc7c42-e532-4167-ac67-1a7c058ca364 /mnt/20TbHd_Usb3 ext4 defaults,nofail,x-systemd.device-timeout=15 0 2

# The mount point for mergerfs
# /mnt/8TbHd:/mnt/8TbHd_1:/mnt/8TbHd_2 /mnt/pool fuse.mergerfs defaults,allow_other,use_ino,fsname=mergerFS 0 0
/mnt/1TbSSD:/mnt/8TbHd:/mnt/8TbHd_1:/mnt/8TbHd_2:/mnt/8TbHd_Parity /mnt/pool fuse.mergerfs defaults,allow_other,nonempty,category.create=ff,category.search=ff,minfreespace=100G,fsname=pool 0 0
```