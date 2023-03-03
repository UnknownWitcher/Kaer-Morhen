#!/bin/bash
# CONFIG - Alpha-v1.2 - service accounts now switched based on original design
#
# path settings
PATH_SOURCE="/<your upload path>"
PATH_TARGET="/<your drive path>"
PATH_CONFIG="/<your config path>/rclone.conf"
# Filters
MIN_FILES_TO_UPLOAD=1
MIN_FILE_AGE_MINUTES=1
IGNORE_FOLDERS=("unpack")

# service settings
SERVICE_ACC="/<path to service account folder>"
SERVICE_SWICHER="google" # dropbox | google

# log settings
LOG_PATH="/media/logs"
LOG_TYPE="-vv"    # blank for notice|-v for info|-vv to debug|-q for errors only
LOG_SIZE=1000     # KB (1MB)
LOG_LIMIT=1       # How many log files should be kept.

# rclone settings
RCLONE_TEST=true

RCLONE_SETTINGS=(
    "--delete-empty-src-dirs"
    "--fast-list"
    "--max-transfer" "750G"
    "--drive-chunk-size" "128M"
    "--tpslimit" "12"
    "--tpslimit-burst" "12"
    "--transfers" "12"
)
RCLONE_REMOTE=( # required for this whole thing to work
    "--rc-addr=localhost:5577"
    "--rc-user=admin"
    # Randomly created password
    "--rc-pass=$(echo $RANDOM | base64 | awk '{print substr($0,1,7);exit}')"
)
#
# FUNCTIONS
#
flock() { #160223-1
    local lock_name lock_path lock_pid check_pid script_arg script_source script_pid
    lock_name="${1}"; script_pid="$$"; script_source="${BASH_SOURCE[0]}"
    script_arg=("${BASH}" "${script_source}")
    lock_path="$(dirname -- "$(realpath "${script_source}}")")/${lock_name}_flock"
    for ((i=0;i<${#BASH_ARGV[@]}; i++)); do 
        script_arg+=("${BASH_ARGV[~i]}")
    done
    if [[ -f "${lock_path}" ]]; then
        read -r lock_pid < "${lock_path}" > /dev/null 2>&1
        if [[ -n "${lock_pid[0]}" ]]; then
            check_pid=$(ps -eo pid,cmd \
                | awk -v a="${lock_pid}" -v b="${script_arg[*]}" '$1==a && $2!="awk" && index($0,b) {print $1}')
            if [[ -n "${check_pid}" ]]; then
                printf "%s\n" "Command with existing arguments alrady exists PID [${check_pid}]." | log debug
                exit 0
            fi
        fi
    fi
    read -r check_pid < <(ps -eo pid,cmd | awk -v a="${script_arg[*]}" '$2!="awk" && index($0,a) {print $1}')
    if [[ "${script_pid}" -ne "${check_pid[0]}" ]]; then
        printf "%s\n" "Race condition prevented." | log debug
        exit 0
    fi
    printf '%s' "${script_pid}" | tee "${lock_path}" > /dev/null 2>&1
}
log() { # 240223-1
    local type_id message script_source err_msg
    type_id="${1}"; script_source="${BASH_SOURCE[0]}"
    if [[ "${LOG_TYPE}" == "-q" && "${type_id}" != "error" && "${type_id}" != "onetimerun" ]]; then return 0; fi
    case "${type_id}" in
        debug)
            if [[ "$LOG_TYPE" != "-vv" ]]; then return 0; fi
            type_id="DEBUG "
            ;;
        error)
            type_id="ERROR "
            ;;
        warn)
            type_id="WARN  "
            ;;
        event)
            type_id="EVENT "
            ;;
        info)
            if [[ "${LOG_TYPE}" != "-v" && "${LOG_TYPE}" != "-vv" ]]; then return 0; fi
            type_id="INFO  "
            ;;
        onetimerun)
            if [[ -n "$LOG_PATH" ]]; then
                if [[ "$LOG_PATH" == "${LOG_PATH#*.}" ]]; then
                    if [[ "$LOG_PATH" == "/" ]]; then
                        LOG_PATH="./"
                    fi
                    LOG_PATH="${LOG_PATH%/}/$(basename "${script_source}" .sh).log"
                fi
                if [[ ! -d "$(dirname -- "$LOG_PATH")" ]]; then
                    if ! mkdir "$(dirname -- "$LOG_PATH")" > /dev/null 2>&1; then
                        err_msg="Failed to create log path '$(dirname -- "$LOG_PATH")'"
                    fi
                    if [[ ! -d "$(dirname -- "$LOG_PATH")" ]]; then
                        LOG_PATH="$(dirname -- "${script_source}")/$(basename "${script_source}" .sh).log"
                        printf "%s\n" "${err_msg}" | tee -a "${LOG_PATH}"
                    fi
                fi
            else
                LOG_PATH="$(dirname -- "${script_source}")/$(basename "${script_source}" .sh).log"
            fi
            return 0
            ;;
        *)
            type_id="NOTICE"
            ;;
    esac
    message=""
    while read -r inputline; do
        if [[ -z "${inputline}" ]]; then
            continue
        fi
        if [[ ! -f "${LOG_PATH}" ]]; then
            :  | tee "${LOG_PATH}" > /dev/null 2>&1
            chmod 777 "${LOG_PATH}" > /dev/null 2>&1
        fi
        message="$(date "+%Y/%m/%d %T") ${type_id}: ${inputline}"
        if [[ -n "${LOG_PATH}" ]]; then
            printf "%s\n" "${message}" | tee -a "${LOG_PATH}" > /dev/null 2>&1
        else
            printf "%s\n" "no-log: ${message}"
        fi
    done
}
log_rotate() { #240223-1
    local max_size get_name path_noext file_ext remove_oldest file_path
    file_path="${LOG_PATH}"
    if [[ -z "${LOG_LIMIT}" ]]; then LOG_LIMIT=1; fi
    if [[ ${LOG_LIMIT} -le 0 ]]; then return 0; fi
    if [[ ! -f "${file_path}" ]]; then
        printf "%s\n" "log_rotate: Unable to find '${file_path}'" | log warn
        return 1
    fi
    max_size=1000000 #1MB
    if [[ ${LOG_SIZE} -ge 10000 ]] && [[ ${LOG_SIZE} -le 5000000 ]]; then
        max_size=${LOG_SIZE}
    fi
    if [[ $(stat -c%s "${file_path}" 2>/dev/null) -ge ${max_size} ]]; then
        if [[ $LOG_LIMIT -le 1 ]]; then
            : > "${file_path}"
            return 0
        fi
        get_name="$(basename -- "${file_path}")"
        path_noext="$(dirname -- "${file_path}")/${get_name%.*}"
        file_ext="${get_name##*.}"
        remove_oldest=true
        for ((i=$((LOG_LIMIT-1)); i>=1; i--)) do
            if [[ -f "${path_noext}-${i}.${file_ext}" ]];then
                if [[ "${remove_oldest}" == true ]];then
                    printf "%s\n" "Removing old file > '${path_noext}-${i}.${file_ext}'" | log debug
                    rm -f "${path_noext}-${i}.${file_ext}"
                else
                    printf "%s\n" "Copying '${path_noext}-${i}.${file_ext}' to '${path_noext}-$((i+1)).${file_ext}'" | log debug
                    cp "${path_noext}-${i}.${file_ext}" "${path_noext}-$((i+1)).${file_ext}"
                    printf "%s\n" "Fixing permissions > '${path_noext}-$((i+1)).${file_ext}'" | log debug
                    chmod 777 "${path_noext}-$((i+1)).${file_ext}" > /dev/null 2>&1
                fi
            fi
            remove_oldest=false
        done
        cp "${file_path}" "${path_noext}-1.${file_ext}"
        printf "%s\n" "Copying '${file_path}' to '${path_noext}-1.${file_ext}'" | log debug
        : > "${file_path}"
        printf "%s\n" "Truncating > '${file_path}'" | log debug
    fi
    return 0
}
fileList() { #240223-1
    local dir_path op value file_age count find_arg invalid_date
    dir_path="${1}"
    if [[ ! -d "${dir_path}" ]]; then
        printf "%s\n" "fileList> Directory '${dir_path}' does not exist." | log error
        safely_exit 1
    fi
    shift; op="${1}"; shift; value="${1}"
    if ! [[ "$value" =~ ^\-?[0-9]+$ ]]; then
        printf "%s\n" "fileList> Value not integer '${value}'." | log error
        safely_exit 1
    fi
    file_age=$MIN_FILE_AGE_MINUTES
    if ! [[ "$file_age" =~ ^\-?[0-9]+$ ]]; then
        printf "%s\n" "fileList> MIN_FILE_AGE_MINUTES is not integer '${file_age}'." | log error
        safely_exit 1
    fi
    find_arg=("${dir_path}" "-type" "f")
    invalid_date=("${dir_path}" "-mtime" "-0")
    for ((i=0;i<${#IGNORE_FOLDERS[@]}; i++)); do 
        find_arg+=("-not" "-ipath" "*/${IGNORE_FOLDERS[$i]}/*")
        invalid_date+=("-not" "-ipath" "*/${IGNORE_FOLDERS[$i]}/*")
    done
    invalid_date+=('-exec' 'touch' '-d' '-1min' '{}' '+')
    find_invalid="$(find ${invalid_date[@]} 2>&1)"
    if [[ -n "${find_invalid}" ]]; then
        printf "%s\n" "${find_invalid}" | log warn
        return 1
    fi
    if [[ $file_age -gt 0 ]]; then
        find_arg+=("-mmin" "+${file_age}")
    elif [[ $file_age -lt 0 ]]; then
        find_arg+=("-mmin" "${file_age}")
    fi
    find_arg+=("-exec" "printf" "%c" "{}" "+")
    if [[ "${op}" == "eq" || "${op}" == "ne" || "${op}" == "lt" || \
        "${op}" == "le" ||"${op}" == "gt" || "${op}" == "ge" ]]; then
        count=$(find "${find_arg[@]}" | wc -c)
    fi
    case "${op}" in
        eq)
            if [[ $count -eq $value ]]; then return 0; fi
            ;;
        ne)
            if [[ $count -ne $value ]]; then return 0; fi
            ;;
        lt)
            if [[ $count -lt $value ]]; then return 0; fi
            ;;
        le)
            if [[ $count -le $value ]]; then return 0; fi
            ;;
        gt)
            if [[ $count -gt $value ]]; then return 0; fi
            ;;
        ge)
            if [[ $count -ge $value ]]; then return 0; fi
            ;;
        *)
            printf "%s\n" \
                "fileList> Invalid operator '${op}'. eq, ne, lt, le, gt, ge" | log error
            safely_exit 1
            ;;
    esac
    return 1
}
service_account_cache() { #190223-1
    local cache_file flag_index index state script_source
    script_source="${BASH_SOURCE[0]}"
    cache_file="$(dirname -- "${script_source}")/$(basename "${script_source}" .sh).sacc"
    flag_index=$1; state="${2}"
    if ! [[ ${flag_index} =~ ^[0-9]+$ ]]; then
        printf "%s\n" "service_account_cache> Invalid argument '${flag_index}'. Must be integer." | log error
        return 1
    fi
    index=$flag_index
    if [[ "${state}" != "save" ]]; then
        if [[ -f "${cache_file}" ]]; then
            read -r index < "${cache_file}"
            if [[ -z "${index}" || $flag_index -gt $index ]]; then
                index=$flag_index
            fi
        fi
    fi
    printf "%s\n" "${index}" | tee "${cache_file}"
    return 0
}
CNT_TRANSFER_LAST=0
CNT_403_RETRY=0
service_account_switch() { # 190223-2
    local message cnt_transfer last_error rclone_arg results
    printf "%s\n" "Running 'service account switcher'" | log debug
    if [[ "${SERVICE_SWICHER}" != "google" ]]; then
        printf "%s\n" "'Service account switcher' requires google services" | log debug
        return 1
    fi
    results="$(rclone_api stats)"
    if [[ $? -eq 1 ]]; then return 1; fi
    if [[ -z "${MONITOR_MAX_TRANSFER}" ]]; then MONITOR_MAX_TRANSFER=750; fi
    cnt_transfer="$(printf "%s\n" "${results}" | jq '.bytes')"
    if [[ -z "${cnt_transfer}" ]]; then cnt_transfer=0; fi
    last_error="$(printf "%s\n" "${results}" | jq '.lastError')"
    if [[ -z "${last_error}" ]]; then last_error=""
    else last_error="$(printf "%s\n" "${last_error}" | grep "userRateLimitExceeded")"; fi
    if [[ ${cnt_transfer} -gt $((${MONITOR_MAX_TRANSFER%G}*1000**3)) ]]; then
        message="Reached max-transfer limit"
    elif [[ -n "${last_error}" ]]; then
        message="user_rate_limit error"
    elif [[ $((cnt_transfer-CNT_TRANSFER_LAST)) -eq 0 ]]; then
        ((CNT_403_RETRY=CNT_403_RETRY+1))
        if [[ $((CNT_403_RETRY%15)) -eq 0 ]]; then
            printf "%s\n" "No transfers in ${CNT_403_RETRY} checks" | log warn
        fi
        if [[ ${CNT_403_RETRY} -ge 120 ]]; then
            message="no transfers have occured in a long time"
        else
            return 1
        fi
    else
        CNT_403_RETRY=0
        CNT_TRANSFER_LAST=${cnt_transfer}
        return 1
    fi
    if [[ $cnt_transfer -gt $((${MONITOR_MAX_TRANSFER%G}*1000**3)) ]]; then
        message="Reached max-transfer limit"
    elif [[ -n "${error_user_rate_limit}" ]]; then
        message="user_rate_limit error"
    else
        return 1
    fi
    printf "%s, %s.\n" "${message}" "switching service accounts." | log info
    return 0
}
rclone_api() { # 230223-1
    local self rclone_arg results accepted_vars
    #printf "%s\n" "Running 'rclone api ${1}'" | log debug
    self="${1}"
    accepted_vars="pid quit stats"
    if [[ "${accepted_vars}" != *"${self}"* ]]; then
        printf "%s\n" "Invalid rclone api command" | log error
        rclone_arg=("rc" "core/quit" "${RCLONE_REMOTE[@]}")
        rclone_try_catch "$(rclone "${rclone_arg[@]}" 2>&1)"
        return 1
    fi
    rclone_arg=("rc" "core/${self}" "${RCLONE_REMOTE[@]}")
    if [[ "${self}" == "pid" ]]; then
        printf "%s\n" "$(rclone "${rclone_arg[@]}" 2>/dev/null)"
        return 0
    fi
    results="$(rclone "${rclone_arg[@]}" 2>&1)"
    if rclone_try_catch "${results}"; then return 1; fi
    if [[ "${self}" == "quit" ]]; then return 0; fi
    printf "%s\n" "${results}"
}
rclone_try_catch() { # 230223-1
    local response="${1}"
    case "${response}" in
        *"connection refused"*)
            printf "%s\n" "${response:20}" | log error
            return 0
            ;;
        *"401 Unauthorized"*)
            printf "%s\n" "test: ${response:20}" | log error
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}
rclone_clean_settings() { #190223-2
    local tmp_array i ignore_case
    printf "%s\n" "Running rclone settings cleaner" | log debug
    if [[ -z "${PATH_TARGET}" || -z "${PATH_SOURCE}" ]]; then
        printf "%s\n" "PATH_TARGET and PATH_SOURCE cannot be empty" | log error
        safely_exit 1
    fi
    if findmnt "${PATH_SOURCE}" -o FSTYPE -n | grep fuse; then
        printf "%s\n" "'${PATH_SOURCE}' cannot be a fuse type" | log error
        safely_exit 1
    fi
    for ((i=0;i<${#RCLONE_SETTINGS[@]}; i++)); do 
        if [[ "${RCLONE_SETTINGS[$i]}" == "--exclude" || \
                "${RCLONE_SETTINGS[$i]}" == "--config" || \
                "${RCLONE_SETTINGS[$i]}" == "--log-file" || \
                "${RCLONE_SETTINGS[$i]}" == "--low-level-retries" || \
                "${RCLONE_SETTINGS[$i]}" == "--drive-service-account-file" || \
                "${RCLONE_SETTINGS[$i]}" == "--min-age" ]]; then
            ((i=i+1))
            continue
        fi
        if [[ "${RCLONE_SETTINGS[$i]}" == "--rc" || \
            "${RCLONE_SETTINGS[$i]}" == "-q" || \
            "${RCLONE_SETTINGS[$i]}" == "-v" || \
            "${RCLONE_SETTINGS[$i]}" == "-vv" || \
            "${RCLONE_SETTINGS[$i]}" == "move" || \
            "${RCLONE_SETTINGS[$i]}" == "${PATH_TARGET}" || \
            "${RCLONE_SETTINGS[$i]}" == "${PATH_SOURCE}" || \
            "${RCLONE_SETTINGS[$i]}" == "--drive-stop-on-upload-limit" ]]; then
            continue
        fi
        if [[ "${RCLONE_SETTINGS[$i]}" == "--dry-run" ]]; then
            RCLONE_TEST=false
        fi
        if [[ "${SERVICE_SWICHER}" == "dropbox" ]]; then
            if [[ "${RCLONE_SETTINGS[$i]}" == "--drive-chunk-size" ]]; then
                tmp_array+=("--dropbox-chunk-size")
                continue
            fi
            if [[ "${RCLONE_SETTINGS[$i]}" == "--max-transfer" ]]; then
                ((i=i+1))
                continue
            fi
        fi     
        tmp_array+=("${RCLONE_SETTINGS[$i]}")
        if [[ "${RCLONE_SETTINGS[$i]}" == "--max-transfer" ]]; then
            ((i=i+1))
            tmp_array+=("${RCLONE_SETTINGS[$i]}")
            MONITOR_MAX_TRANSFER="${RCLONE_SETTINGS[$i]}"
        fi
    done
    if [[ -n ${PATH_CONFIG} ]]; then
        if [[ -f ${PATH_CONFIG} ]]; then
            tmp_array+=("--config" "${PATH_CONFIG}")
        else
            printf "%s\n" "Custom rclone config '${PATH_CONFIG}' is missing" | log error
            safely_exit 1
        fi
    fi
    ignore_case=true
    for ((i=0;i<${#IGNORE_FOLDERS[@]}; i++)); do
        if [[ ${ignore_case} == true ]]; then
            tmp_array+=("--ignore-case")
            ignore_case=false
        fi
        tmp_array+=("--exclude" "'*${IGNORE_FOLDERS[$i]}*/**'")
    done
    if [[ ${RCLONE_TEST} == true ]]; then
        tmp_array+=("--dry-run")
    fi
    if ! [[ "${MIN_FILE_AGE_MINUTES}" =~ ^\-?[0-9]+$ ]]; then
        MIN_FILE_AGE_MINUTES=0
    fi
    if [[ ${MIN_FILE_AGE_MINUTES} -gt 0 ]]; then
        tmp_array+=("--min-age" "${MIN_FILE_AGE_MINUTES}m")
    fi
    if [[ -n "${LOG_TYPE}" ]]; then
        tmp_array+=("${LOG_TYPE}")
    fi
    RCLONE_SETTINGS=(
        "move" "${PATH_SOURCE}" "${PATH_TARGET}"
        "${tmp_array[@]}"
        "--log-file" "${LOG_PATH}"
        "--rc" "${RCLONE_REMOTE[@]}"
    )
}
safely_exit() { # 230123-1
    local rclone_arg pid rquit exit_code
    exit_code=$1
    pid="$(rclone_api pid)"
    if [[ -n "${pid}" ]]; then
        rclone_api quit
    fi
    event_exit ${exit_code}
}
event_exit() { #190223-0
    printf "%s\n" "exiting.." | log info
    exit $1
}
stop_file_exists() { #190223-0
    local exit_file="$(basename "${BASH_SOURCE[0]}" .sh).exit"
    #printf "%s\n" "Running 'stop file exists'" | log debug
    if [[ -f "$(dirname -- "$(realpath "${BASH_SOURCE[0]}")")/${exit_file}" ]]; then
        printf "%s\n" "'${exit_file}' was detected." | log debug
        safely_exit 0
    fi
}
run_service() { # 030323-1
    local json_files current_account cache_account sacc rclone_arg
    case "${SERVICE_SWICHER}" in
        "google")
            readarray -t json_files <<<$(find "${SERVICE_ACC}" -name "*.json" -type f -print)
            if [[ ${#json_files[@]} -eq 0 ]]; then
                printf "%s\n" "Service accounts not found in '${SERVICE_ACC}'" | log error
                safely_exit 1
            fi
            sacc=$(service_account_cache 0) # Gets current SA
            if [[ $? -eq 1 ]]; then safely_exit 1; fi
            current_account="${json_files[$sacc]}"
            printf "%s\n" "Service Account: ${current_account}" | log debug
            rclone_arg=("${RCLONE_SETTINGS[@]}" "--drive-service-account-file" "${current_account}")
            monitor_source_folder
            run_rclone "${rclone_arg[@]}"
            ((sacc=sacc+1)) # Increment and save for next run
            if [[ ${sacc} -gt $((${#json_files[@]}-1)) ]]; then
                sacc=$(service_account_cache 0 save)
                if [[ $? -eq 1 ]]; then echo "safely exit"; fi
            else
                sacc=$(service_account_cache ${sacc} save)
                if [[ $? -eq 1 ]]; then echo "safely exit"; fi
            fi
            if [[ $? -eq 1 ]]; then
                safely_exit 1
            fi
            ;;
        "dropbox")
            monitor_source_folder
            run_rclone "${RCLONE_SETTINGS[@]}"
            if [[ $? -eq 1 ]]; then
                safely_exit 1
            fi
            ;;
        *)
            printf "%s\n" "Invalid service '${SERVICE_SWICHER}' must be 'google' or 'dropbox'" | log error
            safely_exit 1
            ;;
    esac
    return 0
}
monitor_source_folder() { # 230223-0
    local notify min_file_limit
    echo "monitoring source folder" | log debug
    notify=true
    min_file_limit=1
    if [[ ${MIN_FILES_TO_UPLOAD} -gt 0 ]]; then
        min_file_limit=${MIN_FILES_TO_UPLOAD}
    fi
    while :; do
        stop_file_exists
        if fileList "${PATH_SOURCE}" ge ${min_file_limit}; then
            break
        fi
        if ${notify}; then
            printf "%s\n" "Uploading will not start until ${min_file_limit} file(s) are available." | log info
            notify=false
        fi
        sleep 1
    done
    return 0
}
SWITCH_SERVICE_STATE=0
run_rclone() { # 240223-2
    local pid is_active retries
    printf "%s\n" "Starting rclone with the following configuration." | log debug
    printf "%s\n" "$*" | log debug
    rclone "$@" &
    retries=0
    is_active=false
    while :; do
        stop_file_exists
        pid="$(rclone_api pid)"
        if [[ -z "${pid}" ]]; then
            if [[ ${is_active} == false ]]; then
                if [[ ${retries} -gt 0 ]]; then
                    printf "%s\n" "Rclone not running.. attempt ${retries}/15" | log debug
                fi
                if [[ ${retries} -ge 15 ]]; then
                    printf "%s\n" "Rclone failed to start.." | log debug
                    return 1
                fi
                ((retries=retries+1))
                sleep 1
                continue
            else
                break
            fi
        fi
        log_rotate
        is_active=true
        retries=0
        if [[ ${SWITCH_SERVICE_STATE} -ge 2 ]]; then
            printf "%s\n" "Service accounts switched too fast." | log error
            return 1
        fi
        if service_account_switch; then
            printf "%s\n" "Enabled Switching Service Accounts" | log debug
            SWITCH_SERVICE_ACCOUNT=true
            if [[ ${SWITCH_SERVICE_STATE} -eq 0 ]]; then
                ((SWITCH_SERVICE_STATE=SWITCH_SERVICE_STATE+1))
            fi
            break
        fi
        SWITCH_SERVICE_STATE=0
        sleep 30
    done
    return 0
}
# MAIN
flock "rclone_upload"
trap 'safely_exit 0' SIGTERM SIGINT
((LOG_SIZE=LOG_SIZE*1000))
SWITCH_SERVICE_ACCOUNT=false
log onetimerun
rclone_clean_settings
while :; do
    stop_file_exists
    run_service
done
