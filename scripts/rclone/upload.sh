#!/bin/bash
#
#  RCLONE SETUP
#

# Config Path - Leave empty if you are using the default path
RCLONE_CONFIG=""
# Source Path - Must be a local path.
PATH_FROM="/media/mergerfs/local/media/"
# Destination Path - Rclone Mount Path
PATH_TO="gcrypt:/media/"
# Rclone full log path
RCLONE_LOG="/media/logs/uploadmedia.log"
# Rclone --dry-run
RCLONE_TEST=true
# true = Enabled,  false = Disabled
# Dry Run Documentation: https://rclone.org/docs/#n-dry-run

#
#  SERVICE ACCOUNTS
#
# The following settings assume you have 100 SA accounts 
# Inside the path /docker/scripts/sa, with the following
# name format "bypass1, bypass2 etc.."

# Service Account path
SA_PATH="/docker/scripts/sa"
# Service Account name Only.
SA_NAME="bypass"
# What account to start with
SA_START=1
# How many accounts in total
SA_END=100

# The values above start with /docker/scripts/sa/bypass1.json
# Then move to /docker/scripts/sa/bypass2.json and so on...
# Before ending with /docker/scripts/sa/bypass100.json

#
#  MONITOR FOLDER SIZE
#
# This monitors the size of PATH_FROM (your source path),
# By default it will wait until you have 250GB worth of data
# before it uploads, however, in order to prevent an infinit loop,
# I have added a limit to how many times it can check the total size
# before it just ignores this and uploads whatever files are available.

# Minimum folder size before upload starts
MONITOR_MIN_SIZE=250
# Timer - How long, in minutes, to sleep before rechecking folder size
MONITOR_TIMER=5
# Repeat - how many times to loop before skipping this check
MONITOR_REPEAT=36

# Based on the above values that I have set,
# then if there is less than 250G available to upload
# It will recheck the size 36 times and sleep for 5 minutes in between each loop,
# 36 x 5 minutes = 180 minutes, so if you don't have at least 250GB
# available to upload within 3 hours, it will skip this check and just upload
# whatever files you have available for uploading.

#
#  FUNCTIONS
#

# Directory Size

dir_size() {
    dir=${PWD}
    if [ "$1" != "" ]; then
        dir=$1
    fi
    echo `du -s --block-size=1G $dir | awk '{print $1}'`
}

# Rotates logs based on size
rotate_log() {
    MAX_SIZE=1000000 # 1MB in B
    
    if [[ $(stat -c%s "$RCLONE_LOG" 2>/dev/null) -ge $MAX_SIZE ]]; then

        GET_NAME="$(basename -- "$RCLONE_LOG")"
        PATH_NOEXT="$(dirname -- "$RCLONE_LOG")/${GET_NAME%.*}"
        FILE_EXT="${GET_NAME##*.}"

        REMOVE_OLDEST=true
        
        for i in {2..1}; do
            if [[ -f "$PATH_NOEXT-$i.$FILE_EXT" ]]; then
                if [[ "$REMOVE_OLDEST" == true ]]; then
                    rm -f "$PATH_NOEXT-$i.$FILE_EXT"
                else
                    mv "$PATH_NOEXT-$i.$FILE_EXT" "$PATH_NOEXT-$((i+1)).$FILE_EXT"
                fi
            fi
            REMOVE_OLDEST=false
        done

        mv "$RCLONE_LOG" "$PATH_NOEXT-1.$FILE_EXT"

    fi
}

#
# MAIN CODE
#
FLOCK_KEY="/var/lock/$(basename $0 .sh)"
(
    # if already running then exit
    flock -x -w 5 200 || { echo "scripts in use"; exit 1; }
    
    # If source path is a fuse mount, log and exit for safety.
    if /bin/findmnt $PATH_FROM -o FSTYPE -n | grep fuse; then
        echo "$(date "+%Y/%m/%d %T") SCRIPT: ERROR - Path not local '$PATH_FROM'" | tee -a $RCLONE_LOG
        exit 1
    fi

    # Find files with future date and fix them.
    find $PATH_FROM -type f -mtime -0  | while IFS= read p; do

        i=$(($i+1))

        if [[ -z $FOUND_FILES ]]; then
            (
                echo "$(date "+%Y/%m/%d %T") SCRIPT: Found files with corrupted future date."
                echo "$(date "+%Y/%m/%d %T") SCRIPT: Attempting to use touch command to fix them."
            ) | tee -a $RCLONE_LOG
            FOUND_FILES="onetime"
        fi

        RUN_TOUCH="$(touch "$p" 2>&1)"

        if [[ $? -ne 0 ]]; then
            echo "$(date "+%Y/%m/%d %T") SCRIPT: $(echo "$RUN_TOUCH" | grep -io "cannot touch .*")" | tee -a $RCLONE_LOG
        fi

    done

    # If we're using custom rclone config path
    if [[ -n $RCLONE_CONFIG ]]; then
        # Check config file exists
        if [[ -f $RCLONE_CONFIG ]]; then
            export RCLONE_CONFIG
        fi
    fi

    while [ $SA_START -le $SA_END ]; do

        # Rotate logs
        rotate_log

        # Create SA filepath
        SA_FILEPATH="$SA_PATH/$SA_NAME$SA_START.json"
        
        # Increment counter for next file
        let SA_START=SA_START+1
        
        # Make sure the SA json file exists
        if [[ ! -f "$SA_FILEPATH" ]]; then

            echo "$(date "+%Y/%m/%d %T") SCRIPT: Unable to find SA File; '$SA_FILEPATH'" | tee -a $RCLONE_LOG
            continue
            
        fi
        
        echo "$(date "+%Y/%m/%d %T") RCLONE: Running Service File '$SA_FILEPATH'" | tee -a $RCLONE_LOG
        
        # If the total size of our path is not larger than our minimum size, then wait.
        MON_REP=1
        while [ $(dir_size $PATH_FROM) -lt $MONITOR_MIN_SIZE ]; do
            if [ $MON_REP -gt $MONITOR_REPEAT ]; then
                echo "$(date "+%Y/%m/%d %T") SCRIPT: Size check limit exceeded, moving to process any available files." | tee -a $RCLONE_LOG
                break
            fi

            echo "$(date "+%Y/%m/%d %T") SCRIPT: Size Check $MON_REP/$MONITOR_REPEAT, next check in $MONITOR_TIMER minutes." | tee -a $RCLONE_LOG

            sleep $(($MONITOR_TIMER * 60))
            
            let MON_REP=MON_REP+1
        done

        # Rclone arguments
        RCLONE_ARG=(
            "move" "-vv" # vv = debug
            "$PATH_FROM" "$PATH_TO"
            "--drive-service-account-file" "$SA_FILEPATH"

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
        )

        # Include dry run if enabled
        if [[ "$RCLONE_TEST" == true ]]; then
            RCLONE_ARG+=("--dry-run")
        fi

        # Run rclone with arguments
        rclone ${RCLONE_ARG[@]}
        
        (
            echo "$(date "+%Y/%m/%d %T") RCLONE: Exiting Service File '$SA_FILEPATH'"
            echo ""
        ) | tee -a $RCLONE_LOG
        
    done
) 200>$FLOCK_KEY
