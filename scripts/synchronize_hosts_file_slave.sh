#!/bin/bash

#set -x

echo "Starting the script in charge of synchronising /etc/hosts file over NFS"

WAIT_TIME="5"

while true; do
    LOCAL_HOSTS_FILE_MD5=$(md5sum /etc/hosts | awk '{print $1}')
    NFS_HOSTS_FILE_MD5=$(md5sum /mnt/nfs/var/nfs/hosts | awk '{print $1}')
    if [ "$LOCAL_HOSTS_FILE_MD5" != "$NFS_HOSTS_FILE_MD5" ]; then
        echo "Local /etc/hosts has changed, I will start the synchronization"
        cp /mnt/nfs/var/nfs/hosts /etc/hosts
    fi
    echo "Waiting $WAIT_TIME seconds"
    sleep $WAIT_TIME
done

exit 0
