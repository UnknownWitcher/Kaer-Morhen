#!/bin/bash
# RCLONE UPLOAD SCRIPT - for a friend
#
# rclone --dry-run is enabled to allow you to test this script before using it.
# you just need to comment that line out or just remove it from arguments=() 
#
# If you use a custom config path, then comment out
# --config line within arguments=() then replace
# "/your/path/rclone.conf" with your config location.
# 
# I'm assuming you're using terminal/ssh with nano installed
# How to install script and configure crontab
# (replace each path/filename if needed)
#  type: touch /docker/scripts/rclone-upload.sh
#  type: chmod a+x /docker/scripts/rclone-upload.sh
#  type: nano /docker/scripts/rclone-upload.sh
# Press: CTRL + Shift + V to paste this code or use CTRL + INSERT
# Press: CTRL + X to exit
#        Save Modified buffer?
# Press: Y
# Press: Enter
#  The following will set the script to run every 30 minutes
#  type: crontab -e
#  type: 30 * * * * /docker/scripts/rclone-upload.sh >/dev/null 2>&1
# Press: CTRL + X to exit
#        Save Modified buffer?
# Press: Y
# Press: Enter
#
# refer to https://crontab.guru if you want to adjust the time

# Exit if already running
if pidof -o %PPID -x "$0" > /dev/null 2>&1; then
    echo "Already running.."
    exit 1
fi

# Local only, do not set as your rclone or mergerfs mount point
PATH_FROM="/media/mergerfs/local/media/"

# Rclone Mount Path
PATH_TO="gcrypt:/media/"

# Your service account files
SERVICE_ACC=(
    "/docker/scripts/sa/bypass.json"
    "/docker/scripts/sa/bypass1.json"
    "/docker/scripts/sa/bypass2.json"
    "/docker/scripts/sa/bypass3.json"
)

RCLONE_LOG="/media/logs/uploadmedia.log"

# IF PATH_FROM is not a local disk then exit
if /bin/findmnt $PATH_FROM -o FSTYPE -n | grep fuse; then
    echo "YYYY/MM/DD HH:MM:SS" | tee -a $RCLONE_LOG
    echo "$(date "+%Y/%m/%d %T") SYSTEM: not local path '$PATH_FROM'" | tee -a $RCLONE_LOG
    exit 1
fi

# Simple way to rotate log files
# Can be removed if you have something else handling it
if [ -f "$RCLONE_LOG" ]; then
    if [ -f "$RCLONE_LOG-1" ]; then
        rm -f "$RCLONE_LOG-2"
        cp "$RCLONE_LOG-1" "$RCLONE_LOG-2"
    fi
    cp "$RCLONE_LOG" "$RCLONE_LOG-1"
    echo -n > $RCLONE_LOG
fi

# Find files in PATH_FROM with wrong mod date
# Change mod date/time to 1 minute ago
find $PATH_FROM -type f -mtime -1 -exec touch {} -d "-1 minute" \;

sleep 1

# Make sure files older than +1 min exist
if find $PATH_FROM -type f -mmin +1 | read; then
    # Your current script is missing this
    LOGTIME=$(date +'%s')
    
    echo "YYYY/MM/DD HH:MM:SS" | tee -a $RCLONE_LOG
    echo "$(date "+%Y/%m/%d %T") RCLONE: UPLOAD STARTED" | tee -a $RCLONE_LOG
    
    # We now loop through each file in $serviceAccounts
    for ACCOUNT in ${SERVICE_ACC[@]}; do

        echo "$(date "+%Y/%m/%d %T") RCLONE: Using SA '$ACCOUNT'" | tee -a $RCLONE_LOG
        
        RCLONE_ARG=(
            "move" "-vP"
            "$PATH_FROM" "$PATH_TO"

            #"--config" "/your/path/rclone.conf"
            "--drive-service-account-file" "$ACCOUNT"

            "--exclude" "*UNPACK*/**"

            "--delete-empty-src-dirs"
            "--fast-list"
            "--max-transfer" "700G"
            
            "--min-age" "1m"
            "--drive-chunk-size" "128M"
            "--tpslimit" "12"
            "--tpslimit-burst" "12"
            "--transfers" "6"
            "--log-file" "$RCLONE_LOG"
            
            "--dry-run" # comment this out if the script has a successful dry run.
        )
        
        rclone ${RCLONE_ARG[@]}
        
    done
    
    echo "$(date "+%Y/%m/%d %T") RCLONE: UPLOAD FINISHED IN $(($(date +'%s')-$LOGTIME)) SECONDS" | tee -a $RCLONE_LOG
    
fi

exit
