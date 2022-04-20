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
    #"/docker/scripts/sa/bypass1.json"
    #"/docker/scripts/sa/bypass2.json"
    #"/docker/scripts/sa/bypass3.json"
)

# RCLONE TEST RUN
# Enable/Disable rclone dry run
# true = Enabled,  false = Disabled
RCLONE_TEST=true

# IGNORE BASH VERSION
# If your version is not the same as the
# tested version, then the script will exit
#  True = Don't exit, False = Exit if versions dont match
IGNORE_VERSION=false

# ===================================
#            FUNCTIONS
# ===================================
# Minimum required age of files in order to upload
min_file_age() {
    echo "$(date "+%Y/%m/%d %T") SCRIPT: Looking for files older than 1 minute." | tee -a $RCLONE_LOG
    if find $PATH_FROM -type f -mmin +1 | read; then
        return 0
    fi
    echo "$(date "+%Y/%m/%d %T") SCRIPT: No files matching criteria" | tee -a $RCLONE_LOG
    return 1
}
# Rotates logs based on rize
rotate_log() {
    MAX_SIZE=1000000 # 1MB

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

    (
        echo "YYYY/MM/DD HH:MM:SS"
        echo "-------------------------------------------------------"
        echo "$(date "+%Y/%m/%d %T") SCRIPT: RCLONE UPLOAD SCRIPT"
        echo "            Script Version: 2.1"
        echo "       Tested Linux Version: 21.10"
        echo "               Bash Version: 5.1.8(1)-release"
        echo "          Your Bash Version: ${BASH_VERSION}"
        echo "-------------------------------------------------------"
    ) | tee -a $RCLONE_LOG

    # Safey checks
    IS_EXIT=false
    if [[ "${BASH_VERSINFO:-0}" -lt 5 ]] && ! $IGNORE_VERSION; then
        (
            echo "$(date "+%Y/%m/%d %T") SCRIPT: WARNING - Your bash version hasn't been tested"
            echo "                            Set IGNORE_VERSION=true if you wish to continue"
            echo ""
        )  | tee -a $RCLONE_LOG
        IS_EXIT=true
    fi

    if ! which flock > /dev/null 2>&1; then
        echo "$(date "+%Y/%m/%d %T") SCRIPT: ERROR - unable to find 'flock' command."
        IS_EXIT=true
    fi

    # If Source path is fuse mount, log and exit
    if /bin/findmnt $PATH_FROM -o FSTYPE -n | grep fuse; then
        (
            echo "$(date "+%Y/%m/%d %T") SCRIPT: ERROR - Path not local '$PATH_FROM'"
        ) | tee -a $RCLONE_LOG
        IS_EXIT=true
    fi

    if [[ "$IS_EXIT" == true ]]; then
        echo "$(date "+%Y/%m/%d %T") SCRIPT: Exiting.."
        exit 1
    fi

    # Find files with future date and fix them.
    echo "$(date "+%Y/%m/%d %T") SCRIPT: Checking files for future modified dates" | tee -a $RCLONE_LOG
    find $PATH_FROM -type f -mtime -0  | while IFS= read p; do
        i=$(($i+1))
        if [[ -z $FOUND_FILES ]]; then
            echo "$(date "+%Y/%m/%d %T") SCRIPT: Found" | tee -a $RCLONE_LOG
            FOUND_FILES="onetime"
        fi
        RUN_TOUCH="$(touch "$p" 2>&1)"
        if [[ $? -ne 0 ]]; then
            echo "$(date "+%Y/%m/%d %T") SCRIPT: $(echo "$RUN_TOUCH" | grep -io "cannot touch '.*': Permission denied")" | tee -a $RCLONE_LOG
        fi
    done

    # Only run rclone if file age is greater than 1 minute
    if min_file_age; then
        
        echo "$(date "+%Y/%m/%d %T") SCRIPT: Checking rclone config" | tee -a $RCLONE_LOG
        # If we're using custom rclone config path
        if [[ -n $RCLONE_CONFIG ]]; then
            # Check config file exists
            if [[ -f $RCLONE_CONFIG ]]; then
                export RCLONE_CONFIG
                echo "$(date "+%Y/%m/%d %T") SCRIPT: Rclone using config file from custom path '$RCLONE_CONFIG'" | tee -a $RCLONE_LOG
            else
                echo "$(date "+%Y/%m/%d %T") SCRIPT: Rclone config not found in custom path '$RCLONE_CONFIG'" | tee -a $RCLONE_LOG
            fi
        fi

        # Verify rclone can use config
        RCLONE_GREP="$(echo "$(rclone config show 2>&1)" | grep -o 'Config file ".*" not found')"
        if [[ -n "$RCLONE_GREP" ]]; then
            (
                echo "$(date "+%Y/%m/%d %T") RCLONE: $RCLONE_GREP"
                echo "$(date "+%Y/%m/%d %T") SCRIPT: Exiting.."
            )| tee -a $RCLONE_LOG
            exit 1
        fi

        (
            echo "$(date "+%Y/%m/%d %T") SCRIPT: Calling Rclone move"
            echo ""
            if [[ "$RCLONE_TEST" == true ]]; then
                echo "$(date "+%Y/%m/%d %T") RCLONE: Dry run enabled, no action will be taken"
            fi
        )  | tee -a $RCLONE_LOG

        # Loop through service accounts
        for ACCOUNT in ${SERVICE_ACC[@]}; do
            # Log what Service Account we're using
            echo "$(date "+%Y/%m/%d %T") RCLONE: Using SA '$ACCOUNT'" | tee -a $RCLONE_LOG

            # Rclone arguments
            RCLONE_ARG=(
                "move" "-vP"
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
            
            # Timer
            TIMESTAMP=$(date +'%s')

            # Run rclone with arguments
            rclone ${RCLONE_ARG[@]}
            
            echo "$(date "+%Y/%m/%d %T") RCLONE: Upload finnished in $(($(date +'%s')-$TIMESTAMP)) SECONDS" | tee -a $RCLONE_LOG
            echo "" | tee -a $RCLONE_LOG
            # Exit loop if no more files to upload
            if ! min_file_age; then
                break
            fi
        done
    fi
    
    echo "$(date "+%Y/%m/%d %T") SCRIPT: Exiting.." | tee -a $RCLONE_LOG
) 200>$FLOCK_KEY

# REF
# https://www.tothenew.com/blog/foolproof-your-bash-script-some-best-practices/
# https://stackoverflow.com/questions/1715137/what-is-the-best-way-to-ensure-only-one-instance-of-a-bash-script-is-running
