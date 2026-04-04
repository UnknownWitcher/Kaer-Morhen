#!/bin/bash
# radarr settings > general > security > api key
RADARR_API_KEY="< your api key >"
# http://address:port | http://address.domain
RADARR_URL="https://address:port"

# The Event Trigger
if [[ "${radarr_eventtype}" == "Download" ]]; then
    # Sends request to unmonitor movie
    curl_resp=$(curl -s -w "\n%{http_code}" \
        -X 'PUT' "${RADARR_URL}/api/v3/movie/editor" \
        -H 'accept: */*' \
        -H 'Content-Type: application/json' \
        -H "X-Api-Key: ${RADARR_API_KEY}" \
        -d "{\"movieIds\":[${radarr_movie_id}],\"monitored\": false,}")
    
    # Verification
    resp_code="${curl_resp##*$'\n'}"
    resp_data="${curl_resp%$'\n'*}"
    
    case "${resp_code}" in
        2[0-9][0-9]) exit 0;; # success
        *) printf "%s" "${resp_data}";; # failed response
    esac
fi
