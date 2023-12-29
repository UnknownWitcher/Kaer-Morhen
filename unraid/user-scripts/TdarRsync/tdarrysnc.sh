#!/bin/bash
# shellcheck disable=SC2089
CONFIG='{
	"source": "/mnt/disks/db_shows/series",
	"target": "/mnt/user/downloads/dropbox/series",
	"database": "/mnt/user/downloads",
	"subfolder": "/NCIS (2003) [tvdb-72108]/Season 03"
}'

main() {
	local source target datapath queue subfolder directory \
			file filepath destination response

	source="$(config "source")"
	target="$(config "target")"
	subfolder=$(config "subfolder")
	datapath="$(config "database")/tdarrsyncDB"
	queue=()

	directory="${source}"
	if [[ -n "${subfolder}" ]] && ! [[ "${subfolder}" == "/" ]]; then
		if [[ "${subfolder::1}" == "/" ]]; then
			directory="${directory}${subfolder}"
		else
			directory="${directory}/${subfolder}"
		fi
	fi
	
	find "${directory}" -type f -print0 | while IFS= read -r -d '' file; do

		filepath="$(dirname -- "${file}")"
		database="${filepath/${source}/${datapath}}/$(basename -- "${file%.*}.tsdb")"

		if [[ -f "${database}" ]]; then
			continue
		fi

		destination="${filepath/${source}/${target}}"
		
		echo "Copying ${file} ==> ${destination}"

		mkdir -p "${destination}"
		sleep 1

		rsync -a "${file}" "${destination}"
		response=$?

		if [[ ${response} -ne 0 ]]; then
			echo "rsync failed, exiting.."
			exit ${response}
		fi

		mkdir -p "$(dirname -- "${database}")"
		touch "${database}"
		queue+=("${file/${source}/${target}}")

		if [[ ${#queue[@]} -ge 10 ]]; then
			echo "Waiting for files to process in tdarr."
			while :; do
				for i in "${!queue[@]}"; do
					if ! [[ -f "${queue[i]}" ]]; then
						echo "processed: $(basename -- "${queue[i]}")"
						unset 'queue[i]'
					fi
				done
				if [[ ${#queue[@]} -le 5 ]]; then break; fi
				sleep 60
			done
		fi
	done
}

cleanTargetPath() {
	local target="$(config 'target')"
	if [[ -d "${target}" ]]; then
		# Delete empty folders except source folder
		find "${target}" -mindepth 1 -type d -empty -delete
	fi
}

config() {
	echo "${CONFIG}" | jq -r ."${1}"
}

trap cleanTargetPath EXIT
main
