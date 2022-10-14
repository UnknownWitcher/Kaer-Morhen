#!/bin/bash
# -- Configuration -->

# Service Account directory, this should only contain json files for SA)
SA_JSON_FOLDER="/mnt/shared/config/rclone/sa"

# Where to upload from, local path only
RC_SOURCE=(
    "/mnt/shared/fusemounts/local/Shows"
    "/mnt/shared/fusemounts/local/Films"
)
# Where are we uploading to mount:folders
RC_DESTINATION=(
    "shows:Shows"
    "films:Films"
)

# Rclone config; leave blank for default config path
RC_CONFIG="/mnt/shared/config/rclone.conf"

# RC MOVE ARGUMENTS
RC_SETTINGS=(
    #"--exclude" "*UNPACK*/**"

    "--delete-empty-src-dirs"
    "--fast-list"

    "--max-transfer" "750G"
    "--min-age" "1m"
    #"--bwlimit" "20M:5M"
    "--drive-chunk-size" "64M"
    "--tpslimit" "12"
    "--tpslimit-burst" "12"
    "--transfers" "6"
)

# Path to log file
RC_LOG_FILE="/mnt/shared/logs/rclone/new-upload.log"

# Type of logging you prefer, leave blank for default
RC_LOG_TYPE="-q"  # -q, -v, -vv https://rclone.org/docs/#logging

# Rclone trial run with no permanent changes
# True = Enabled, False = Disabled
RC_DRY_RUN=false # https://rclone.org/docs/#n-dry-run

# Service Account rules - for switching SA's
SA_RULES=(
    "limit" 1                         # The maximum number of rules that need to apply before action is taken
    "more_than_750" true              # Current SA has passed the daily upload quota
    "user_rate_limit" true            # Rclone has prompted the rate limit error for current SA
    "all_transfers_zero" true         # Current transfer size of all transfers is 0
    "no_transfer_between_checks" true # The amount of transfers during 100 checks is 0
)

# Wait between rclone checks
CHECK_AFTER_START=60 # Wait X seconds after rclone has started
CHECK_INTERVAL=60    # Check rclone stats every x seconds

# <-- Configuration --
OLD_UMASK=$(umask)
umask 002 > /dev/null 2>&1
FLOCK_KEY="/var/lock/$(basename $0 .sh)"
(
    
    flock -x -w 5 200 || { echo "scripts in use"; exit 1; }
    
    # -- Functions -->
    # Get next service account from path
    get_next_sa() { # works
        local NEXT_INDEX=0
        if [[ -n $1 ]]; then
            local i=0
            while [ $i -lt ${#SA_FILES[@]} ]; do
                if [[ "${SA_FILES[$i]}" == "$1" ]]; then
                    let NEXT_INDEX=$i+1
                    break
                fi
                let i=i+1
            done
        fi
        if [[ $NEXT_INDEX -ge ${#SA_FILES[@]} ]]; then
            NEXT_INDEX=0
        fi
        echo "${SA_FILES[$NEXT_INDEX]}"
    }
    # Handles the logging situation
    log_handler() { # works
        if [[ "$1" == "debug" ]]; then
            if [[ "$RC_LOG_TYPE" != "-vv" ]]; then
                return 0
            fi
            LOG_TYPE="DEBUG  "
        elif [[ "$1" == "error" ]]; then
            LOG_TYPE="ERROR  "
        elif [[ "$1" == "warning" ]]; then
            LOG_TYPE="WARNING"
        else
            LOG_TYPE="NOTICE "
        fi
        local LOG_MSG=""
        while read INPUTLINE; do
            LOG_MSG="$(date "+%Y/%m/%d %T") $LOG_TYPE: $INPUTLINE"
            if [[ -n "$RC_LOG_FILE" ]]; then
                echo "$LOG_MSG" | tee -a $RC_LOG_FILE
            else
                echo "no-file $LOG_MSG"
            fi
        done
    }
    rotate_logs() { # works
        MAX_SIZE=$(pow 1000 2)        # Default 1MB in B
        if [[ -n $1 ]]; then
            let MAX_SIZE=$1*1000 # B TO KB
        fi
        if [[ $(stat -c%s "$RC_LOG_FILE" 2>/dev/null) -ge $MAX_SIZE ]]; then

            GET_NAME="$(basename -- "$RC_LOG_FILE")"
            PATH_NOEXT="$(dirname -- "$RC_LOG_FILE")/${GET_NAME%.*}"
            FILE_EXT="${GET_NAME##*.}"

            REMOVE_OLDEST=true
            
            for i in {4..1}; do
                if [[ -f "$PATH_NOEXT-$i.$FILE_EXT" ]]; then
                    if [[ "$REMOVE_OLDEST" == true ]]; then
                        rm -f "$PATH_NOEXT-$i.$FILE_EXT"
                    else
                        cp "$PATH_NOEXT-$i.$FILE_EXT" "$PATH_NOEXT-$((i+1)).$FILE_EXT"
                    fi
                fi
                REMOVE_OLDEST=false
            done

            cp "$RC_LOG_FILE" "$PATH_NOEXT-1.$FILE_EXT"
            
            : > "$RC_LOG_FILE"
        fi
    }
    # No easy way to test for arrays
    is_array() { # works
        # no argument passed
        if [[ $# -ne 1 ]]; then
            echo "'is_array' missing var" | log_handler "error"
            exit 1
        fi
        local var=$1
        # use a variable to avoid having to escape spaces
        local regex="^declare -[aA] ${var}(=|$)"
        [[ $(declare -p "$var" 2> /dev/null) =~ $regex ]] && return 0
    }

    session_config() { # works
        IS_EXIT=false
        
        if [[ ! -n $1 ]]; then
            echo "'session_config' missing case selector" | log_handler "error"
            IS_EXIT=true
        fi
        if [[ ! -n $2 ]]; then
            echo "'session_config' missing key" | log_handler "error"
            IS_EXIT=true
        fi
        if $IS_EXIT; then
            exit 1
        fi
        
        local database="$(dirname -- "$0")/uploaded.db"

        local TABLE=$(sqlite3 "$database" "CREATE TABLE IF NOT EXISTS config (id INTEGER PRIMARY KEY, name TEXT NOT NULL, value TEXT NOT NULL);" 2>&1)
        
        if [[ $? -ne 0 ]]; then
            echo "'session_config' $TABLE" | log_handler "error"
            exit 1
        fi
        
        case $1 in
            "get")
                local QUERY="SELECT value FROM config WHERE name='${2}';"
                ;;
            "save")
                if [[ ! -n $3 ]]; then
                    echo "'session_config save' missing value" | log_handler "error"
                    exit 1
                fi
                local QUERY="INSERT OR REPLACE INTO config(id, name,value) VALUES ((SELECT id FROM config WHERE name='${2}'),'${2}', '${3}');"
                ;;
            *)
                echo "'session_config' unknown case selector $2" | log_handler "error"
                exit 1
                ;;
        esac

        local RESULT=$(sqlite3 "$database" "$QUERY" 2>&1)

        if [[ $? -ne 0 ]]; then
            echo "'session_config' $RESULT" | log_handler "error"
            exit 1
        fi
        
        if [[ "$1" == "get" ]]; then
            echo $RESULT
        fi
    }
    rclone_pid() { # works
        IS_EXIT=false
        if [[ ! -n $1 ]]; then
            echo "'rclone_pid' missing case selector" | log_handler "error"
            IS_EXIT=true
        fi
        local PID=$2
        if [[ $((PID=PID*1)) -eq 0 ]]; then
            echo "'rclone_pid' invalid PID must be an intiger greater than 0" | log_handler "error"
            IS_EXIT=true
        fi
        if $IS_EXIT; then
            exit 1
        fi
        case $1 in
            kill)
                if $(ps -p $PID | grep -i 'rclone' > /dev/null); then
                    kill $PID
                fi
                return 0
                ;;
            find)
                if $(ps -p $PID | grep -io 'rclone' > /dev/null); then
                    return 0
                fi
                ;;
        esac

        return 1
    }
    # json METHOD DATA KEY DEFAULT
    # json get json_raw name false
    # json make array
    json() {  # works
        local METHOD=$1

        case $METHOD in
            'get')
                local DATA=$2
                if [[ ! -n $DATA ]]; then
                    echo "'json' missing data." | log_handler "error"
                    exit 1
                fi
                local KEY=$3
                if [[ ! -n $KEY ]]; then
                    echo "'json' cannot get vallue missing key." | log_handler "error"
                    exit 1
                fi
                local DEFAULT=$4
                
                local VALUE=$(echo "$DATA" | jq -r ".${KEY}" 2>&1)
                if [[ $? -ne 0 ]]; then
                    echo "$VALUE" | log_handler "error"
                    exit 1
                fi
                if [[ ! -n $VALUE ]]; then 
                    if [[ -n $DEFAULT ]]; then 
                        VALUE="$DEFAULT"
                    fi
                fi

                echo $VALUE
                ;;
            'make')
                shift
                local ARRAY=("$@")
                if [[ ${ARRAY[@]} == "" ]]; then
                    echo "'json' cannot get value missing key." | log_handler "error"
                    exit 1
                fi
                local i=0
                while [[ $i -lt ${#ARRAY[@]} ]]; do
                    if [[ $i -eq 0 ]]; then
                        local JSON="\"${ARRAY[$i]}\":"
                    else
                        JSON+=", \"${ARRAY[$i]}\":"
                    fi

                    JSON+="\"${ARRAY[$((i+1))]}\""
                    
                    let i=i+2
                done
                echo "{$JSON}"
                ;;
            *)
                echo "'json' missing case selector" | log_handler "error"
                exit 1
            ;;
        esac
    }
    pow() {
        local i=1
        local NUM=$1
        while [[ $i -lt $2 ]]; do
            let NUM=NUM*$1
            let i=i+1
        done 
        echo $NUM
    }
    # <-- Functions --
    # -- Main -->
    IS_EXIT=false

    # Check for requirements
    if ! which rclone >/dev/null; then
        echo "Mising requirement 'rclone': https://rclone.org/install/" | log_handler "warning"
        IS_EXIT=true
    fi
    if ! which jq >/dev/null; then
        echo "Mising requirement 'jq': install jq" | log_handler "warning"
        IS_EXIT=true
    fi
    if ! which sqlite3 >/dev/null; then
        echo "Mising requirement 'sqlite3': install sqlite3" | log_handler "warning"
        IS_EXIT=true
    fi
    if ! which awk >/dev/null; then
        echo "Mising requirement 'awk': install awk" | log_handler "warning"
        IS_EXIT=true
    fi

    # Check SA accounts exist
    if [[ ! -d $SA_JSON_FOLDER ]]; then
        echo "Missing folder '$SA_JSON_FOLDER'" | log_handler "error"
        IS_EXIT=true
    fi

    # Convert non-array to array
    if ! is_array RC_SOURCE; then
        RC_SOURCE=($RC_SOURCE)
    fi
    if ! is_array RC_DESTINATION; then
        RC_DESTINATION=($RC_DESTINATION)
    fi
    # Compare Arrays
    if [[ ${#RC_SOURCE[@]} -gt ${#RC_DESTINATION[@]} ]]; then
        echo "RC_SOURCE out of RC_DESTINATION range" | log_handler "error"
        IS_EXIT=true
    else
        if [[ ${#RC_SOURCE[@]} -lt ${#RC_DESTINATION[@]} ]]; then
            echo "RC_DESTINATION out of RC_SOURCE range" | log_handler "error"
            IS_EXIT=true
        fi
    fi
    # Test RC_CONFIG
    if [[ -n $RC_CONFIG ]]; then
        if [[ -f $RC_CONFIG ]]; then
            RC_SETTINGS+=("--config" "$RC_CONFIG")
        else
            echo "Custom rclone config '$RC_CONFIG' is missing" | log_handler "error"
            IS_EXIT=true
        fi
    fi
    # Validate RC_SETTINGS
    if [[ -n "$RC_SETTINGS" ]]; then
        if ! is_array RC_SETTINGS; then
            echo "RC_SETTINGS must be an array" | log_handler "error"
            IS_EXIT=true
        fi
    else
        echo "RC_SETTINGS is missing, must be an array" | log_handler "error"
        IS_EXIT=true
    fi

    if $IS_EXIT; then
        exit 1
    fi

    # Fix missing log file
    if [[ ! -n "$RC_LOG_FILE" ]]; then
        RC_LOG_FILE="$(dirname -- "$0")/upload.log"
    fi

    # Validate Log and Log Type
    #if [[ "${RC_SETTINGS[@]}" != *"-vv"* ]]; then
    #    if [[ "${RC_SETTINGS[@]}" != *"-v"* ]]; then
    #        if [[ ! -n $RC_LOG_TYPE ]]; then
    #            RC_LOG_TYPE=("-v")
    #        fi
    #    fi
    #fi
    if [[ "${RC_SETTINGS[@]}" != *"--log-file"* ]]; then
        if [[ -n $RC_LOG_FILE ]]; then
            RC_SETTINGS+=("--log-file" "$RC_LOG_FILE")
        else
            echo "LOG_FILE not set" | log_handler "error"
            exit 1
        fi
    fi

    # Fix missing --rc arguments
    if [[ "${RC_SETTINGS[@]}" != *"--rc"* ]]; then
        RC_SETTINGS+=("--rc")
    fi

    # Determins if we need to add dry-run to rclone
    if $RC_DRY_RUN; then 
        if [[ "${RC_SETTINGS[@]}" != *"--dry-run"* ]]; then
            RC_SETTINGS+=("--dry-run")
        fi
    fi

    SA_RULES=$(json make "${SA_RULES[@]}")

    # Convert file list to array
    readarray -t SA_FILES <<<$(find "$SA_JSON_FOLDER" -name "*.json" -type f -print)

    # Validate array
    if [[ ${#SA_FILES[@]} -eq 0 ]]; then
        echo "JSON files not found in '$SA_JSON_FOLDER'" | log_handler "error"
        exit 1
    fi

    # Get Last PID
    LAST_PID=$(session_config get PID)
    if [[ -n $LAST_PID ]]; then
        rclone_pid kill $LAST_PID
    fi
    # Get Last SA Job
    LAST_SA="$(session_config get LAST_SA)"
    if [[ ! -f $LAST_SA ]]; then
        LAST_SA=""
    fi
    
    # Rotate logs if needed
    rotate_logs

    # Switching SA Accounts
    i=0
    while :; do
        if [["$RC_LOG_TYPE" == "-vv"]]; then
            echo "Selecting Service Account........" | log_handler 
            echo "Last SA: $LAST_SA" | log_handler 
        fi
        
        SA_NOW=$(get_next_sa $LAST_SA)
        LAST_SA="$SA_NOW"
        
        if [["$RC_LOG_TYPE" == "-vv"]]; then
            echo "Now SA: $SA_NOW" | log_handler 
        fi
        
        if [[ ! -f "$SA_NOW" ]]; then # works
            echo "File missing '$SA_NOW'" | log_handler "warning"

            if [[ $((i=i+1)) -ge ${#SA_FILES[@]} ]]; then
                echo "No service account selected." | log_handler "error"
                exit 1
            fi

            continue
        fi

        session_config save LAST_SA $LAST_SA

        j=0
        while [[ $j -lt ${#RC_SOURCE[@]} ]]; do
        
            RC_ARGUMENTS=("move" $RC_LOG_TYPE "${RC_SOURCE[$j]}" "${RC_DESTINATION[$j]}" ${RC_SETTINGS[@]})
            let j=j+1
            
            find "${RC_SOURCE[$j]}" -mtime -0 -exec touch {} \;
            
            RC_ARG=(${RC_ARGUMENTS[@]} "--drive-service-account-file" "$SA_NOW")
            
            # Run rclone independently
            rclone ${RC_ARG[@]} &

            # Wait for rclone
            if [["$RC_LOG_TYPE" == "-vv"]]; then
                echo "Waiting $CHECK_AFTER_START seconds for rclone command: ${RC_ARG[@]}" | log_handler
            fi
            sleep $CHECK_AFTER_START
            
            # Get this rclone PID
            PID=$!
            if [[ $PID -gt 0 ]]; then
                session_config save PID $PID
            fi

            CNT_ERROR=0
            CNT_403_RETRY=0
            CNT_LAST_TRANS=0
            CNT_GET_RATE_LIMIT=False
            
            while :; do
                if [[ -f "$(dirname -- "$0")/upload.exit" ]]; then
                    echo "Found '$(dirname -- "$0")/upload.exit', exiting..." | log_handler
                    if rclone_pid find $PID; then
                        echo "rclone process still exists, killing process id '$PID'" | log_handler "warning"
                        rclone_pid kill $PID
                    fi
                    exit
                fi
                # Rotate Logs if needed
                rotate_logs

                # Get rcloens stats
                JSON_RESPONSE=$(rclone rc core/stats)
                if [[ $? -ne 0 ]]; then
                    let CNT_ERROR=CNT_ERROR+1

                    ERR_MSG="rclone check core/stats failed $CNT_ERROR/3 times," 

                    if [[ $CNT_ERROR -gt 3 ]]; then
                        if rclone_pid find $PID; then
                            echo "$ERR_MSG rclone process still exists, killing process id '$PID'" | log_handler "error"
                            rclone_pid kill $PID
                        fi
                        if [["$RC_LOG_TYPE" == "-vv"]]; then
                            echo "Too many failed attempts.." | log_handler "error"
                        fi
                        break 1
                    fi
                    if [["$RC_LOG_TYPE" == "-vv"]]; then
                        echo "$ERR_MSG Waiting $CHECK_INTERVAL seconds to recheck." | log_handler "warning"
                    fi
                    sleep $CHECK_INTERVAL

                    continue
                else
                    CNT_ERROR=0
                fi

                CNT_TRANSFER=$(json get "$JSON_RESPONSE" bytes 0)

                LOG_MSG="Transfer Status - Upload: "
                LOG_MSG+="$(echo "$(json get "$JSON_RESPONSE" bytes 0) $(pow 1024 3)" | awk '{printf "%.2f\n", $1/$2 }') GiB,"
                LOG_MSG+="Avg upspeed $(echo "$(json get "$JSON_RESPONSE" speed 0) $(pow 1024 2)" | awk '{printf "%.2f\n", $1/$2 }') MiB/s,"
                LOG_MSG+="Transfered $(json get "$JSON_RESPONSE" transfers 0)"

                echo "$LOG_MSG" | log_handler
                
                SHOULD_SWITCH=0
                SWITCH_REASON="Reason: "

                # Check 750GB daily quota
                if $(json get "$SA_RULES" more_than_750 false); then
                    if [[ $CNT_TRANSFER -gt $((750*$(pow 1024 3))) ]]; then

                        let SHOULD_SWITCH=SHOULD_SWITCH+1
                        SWITCH_REASON+="more_than_750, "

                    fi
                fi

                # Check rclone transfers
                if $(json get "$SA_RULES" no_transfer_between_checks false); then

                    if [[ $(($CNT_TRANSFER - $CNT_LAST_TRANS)) -eq 0 ]]; then
                        let CNT_403_RETRY=CNT_403_RETRY+1

                        if [[ $(($CNT_403_RETRY % 10 )) -eq 0 ]]; then
                            echo "Rclone has not transfered in $CNT_403_RETRY checks" | log_handler "warning"
                        fi

                        if [[ $CNT_403_RETRY -gt 100 ]]; then
                            let SHOULD_SWITCH=SHOULD_SWITCH+1
                            SWITCH_REASON+="no_transfer_between_checks, "
                        fi
                    fi

                else
                    CNT_403_RETRY=0
                    CNT_LAST_TRANS=$CNT_TRANSFER
                fi

                if $(json get "$SA_RULES" user_rate_limit false); then
                    LAST_ERROR=$(json get "$JSON_RESPONSE" lastError "")
                    if [[ "$LAST_ERROR" == *"userRateLimitExceeded"* ]]; then
                        let SHOULD_SWITCH=SHOULD_SWITCH+1
                        SWITCH_REASON+="'user_rate_limit', "
                    fi
                fi

                if $(json get "$SA_RULES" all_transfers_zero false); then

                    TRANSFER_FAILED=true
                    JSON_TRANSFER=$(json get "$JSON_RESPONSE" transferring "")
                    
                    if [[ "$JSON_TRANSFER" != "" ]]; then
                        if [[ "$JSON_TRANSFER" != *"[].bytes"* ]] || [[ "$JSON_TRANSFER" != *"[].speed"* ]]; then :
                        elif [[ $(json get "$JSON_TRANSFER" bytes 0) -ne 0 ]] && [[ $(json get "$JSON_TRANSFER" speed 0) -gt 0 ]]; then
                            TRANSFER_FAILED=false
                        fi
                    fi

                    if $TRANSFER_FAILED; then
                        let SHOULD_SWITCH=SHOULD_SWITCH+1
                        SWITCH_REASON+="'all_transfers_zero', "
                    fi

                fi
                SAR_LIMIT=$(json get "$SA_RULES" limit 1) 
                if [[ $SHOULD_SWITCH -gt $SAR_LIMIT ]]; then
                    if [[ $SAR_LIMIT -gt 1 ]]; then LOG_MSG="have been triggered"; else LOG_MSG="has been triggered"; fi
                    echo "ruleLimitsReached; $SWITCH_REASON $LOG_MSG." | log_handler "warning"
                    rclone_pid kill $PID
                    break 2
                fi

                sleep $CHECK_INTERVAL
            done

        done

    done
) 200>$FLOCK_KEY
# <-- Main --
umask $OLD_UMASK > /dev/null 2>&1
