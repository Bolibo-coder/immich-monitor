echo "######################################################################"
echo "#    Executed on: $(date +"%Y-%m-%d %H:%M:%S")                                #"
echo "######################################################################"

if [ -n "$(ctr -n moby leases ls -q)" ]; then
   echo "Removing all containerd snapshots...";
   ctr -n moby leases rm $(ctr -n moby leases ls -q);
   echo "Removing all Immich containers..."
   docker rm -f immich_server immich_postgres immich_machine_learning immich_redis
   echo "Restarting Immich..."
   docker compose pull && docker compose up -d
else
   echo "Restarting Immich..."
   docker compose pull && docker compose up -d
fi