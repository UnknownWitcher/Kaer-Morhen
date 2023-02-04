#!/bin/bash
# FILENAME EXAMPLE
# rclone-service-movies.sh,  rclone-service-series.sh
# rclone-movies.sh,  rclone-series.sh
#
# LOG PATH
LOG_PATH="/mnt/shared/logs/rclone"
#
# RCLONE API
#
# Address should not need changed
RCLONE_API_ADDR="127.0.0.1"
# Change the port for each "service" file you create.
RCLONE_API_PORT="5577"
# Random Username will be used if empty
RCLONE_API_USER=""
# Random Password will be used if empty
RCLONE_API_PASS=""
#
# RCLONE SETTINGS
#
RCLONE_SETTINGS=(
    "mount" "movies:" "/mnt/shared/fusemounts/movies"
    "--config" "/mnt/shared/config/rclone.conf"
    "--allow-other" "-v"
    "--dir-cache-time" "5000h"
    "--poll-interval" "10s"
    "--umask" "002"
    "--cache-dir" "/mnt/shared/fusemounts/cache"
    "--drive-pacer-min-sleep" "10ms"
    "--drive-pacer-burst" "200"
    "--vfs-cache-mode" "full"
    "--vfs-cache-max-size" "250G"
    "--vfs-cache-max-age" "5000h"
    "--vfs-cache-poll-interval" "5m"
)
#
# DISCORD WEBHOOK
#
DISCORD_URL="https://discord.com/api/webhooks/.."
#
# DO NOT EDIT BELOW THIS LINE
#
if [[ -z "${LOG_PATH}" ]]; then
    LOG_PATH="/mnt/shared/logs/rclone"
fi
if [[ -z "${RCLONE_API_USER}" ]]; then
    RCLONE_API_USER="${$(echo $RANDOM | base64 | awk '{print substr($0,1,7);exit}')}"
fi
if [[ -z "${RCLONE_API_PASS}" ]]; then
    RCLONE_API_PASS="${$(echo $RANDOM | base64 | awk '{print substr($0,1,7);exit}')}"
fi
if [[ -z "${RCLONE_API_ADDR}" ]]; then
    RCLONE_API_ADDR="127.0.0.1"
fi
if [[ -z "${RCLONE_API_PORT}" ]]; then
    RCLONE_API_PORT="5578"
fi

SCRIPT_PATH=$(realpath "$0")
RCLONE_API_HOST="${RCLONE_API_ADDR}:${RCLONE_API_PORT}"
LOG_PATH="${LOG_PATH%/}/$(basename "$0" .sh).log"

RCLONE_REMOTE=(
    "--rc-addr=${RCLONE_API_HOST}"
    "--rc-user=${RCLONE_API_USER}"
    "--rc-pass=${RCLONE_API_PASS}"
)
RCLONE_SETTINGS+=(
    "--log-file" "${LOG_PATH}"
    "--rc"
    "${RCLONE_REMOTE[@]}"
)
#
# FUNCTIONS
#
flock() { # Replacement for flock to fix trap issue
    local pid lock active_pid

    lock="$1"
    if [[ -f $lock ]];  then
        read -r pid < "$lock" > /dev/null 2>&1
        if [[ -n $pid ]]; then
            active_pid=$(ps -e -o pid,cmd | awk -v a="$pid" -v b="$SCRIPT_PATH" '$1==a && index($0,b) {print $1}')
            if [[ -n $active_pid ]]; then
                if [[ -n $2 ]]; then
                    echo "${2}"
                fi
                exit 0
            fi
        fi
    fi
    read -r pid < <(ps -e -o pid,cmd | awk -v a="$SCRIPT_PATH" '$2!="awk" && index($0,a) {print $1}')
    if [[ -n $pid && $$ -ne $pid ]];  then
        exit 0
    fi
    echo $$ | tee "${lock}" > /dev/null 2>&1
}
log() {
    local mkdir_resp log_msg

    if [[ ! -d "$(dirname -- "${LOG_PATH}")" ]]; then
        mkdir_resp=$(mkdir "$(dirname -- "${LOG_PATH}")" 2>&1)
        if [[ $? -ne 0 ]]; then
            echo "${mkdir_resp}" | tee -a "$(dirname -- "$0")/$(basename "$0" .sh)-error.log"
        fi
        if [[ ! -d "$(dirname -- "${LOG_PATH}")" ]]; then
            echo "Unable to create directory path '$(dirname -- "${LOG_PATH}")'" | tee -a "$(dirname -- "$SCRIPT_PATH")/$(basename "$SCRIPT_PATH" .sh)-error.log"
            echo "Switching to path '$(dirname -- "$0")' for logs" | tee -a "$(dirname -- "$SCRIPT_PATH")/$(basename "$SCRIPT_PATH" .sh)-error.log"
            LOG_PATH="$(dirname -- "$SCRIPT_PATH")/$(basename "$SCRIPT_PATH" .sh).log"
        fi
    fi
    if [[ ! -f "${LOG_PATH}" ]]; then
        :  | tee "${LOG_PATH}" > /dev/null 2>&1
        chmod 777 "${LOG_PATH}" > /dev/null 2>&1
    fi
    if [[ "$1" == "debug" ]]; then
        log_type="DEBUG "
    elif [[ "$1" == "error" ]]; then
        log_type="ERROR "
    elif [[ "$1" == "warning" ]]; then
        log_type="WARN  "
    elif [[ "$1" == "event" ]]; then
        log_type="EVENT "
    else
        log_type="NOTICE"
    fi
    log_msg=""
    while read -r INPUTLINE; do
        log_msg="$(date "+%Y/%m/%d %T") $log_type: $INPUTLINE"
        if [[ -n "${LOG_PATH}" ]]; then
            if [[ -n "${log_msg}" ]]; then
                echo "${log_msg}" | tee -a "${LOG_PATH}" > /dev/null 2>&1
            fi
        else
            echo "no-file ${log_msg}"
        fi
    done
}
log_rotate() {
    local max_size get_size get_name path_noext file_ext remove_oldest

    max_size=1000000 # 1MB in Bytes
    get_size=$(stat -c%s "${LOG_PATH}" 2>/dev/null)

    if [[ $get_size -ge $max_size ]]; then
        get_name="$(basename -- "${LOG_PATH}")"
        path_noext="$(dirname -- "${LOG_PATH}")/${get_name%.*}"
        file_ext="${get_name##*.}"
        remove_oldest=true
        for i in {3..1};do
            if [[ -f "$path_noext-$i.$file_ext" ]];then
                if [[ "$remove_oldest" == true ]];then
                    rm -f "$path_noext-$i.$file_ext"
                else
                    cp "$path_noext-$i.$file_ext" "$path_noext-$((i+1)).$file_ext"
                    chmod 777 "$path_noext-$((i+1)).$file_ext" > /dev/null 2>&1
                fi
            fi
            remove_oldest=false
        done
        cp "${LOG_PATH}" "$path_noext-1.$file_ext"
        
        : > "${LOG_PATH}"
    fi
}
on_exit() {
    echo "Script Exiting; code ${1}." | log
    exit "${1}"
}
is_mounted() {
    findmnt --target "${RCLONE_SETTINGS[2]}" --type "fuse.rclone" >/dev/null;
}
find_rclone() {
    local pid
    read -r pid < <(ps -e -o pid,cmd | awk -v a="rclone ${RCLONE_SETTINGS[*]}" '$2!="awk" && index($0,a) {print $1}')
    if [[ -n $pid ]]; then
        if [[ "${1}" == "pid" ]];then 
            echo "${pid}";
        fi
        return 0
    fi
    return 1
}
clean_exit() {
    local rclone_quit mount_path pid

    rclone_quit=("rc" "core/quit" "${RCLONE_REMOTE[@]}" "--log-file" "${LOG_PATH}")
    rclone "${rclone_quit[@]}" > /dev/null 2>&1

    mount_path="${RCLONE_SETTINGS[2]}"

    pid=$(find_rclone pid)
    if [[ -n $pid ]]; then
        kill "${pid}" > /dev/null 2>&1
        sleep 2
        if find_rclone; then
            eNotify "Rclone mount '${mount_path}' is still running but script has been terminated."
            on_exit 1
        fi
    fi

    eNotify "Rclone Mount '${mount_path}', was terminated."
    on_exit 0
}
eNotify() {
    echo "${1}" | log warn
    if [[ -n "${DISCORD_URL}" ]]; then
        curl -H "Content-Type: application/json" -X POST -d "{\"content\": \"${1}\"}" "${DISCORD_URL}"
    fi
}
#
# MAIN CODE

# lock script
flock "$(dirname -- "$SCRIPT_PATH")/lock_$(basename "$SCRIPT_PATH" .sh)"

# create log and set permissions
: | log

# if mounted then we exit to avoid issues
if is_mounted; then
    if find_rclone; then
        eNotify "$(basename "$0" .sh) an attempt was made but mount already exists '${RCLONE_SETTINGS[2]}'."
    else
        eNotify "$(basename "$0" .sh) is not runnig but mount exists '${RCLONE_SETTINGS[2]}'."
    fi
    on_exit 1
fi

# redirect trap signals to cleaner
trap 'clean_exit' SIGTERM SIGINT

rclone "${RCLONE_SETTINGS[@]}" &

sleep 2

if [[ $? -ne 0 ]]; then
    clean_exit
fi

#
# MONITOR RCLONE MOUNT
#
PID_CHECK=0
IS_ACTIVE=false
NOT_RUNNING=false
while :; do
    sleep 2
    if ! find_rclone ; then
        NOT_RUNNING=true
    fi
    if ! is_mounted; then
        NOT_RUNNING=true
    fi
    if $NOT_RUNNING; then
        if ! $IS_ACTIVE; then
            if [[ $PID_CHECK -ge 50 ]]; then
                eNotify "$(basename "$0" .sh) Failed to find rclone mount '${RCLONE_SETTINGS[2]}'."
                clean_exit
            fi
            if [[ $PID_CHECK -ne 0 ]]; then
                echo "$(basename "$0" .sh) retry ${PID_CHECK}/50" | log
            fi
        else
            eNotify "$(basename "$0" .sh) has stopped."
        fi
        (( PID_CHECK++ ))
	else
		PID_CHECK=0
		IS_ACTIVE=true
		log_rotate
    fi
    NOT_RUNNING=false
done
