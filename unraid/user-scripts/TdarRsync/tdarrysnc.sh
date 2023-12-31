#!/bin/bash
# shellcheck disable=SC2089
CONFIG='{
	"source": "/mnt/disks/db_shows/series",
	"target": "/mnt/user/downloads/dropbox/series",
	"database": "/mnt/user/downloads",
	"subfolder": "/NCIS (2003) [tvdb-72108]/Season 03",
	"file limit": 10
}'

main() {
	local source target subfolder datapath fileLimit queue  directory \
			file destination response queueMsg

	source="$(config "source")"
	target="$(config "target")"
	subfolder=$(config "subfolder")
	datapath="$(config "database")/tdarrsyncDB"
	fileLimit=$(config "file limit")
	queue=()

	directory="${source}"
	if [[ -n "${subfolder}" ]] && ! [[ "${subfolder}" == "/" ]]; then
		if [[ "${subfolder::1}" == "/" ]]; then
			directory="${directory}${subfolder}"
		else
			directory="${directory}/${subfolder}"
		fi
	fi

	if [[ ${fileLimit} -le 0 ]]; then fileLimit=10; fi
	if [[ ${fileLimit} -gt 1 ]]; then ((fileLimit--)); fi

	while IFS= read -r -d '' file; do

		database="${file%.*}.tsdb"; database="${database/${source}/${datapath}}"
		fileDestination="${file/${source}/${target}}"

		if [[ -f "${fileDestination}" ]]; then
			echo "'$(basename -- "${file}")' in target path, adding to queue"
			queue+=("${fileDestination}")
			if ! [[ -f "${database}" ]]; then
				touch "${database}"
				sleep 1
			fi
		fi

		if [[ -f "${database}" ]]; then
			continue
		fi

		destination="$(dirname -- "${fileDestination}")"

		mkdirmod "${target}" "${destination}"
		sleep 1

		echo "Copying ${file} ==> ${destination}"
		sleep 10
		TDSDB_CURRENT_PROCESS=("${database}" "${fileDestination}")
		rsync -a "${file}" "${destination}"
		response=$?

		if [[ ${response} -ne 0 ]]; then
			echo "rsync failed, exiting.."
			exit ${response}
		fi
		setDatabase "${database}"
		echo "--- Adding to queue"
		queue+=("${fileDestination}")

		if [[ ${#queue[@]} -ge ${fileLimit} ]]; then
			queueMsg=false
			while :; do
				for i in "${!queue[@]}"; do
					if ! [[ -f "${queue[i]}" ]]; then
						echo "processed: $(basename -- "${queue[i]}")"
						unset queue[i]
					fi
				done
				if [[ ${#queue[@]} -le ${fileLimit} ]]; then break; fi
				if [[ "${queueMsg}" == "false" ]]; then
					echo "Waiting for tdarr to process some files.";
					queueMsg=true
				fi
				sleep 60
			done

		fi

	done < <(find "${directory}" -type f -print0)
}
config() {
	echo "${CONFIG}" | jq -r ."${1}"
}
cleanTargetPath() {
	local target; target="$(config 'target')"
	if [[ -d "${target}" ]]; then
		# Delete empty folders except source folder
		find "${target}" -mindepth 1 -type d -empty -delete
	fi
	if [[ ${#TDSDB_CURRENT_PROCESS[@]} -eq 0 ]]; then return 0; fi
	if [[ -f "${TDSDB_CURRENT_PROCESS[0]}" ]]; then return 0; fi
	if [[ -f "${TDSDB_CURRENT_PROCESS[1]}" ]]; then
		setDatabase "${TDSDB_CURRENT_PROCESS[0]}"
	fi
}
setDatabase() {
	mkdir -p "$(dirname -- "${1}")"
	touch "${1}"
	echo "--- Adding to database."
}
mkdirmod() {
	local target destination fixTargetPermissions modPath

	target="${1}"; destination="${2}"
	fixTargetPermissions=false

	if [[ -d "${destination}" ]]; then return 0; fi
	if ! [[ -d "${target}" ]]; then fixTargetPermissions=true; fi
	
	mkdir -p "${destination}"

	if [[ "${fixTargetPermissions}" == "true" ]]; then
		modPath="${target}"
	else
		modPath="${target}/$(echo "${destination#"${target}"}" | cut -d "/" -f2)"
	fi

	find "${modPath}" -type d -exec chmod 777 {} +
}
trap cleanTargetPath EXIT
TDSDB_CURRENT_PROCESS=()
main
