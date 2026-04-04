#!/bin/bash
# shellcheck disable=SC2089
CONFIG="{
	\"source\": \"/mnt/disks/db_shows/series\",
	\"target\": \"/mnt/user/downloads/dropbox/series/shows\",
	\"database\": \"/mnt/user/downloads\",
	\"subfolder\": [
		\"/Arrow (2012) [tvdb-257655]\",
		\"/The Flash (2014) [tvdb-279121]\",
		\"/Constantine (2014) [tvdb-273690]\",
		\"/DC's Legends of Tomorrow (2016) [tvdb-295760]\"
	],
	\"file_type\": \"video\",
	\"file_limit\": 10
}"
function invoke-script {
	local limiter value temp
	limiter=$(get-config "file_limit")

	if [[ ${limiter} -le 0 ]]; then limiter=10; fi

	while read -r value; do
		temp=""
		if [[ -n "${value}" ]] && ! [[ "${value}" == "/" ]]; then
			temp="${value}"
			if ! [[ "${value::1}" == "/" ]]; then
				temp="/${value}"
			fi
		fi
		invoke-process "${temp}" "${limiter}"
		if [[ ${ENABLE_CLEANER} -eq 1 ]]; then
			invoke-cleaner
		fi
	done < <(get-config 'subfolder')
}
function invoke-process {
	local source target datapath filelimit directory file fileType getFileType database \
			targetFile queueState targetFileDirname response
	
	source="$(get-config 'source')"
	target="$(get-config 'target')"
	datapath="$(get-config 'database')/tdarrsyncDB"
	filelimit="${2}"
	fileType="$(get-config 'file_type')"

	directory="${source}"
	if [[ -n "${1}" ]]; then
		directory="${directory}${1}"
	fi
	if ! [[ -d "${directory}" ]]; then
		echo "Directory does not exist: '${directory}'"
		return
	fi
	while IFS= read -r -d '' file; do
		database="${file}.tsdb"; database="${database/${source}/${datapath}}"
		targetFile="${file/${source}/${target}}"

		if ! [[ -f "${database}" ]]; then
			getFileType="$(get-fileType "${file}")"
			if ! [[ "${getFileType}" == "${fileType}" ]]; then
				set-database "${datapath}" "${database}" > /dev/null 2>&1
				continue
			fi
		fi

		if [[ -f "${targetFile}" ]]; then
			echo "'$(basename -- "${file}")' in target path."
			set-queue "${targetFile}"
			if ! [[ -f "${database}" ]]; then
				set-database "${datapath}" "${database}"
				sleep 1
			fi
		fi

		if [[ ${#GLOBAL_QUEUE[@]} -ge ${filelimit} ]]; then
			queueState=false
			while :; do
				for i in "${!GLOBAL_QUEUE[@]}"; do
					if ! [[ -f "${GLOBAL_QUEUE[i]}" ]] && [[ -n "${GLOBAL_QUEUE[i]}" ]]; then
						echo "processed: $(basename -- "${GLOBAL_QUEUE[i]}")"
						unset "GLOBAL_QUEUE[i]"
					fi
				done
				if [[ ${#GLOBAL_QUEUE[@]} -lt ${filelimit} ]]; then break; fi
				if [[ "${queueState}" == "false" ]]; then
					echo "Waiting for tdarr to process some files."
					queueState=true
				fi
				sleep 60
			done
		fi

		if [[ -f "${database}" ]]; then
			continue
		fi

		targetFileDirname="$(dirname -- "${targetFile}")"

		create-dir "${target}" "${targetFileDirname}"
		sleep 1

		CURRENT_PROCESS=("${database}" "${targetFile}")

		echo "Copying $(basename -- "${file}") ==> ${targetFileDirname}"
		rsync -a "${file}" "${targetFileDirname}"
		response=$?

		if [[ ${response} -ne 0 ]]; then
			echo "rsync failed, exiting.."
			exit ${response}
		fi
		
		ENABLE_CLEANER=1
		set-database "${datapath}" "${database}"
		set-queue "${targetFile}"

	done < <(find "${directory}" -type f -print0)
}
function get-config {
	function test-array {
		return "$(echo "${CONFIG}" | jq ."${1}" | \
			jq 'if type=="array" then 0 else 1 end')"
	}
	if test-array "${1}"; then
		echo "${CONFIG}" | jq -r ."${1}[]"
		return
	fi
	echo "${CONFIG}" | jq -r ."${1}"
}
function get-fileType {
	local checkFile getType
	checkFile="$1" getType="$(file -ib "${checkFile}")"
	echo "${getType%/*}"
}
function set-queue {
	GLOBAL_QUEUE+=("${1}")
	echo "--- Adding to queue"
}
function set-database {
	local rootPath file; rootPath="${1}"; file="${2}"

	create-dir "${rootPath}" "$(dirname -- "${file}")"

	touch "${file}"; chmod 666 "${file}"
	echo "--- Adding to database."
	CURRENT_PROCESS=()
}
function create-dir {
	local rootPath filePath fixPermissions

	rootPath="${1}"; filePath="${2}"; fixPermissions=false

	if [[ -d "${filePath}" ]]; then return 0; fi
	if ! [[ -d "${rootPath}" ]]; then fixPermissions=true; fi

	mkdir -p "${filePath}"

	if [[ "${fixPermissions}" != "true" ]]; then
		rootPath="${rootPath}/$(echo "${filePath#"${rootPath}"}" | cut -d "/" -f2)"
	fi

	find "${rootPath}" -type d -exec chmod 777 {} +
}
function invoke-cleaner {
	local target datapath files
	target="$(get-config 'target')"
	echo "Running Cleaner"
	if [[ -d "${target}" ]]; then
		echo "Cleaning - '${target}'"
		while :; do
			readarray -d '' files < <(find "${target}" -mindepth 1 -type d -empty -print0)
			if [[ "${#files[@]}" -gt 0 ]]; then
				find "${target}" -mindepth 1 -type d -empty -delete
				continue
			fi
			break
		done
	fi
	
	if [[ ${#CURRENT_PROCESS[@]} -eq 0 ]]; then return 0; fi
	if [[ -f "${CURRENT_PROCESS[0]}" ]]; then return 0; fi
	if [[ -f "${CURRENT_PROCESS[1]}" ]]; then
		datapath="$(get-config 'database')/tdarrsyncDB"
		set-database "${datapath}" "${CURRENT_PROCESS[0]}"
	fi
}
## RUN
CURRENT_PROCESS=()
GLOBAL_QUEUE=()
ENABLE_CLEANER=0

invoke-script
