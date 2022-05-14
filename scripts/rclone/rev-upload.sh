#!/bin/bash
# WARNING THIS IS CURRENTLY BEING TESTED
# ===================================
#          CONFIGURATION
# ===================================
# Custom config
# Leave empty to use default
RCLONE_CONFIG=""

# SOURCE PATH, UPLOAD FROM
# local path only, Must not be fuse mount path
PATH_FROM="/mnt/media/local/Shows"

# DESTINATION PATH, UPLOAD TO
# rclone_mount:folder
PATH_TO="gd_shows:Shows"

# FULL LOG PATH
RCLONE_LOG="/mnt/appdata/rclone/logs/upload.log"

# SERVICE ACCOUNTS
SERVICE_ACC=(
    "/docker/scripts/sa/bypass.json"
    "/docker/scripts/sa/bypass1.json"
    "/docker/scripts/sa/bypass2.json"
    "/docker/scripts/sa/bypass3.json"
)

# RCLONE TEST RUN
# Enable/Disable rclone dry run
# true = Enabled,  false = Disabled
RCLONE_TEST=true

# ===================================
#            FUNCTIONS
# ===================================
# Minimum Files, checked at the end of each rclone run
min_file_age() {
    if find "$PATH_FROM" -type f -mmin +1 | read; then
        return 0
    fi
    return 1
}
# Rotates logs based on size
rotate_log() {
    MAX_SIZE=1000000 # 1MB in B

    if [[ $(stat -c%s "$RCLONE_LOG") -ge $MAX_SIZE ]]; then

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
# ===================================
#           MAIN CODE
# ===================================
# flock ensures 1 instance runs at a time.
FLOCK_KEY="/var/lock/$(basename $0 .sh)"
(
    # if already running then exit
    flock -x -w 5 200 || { echo "scripts in use"; exit 1; }
    
    # Rotate logs
    rotate_log

    # If Source path is fuse mount, log and exit
    if /bin/findmnt $PATH_FROM -o FSTYPE -n | grep fuse; then
        (
            echo "$(date "+%Y/%m/%d %T") SCRIPT: ERROR - Path not local '$PATH_FROM'"
            echo "$(date "+%Y/%m/%d %T") SCRIPT: Exiting.."
        ) | tee -a $RCLONE_LOG
        exit 1
    fi

    # Find files with future date and fix them.
    IS_EXIT=false
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

    # If we're using custom config path for rclone then export it.
    if [[ -n $RCLONE_CONFIG ]]; then
        if [[ -f $RCLONE_CONFIG ]]; then
            export RCLONE_CONFIG
        fi
    fi

    for ACCOUNT in ${SERVICE_ACC[@]}; do
        # Log what Service Account we're using
        echo "$(date "+%Y/%m/%d %T") RCLONE: Using SA '$ACCOUNT'" | tee -a $RCLONE_LOG

        # Rclone arguments
        RCLONE_ARG=(
            "move" "-vv" # vv = debug, vP is what we normally want to use
            "$PATH_FROM" "$PATH_TO"
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
        )

        # Include dry run if enabled
        if [[ "$RCLONE_TEST" == true ]]; then
            RCLONE_ARG+=("--dry-run")
        fi
        
        # Run rclone with arguments
        rclone ${RCLONE_ARG[@]}

        # Exit loop early if no more files to upload
        if ! min_file_age; then
            break
        fi

        echo "" | tee -a $RCLONE_LOG
    done

) 200>$FLOCK_KEY
