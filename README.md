immich-monitor.sh

Immich keeps database disk running 24/7 This script pauses immich containers ($MONITOR_CONTAINERS) when there is no $PORT activity and unpauses Immich when any activity is detected. Uses tcpdump and saves logs in $LOGFILE can be installed as system service - see immich-monitor.readme and immich-monitor.service

tested on Debian
__________________________________________________________________________________________________________________


immich-release.disk.space.sh

Immich containerd will create snapshots that will fill up the whole disk.  This script runs as cron and deletes the snapshots periodically.

tested on debian
