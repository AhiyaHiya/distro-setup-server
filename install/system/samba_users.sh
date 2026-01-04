#!/bin/bash

function add_group_and_users()
{
    printf "Adding group family\n"
    sudo groupadd family

    printf "Adding lucas and zachary no login accounts\n"
    sudo adduser --system --no-create-home --shell /usr/sbin/nologin zachary
    sudo adduser --system --no-create-home --shell /usr/sbin/nologin lucas

    printf "Adding users to family group\n"
    sudo usermod -aG family jaimerios
    sudo usermod -aG family zachary
    sudo usermod -aG family lucas

    printf "Printing users for group family\n"
    getent group family
}

function set_permissions()
{
    printf "Adding permissions to folders\n"
    sudo chown -R root:family /mnt/pool/samba/users/family
    sudo chmod -R 2770 /mnt/pool/samba/users/family

    sudo chown -R zachary:family /mnt/pool/samba/users/zachary
    sudo chmod -R 2770 /mnt/pool/samba/users/zachary

    sudo chown -R lucas:family /mnt/pool/samba/users/lucas
    sudo chmod -R 2770 /mnt/pool/samba/users/lucas

    sudo chown -R jaimerios:jaimerios /mnt/pool/samba/users/jaime  # Private share – no group needed
    sudo chmod -R 0750 /mnt/pool/samba/users/jaime
}

function set_passwords()
{
    sudo smbpasswd -a zachary
    sudo smbpasswd -a lucas
}

function enable_users()
{
    sudo smbpasswd -e jaimerios
    sudo smbpasswd -e zachary
    sudo smbpasswd -e lucas
}

printf "No functions are selected; edit script to execute a particular function\n"

