#!/bin/bash
#
#  RCLONE
#
# Config Path - Leave empty if you are using the default path
RCLONE_CONFIG=""
# Source Paths - Must be a local path.
PATH_FROM=(
    "/mnt/shared/fusemounts/local/Shows"
    "/mnt/shared/fusemounts/local/Films"
)
# Destination Paths - Rclone Mount Path
PATH_TO=(
    "shows:Shows"
    "films:Films"
)
# Full log path
RCLONE_LOG="/media/logs/uploadmedia.log"
# Minimum File Age (in minutes)
RCLONE_MIN_AGE=1
# --dry-run
RCLONE_TEST=true

#
#  SERVICE ACCOUNTS
#
# Example:
# With Prefix /path/to/sa/account-1.json
# Without     /path/to/sa/1.json

# Json path
SA_PATH="/docker/scripts/sa"
# Json Prefix - leave blank if you just use numbers
SA_PREFIX=""
# What account to start with
SA_START=1
# How many accounts in total
SA_END=2

#
#  MONITOR
#
# Minimum folder size before upload starts
MONITOR_MIN_SIZE=250
# Timer - How long, in minutes, to sleep before rechecking folder size
MONITOR_TIMER=5
# Repeat - how many times to loop before skipping this check
MONITOR_REPEAT=1

#
# FUNCTIONS
#
PATH_SIZE() {
    dir=${PWD}

    if [[ ! -n $1 ]]; then
        dir=$1
    fi

    ARG=(
        "$dir"
        "-type" "f"
    )

    if [[ ! -n $2 ]]; then
        ARG+=("-mmin" "$2")
    fi
    
    ARG+=("-printf" "'%s\n'")

    find ${ARG[@]} | awk '{total=total+$1}END{printf("%.0f\n", total/1000)}'
    #find $dir -type f -mtime +1 -printf '%s\n' | awk '{total=total+$1}END{printf("%.2f\n", total/1000)}'
}
SQL() {
    if [[ ! -n $1 ]]; then
        exit 1
    fi

    case $1 in
        create)
            QUERY="CREATE TABLE IF NOT EXISTS activity (id INTEGER PRIMARY KEY, account TEXT NOT NULL, uploaded INTEGER NOT NULL, timestamp DATETIME NOT NULL DEFAULT (datetime(CURRENT_TIMESTAMP, 'localtime'));"
            ;;
        insert)
            IS_EXIT=false
            if [[ ! -n $2 ]]; then
                echo "Unable to insert activity, missing path value."
                IS_EXIT=true
            fi
            if [[ ! -n $3 ]]; then
                echo "Unable to insert activity, missing upload value."
                IS_EXIT=true
            fi
            if IS_EXIT; then
                exit 1
            fi
            QUERY="INSERT INTO activity(path, uploaded) VALUES ('${2}', '${3}')"
            ;;
        total_uploaded)
            if [[ ! -n $2 ]]; then
                echo "Unable to get total uploaded, missing path value."
                exit 1
            fi
            QUERY="SELECT IFNULL(SUM(uploaded),0) FROM activity WHERE path='${2}';"
            ;;
        last_activity)
            if [[ ! -n $2 ]]; then
                echo "Unable to get last activity, missing path value."
                exit 1
            fi
            QUERY="SELECT timestamp FROM activity ORDER BY timestamp DESC WHERE path='${2}' LIMIT 1;"
    esac

    sqlite3 "./upload.db" "$QUERY"
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

        # Increment counter for next SA_FILEPATH
        let SA_START=SA_START+1

        # Make sure the SA json file exists
        if [[ ! -f "$SA_FILEPATH" ]]; then

            echo "$(date "+%Y/%m/%d %T") SCRIPT: Unable to find SA File; '$SA_FILEPATH'" | tee -a $RCLONE_LOG
            continue
            
        fi

        echo "$(date "+%Y/%m/%d %T") RCLONE: Running Service File '$SA_FILEPATH'" | tee -a $RCLONE_LOG

        # If the total size of our path is not larger than our minimum size, then wait.
        COUNT=1
        while [ $(PATH_SIZE $PATH_FROM +1) -lt $MONITOR_MIN_SIZE ]; do
            if [ $COUNT -gt $MONITOR_REPEAT ]; then
                echo "$(date "+%Y/%m/%d %T") SCRIPT: Size check limit exceeded, moving to process any available files." | tee -a $RCLONE_LOG
                break
            fi

            echo "$(date "+%Y/%m/%d %T") SCRIPT: Size Check $COUNT/$MONITOR_REPEAT, next check in $MONITOR_TIMER minutes." | tee -a $RCLONE_LOG

            sleep $(($MONITOR_TIMER * 60))
            
            let COUNT=COUNT+1
        done

        # Rclone arguments
        RCLONE_ARG=(
            "move" "-vv" # vv = debug
            "$PATH_FROM" "$PATH_TO"
            #"--drive-service-account-file" "$SA_FILEPATH"

            "--exclude" "*UNPACK*/**"

            "--delete-empty-src-dirs"
            "--fast-list"
            "--max-transfer" "700G"
            
            "--min-age" "${RCLONE_MIN_AGE}m"
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
        
        # Start upload timer
        TIMESTAMP=$(date +'%s')

        # Run rclone with arguments
        echo "rclone ${RCLONE_ARG[@]}"

        # Calculate upload timer
        TIMESTAMP=$(($(date +'%s')-$TIMESTAMP))

        # Convert timestamp seconds into minutes
        SEC_TO_MIN=$(awk "BEGIN {print ($TIMESTAMP/60)+$RCLONE_MIN_AGE}")



    done
) 200>$FLOCK_KEY


TIMESTAMP=$(date +'%s')

sleep 30

TIMESTAMP=$(($(date +'%s')-$TIMESTAMP))

SEC_TO_MIN=$(awk "BEGIN {print ($TIMESTAMP/60)+$RCLONE_MIN_AGE}")

echo $TIMESTAMP

echo $SEC_TO_MIN

echo $(($RCLONE_MIN_AGE))
