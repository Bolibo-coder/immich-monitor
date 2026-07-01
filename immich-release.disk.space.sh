#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# 1. DEFINE YOUR IMMICH DIRECTORY PATH HERE
IMMICH_DIR="/media/CloudHDD/immich-app"

echo "######################################################################"
echo "#    Executed on: $(date +"%Y-%m-%d %H:%M:%S")                                #"
echo "######################################################################"
echo " "
echo "______________________________________________________________________"
echo "1. Cleaning system:"
sudo apt-get autoremove -y && sudo apt-get clean
sudo journalctl --vacuum-size=50M
echo "______________________________________________________________________"
echo " "
echo "2. Cleaning docker in $IMMICH_DIR:"
cd "$IMMICH_DIR" || exit 1
if [ -n "$(ctr -n moby leases ls -q)" ]; then
   echo "       Removing all containerd snapshots...";
   ctr -n moby leases rm $(ctr -n moby leases ls -q);
   echo "       Removing all Immich containers..."
   docker rm -f immich_server immich_postgres immich_machine_learning immich_redis
   echo "       Restarting Immich..."
   docker system prune -af

   # 2. CHANGE DIRECTORY BEFORE COMPOSE RUNS
   docker compose pull && docker compose up -d
else
   echo "       No containers found. Restarting Immich..."
   # 3. CHANGE DIRECTORY HERE AS WELL
   docker compose pull && docker compose up -d
fi
echo "______________________________________________________________________"
