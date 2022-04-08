#!/bin/bash
# RCLONE UPLOAD CRON TAB SCRIPT - for a friend
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

# refer to https://crontab.guru if you want to adjust the time

# Exit if running
if [[ $(pidof -x "$(basename "$0")" -o %PPID) ]]; then
    exit 1
fi

# Local only, do not set as your rclone or mergerfs mount point for google
pathFrom="/media/mergerfs/local/media"

# Rclone Mount Path
pathTo="gcrypt:media"

# Your service account files
serviceAccounts=(
    "/docker/scripts/sa/bypass1.json"
    "/docker/scripts/sa/bypass2.json"
    "/docker/scripts/sa/bypass3.json"
)

rcloneLog="/media/logs/uploadmedia.log"

# IF $pathFrom is not a local disk then exit
if /bin/findmnt $pathFrom -o FSTYPE -n | grep fuse; then
    exit 1
fi

# Simple way to rotate log files.
if [ -f "$rcloneLog" ]; then
    if [ -f "$rcloneLog-1" ]; then
        rm -f "$rcloneLog-2"
        cp "$rcloneLog-1" "$rcloneLog-2"
    fi
    cp "$rcloneLog" "$rcloneLog-1"
    echo -n > $rcloneLog
fi

# Your current script is missing this
logTime=$(date +'%s')
echo "YYYY/MM/DD HH:MM:SS"

# Make sure files older than +1 min exist
if find $pathFrom -type f -mmin +1 | read; then

    echo "YYYY/MM/DD HH:MM:SS"
    echo "$(date "+%Y/%m/%d %T") RCLONE: UPLOAD STARTED" | tee -a $rcloneLog
    
    # We now loop through each file in $serviceAccounts
    for account in ${serviceAccounts[@]}; do

        echo "$(date "+%Y/%m/%d %T") RCLONE: Using SA '$account'" | tee -a $rcloneLog
        
        arguments=(
            "move" "-vP"
            "$pathFrom" "$pathTo"

            #"--config" "/your/path/rclone.conf"
            "--drive-service-account-file" "$account"

            "--exclude" "*UNPACK*/**"

            "--delete-empty-src-dirs"
            "--fast-list"
            
            "--min-age" "1m"
            "--drive-chunk-size" "128M"
            "--tpslimit" "12"
            "--tpslimit-burst" "12"
            "--transfers" "6"
            
            "--log-file" "$rcloneLog"
            
            "--dry-run" # comment this out if the script has a successful dry run.
        )
        
        rclone ${arguments[@]}
        
    done
    
    echo "$(date "+%Y/%m/%d %T") RCLONE: UPLOAD FINISHED IN $(($(date +'%s')-$logTime)) SECONDS" | tee -a $rcloneLog
    
fi
exit
