#!/bin/bash
#
# CONFIGURATION
#
# radarr settings > general > security > api key
RADARR_API_KEY="< your api key >"
# http://address:port | http://address.domain
RADARR_URL="https://address:port"
# Custom radarr tag, it will be created if it does not exist.
RADARR_TAG="unreleased"
# This is a range between now and [n] day/month/year(s) from now.
MAX_AVAILABILITY="2 month" # '-[n] day|month|year'
LOG_PATH="" # leave empty to disable logging.
#
# FUNCTIONS - DO NOT EDIT BELOW
#
# radarr api
api_caller() {
    local METHOD ENDPOINT ID DATA URI EXIT_STATUS
    while [[ $# -gt 0 ]]; do case "$1" in
        -M|--method) shift
            case "$1" in 'GET'|'POST'|'PUT') METHOD="$1";; *)
            echo "api_caller: '$1' is not valid Method; 'GET|POST|PUT'" | simpleLog;exit 1;;esac;shift;;
        -E|--endpoint) shift
            case "$1" in 'tag'|'rootfolder'|'movie'|'movie/editor'|'system/status') 
                ENDPOINT="$1"; ENDPOINT="${ENDPOINT#\/}"; ENDPOINT="${ENDPOINT%\/}";;
                *) echo "api_caller: '$1' is not valid Method; 'tag|rootfolder|movie|movie/editor|" \
                    "system/status'" | simpleLog;exit 1;;esac
            shift;;
        -i|--id) shift
            case "$1" in ''|*[!0-9]*) echo "api_caller: id must be integer" | simpleLog;exit 1;; *) ID="$1";;esac
            shift;;
        -D|--data) shift; DATA="$1"; shift;; *) echo "api_caller: invalid argument '$1'" | simpleLog; exit 1 ;;
    esac; done
    # Build URI
    URI="$RADARR_URL/api/v3/$ENDPOINT"
    if [[ -n "$ID" ]];then URI="$URI/$ID";fi
    case "$METHOD" in
        POST|PUT)
            if ! test_variable "$DATA";then echo "JSON data required for $METHOD" | simpleLog;exit 1;fi
            CURL_RESP=$(curl -sf -H "accept: */*" \
                    -H "Content-Type: application/json" \
                    -H "X-Api-Key: $RADARR_API_KEY" \
                    -X "$METHOD" "$URI" -d "$DATA");EXIT_STATUS=$?;;
        *)
            curl -sf -H "Accept: application/json" \
                    -H "X-Api-Key: $RADARR_API_KEY" \
                    -X "$METHOD" "$URI";EXIT_STATUS=$?;;
    esac
    if [[ $EXIT_STATUS -ne 0 && $ENDPOINT != "tag" ]]; then
        echo "api_caller: $METHOD - $URI" | simpleLog
        echo "api_caller: curl error code $EXIT_STATUS; https://everything.curl.dev/usingcurl/returns" | simpleLog
        echo "$CURL_RESP"
        exit 1
    fi
    return 0
}
test_variable() {
    if [[ -z "$1" || "$1" == "[]" || "$1" == "null" ]];then return 1;fi
    return 0
}
movie_checker() {
    local MOVIE_DATA MOVIE_TITLE MOVIE_YEAR MOVIE_STATUS MOVIE_CINEMA MOVIE_DIGITAL MOVIE_PHYSICAL \
    MOVIE_MONITORED TAG_HANDLER TIMESTAMP; TIMESTAMP=0; unset MOVIE_ID MOVIE_PATH MOVIE_TAGS
    # Arguments
    while [[ $# -gt 0 ]];do case "$1" in
        -D|"--data") shift; MOVIE_DATA="$1";shift;;
        *) echo "movie_checker: Invalid argument, must use '-D|--data'" | simpleLog;exit 1;;
    esac done
    # Fail safe
    if ! test_variable "$MOVIE_DATA"; then
        echo "movie_checker: missing value for '-D|--data'." | simpleLog; exit 1
    fi
    # Get Required Data and place it in 
    while IFS= read -r MOVIE_RES; do
        unset line; line="${MOVIE_RES%\"}";line="${line#\"}"
        if [[ -z "$MOVIE_ID" ]]; then MOVIE_ID="$line"
        elif [[ -z "$MOVIE_TITLE" ]]; then MOVIE_TITLE="$line"
        elif [[ -z "$MOVIE_YEAR" ]]; then MOVIE_YEAR="$line"
        elif [[ -z "$MOVIE_PATH" ]]; then MOVIE_PATH="$line"
        elif [[ -z "$MOVIE_STATUS" ]]; then MOVIE_STATUS="$line"
        elif [[ -z "$MOVIE_CINEMA" ]]; then MOVIE_CINEMA="$line"
        elif [[ -z "$MOVIE_DIGITAL" ]]; then MOVIE_DIGITAL="$line"
        elif [[ -z "$MOVIE_PHYSICAL" ]]; then MOVIE_PHYSICAL="$line"
        elif [[ -z "$MOVIE_MONITORED" ]]; then MOVIE_MONITORED="$line"
        elif [[ -z "$MOVIE_TAGS" || "$line" != "[]" ]]; then 
            readarray -t MOVIE_TAGS < <(echo "$line" | jq '.[]')
        else break; fi
    done < <(echo "$MOVIE_DATA" | \
        jq -c '.id,.title,.year,.path,.status,.inCinemas,.digitalRelease,.physicalRelease,.monitored,.tags')
    # If movie is not monitored and this is not a radarr event, skip.
    if [[ "$MOVIE_MONITORED" == "false" && -z "$radarr_eventtype" ]]; then
        return 0
    fi
    # If movie has no year, we tag it
    if [[ "$MOVIE_YEAR" == "0" ]]; then
        echo "Movie: $MOVIE_TITLE ($MOVIE_YEAR)" | simpleLog
        echo "-----| Year not found." | simpleLog
        store_movie_id -T
        return 0
    fi
    echo "Movie: $MOVIE_TITLE ($MOVIE_YEAR)" | simpleLog
    # If movie is released
    if [[ "$MOVIE_STATUS" == "released" ]]; then
        # skip if this is a radarr event or untag it
        if [[ -n "$radarr_eventtype" ]];then return 0;fi
        store_movie_id
        return 0
    fi
    # Convert release date to epoch; cinema date takes priority
    if test_variable "$MOVIE_CINEMA";then TIMESTAMP="$(date -d"$MOVIE_CINEMA" +%s)"
    echo "-----| Cinema Date: $(date -d"$MOVIE_CINEMA" '+%a %d %B %Y')" | simpleLog
    else # Get earliest dates between digital/physical
        if test_variable "$MOVIE_DIGITAL";then TIMESTAMP="$(date -d"$MOVIE_DIGITAL" +%s)"
            echo "-----| Digital Date: $(date -d"$MOVIE_DIGITAL" '+%a %d %B %Y')" | simpleLog; fi
        if test_variable "$MOVIE_PHYSICAL"; then CACHE_TIMESTAMP="$(date -d"$MOVIE_PHYSICAL" +%s)"
            echo "-----| Physical Date: $(date -d"$MOVIE_PHYSICAL" '+%a %d %B %Y')" | simpleLog
            if [[ $CACHE_TIMESTAMP -lt $TIMESTAMP || $TIMESTAMP -eq 0 ]]; then
                echo "-----| Using Physical." | simpleLog; TIMESTAMP="$CACHE_TIMESTAMP"
            else echo "-----| Using Digital." | simpleLog; fi
        fi
    fi
    # Compare to 'MAX_AVAILABILITY'
    ((TIMESTAMP=TIMESTAMP-$(date -d"$MAX_AVAILABILITY 23:59:59" +%s)))
    echo "-----| Max Availability: $(date -d"$MAX_AVAILABILITY" '+%a %d %B %Y')" | simpleLog
    if [[ $TIMESTAMP -gt 0 ]]; then
        store_movie_id -T
        return 0
    fi
    # Only applies to non-radarr events
    if [[ -z "$radarr_eventtype" ]]; then
        # If we get to this point then the movie can be untagged
        store_movie_id
        return 0
    fi
}
store_movie_id() {
    local TAG_HANDLER JSON_TAG JSON_KEY NEW_JSON
    TAG_HANDLER="false"
    # Arguments
    while [[ $# -gt 0 ]]; do case "$1" in
        -T|--tag) TAG_HANDLER="true"; shift;;
        *) break;;
    esac; done
    if [[ "$TAG_HANDLER" == "false" ]]; then
        if [[ -z "${MOVIE_TAGS[*]}" ]]; then
            return 0
        fi
        echo "-----| Untagging: saving movie ID" | simpleLog
        JSON_TAG='"tag":[],"untag":['"$MOVIE_ID"']'; JSON_KEY="untag"
    else
        # get tag id
        TAG_ID="$(get_tag_id)"
        # Compare tags from movie to tag id
        if [[ -n "$MOVIE_TAGS" ]]; then
            for T in "${MOVIE_TAGS[@]}"; do
                if [[ $T -eq $TAG_ID ]]; then
                    echo "-----| Tagging: already tagged" | simpleLog
                    return 0
                fi
            done
        fi
        echo "-----| Tagging: saving movie ID" | simpleLog
        # Configure json tagging format and key for updates
        JSON_TAG='"tag":['"$MOVIE_ID"'],"untag":[]'; JSON_KEY="tag"
    fi
    # Convert rootfolders to bash array if not set
    if [[ -z "$ROOTFOLDERS" ]]; then
        readarray -t ROOTFOLDERS < <(api_caller -M GET -E "rootfolder" | jq -r '.[] | .path')
        echo "-----| Getting list of rootfolders.." | simpleLog
    fi
    # Find out what root folder our movie belongs to.
    for R in "${ROOTFOLDERS[@]}"; do
        case "$MOVIE_PATH" in
            "$R/"*)
                if [[ "$MOVIE_ROOTPATH" != "$R" ]]; then
                    MOVIE_ROOTPATH="$R"
                    echo "-----| Rootfolder: $MOVIE_ROOTPATH" | simpleLog
                fi; break;;
            *) :;; # do nothing
        esac
    done
    if [[ -z "$MOVIE_ROOTPATH" ]]; then
        echo "-----| Unable to find rootfolder for this movie.."
        echo "-----| Movie Path: $MOVIE_PATH"
        echo "-----| Root Paths: ${ROOTFOLDERS[*]}"
        return 1
    fi
    if ! test_variable "$MOVIE_JSON"; then
        echo "-----| Creating data for api.." | simpleLog
        # First time
        MOVIE_JSON='[{"path":"'"$MOVIE_ROOTPATH"'",'"$JSON_TAG"'}]'
        return 0
    fi
    # Get Index to existing root path from movie_json
    JSON_INDEX=$(echo "$MOVIE_JSON" | jq 'map(.path=="'"$MOVIE_ROOTPATH"'") | index(true)')
    #$(json -D "$MOVIE_JSON" -k 'map(.path=="'"$MOVIE_PATH"'") | index(true)')
    case "$JSON_INDEX" in
        ''|*[!0-9]*)
            # Create Path if it does not exist
            NEW_JSON="$(echo "$MOVIE_JSON" | jq '. += [{"path":"'"$MOVIE_ROOTPATH"'",'"$JSON_TAG"'}]')";;
        *)
            # Path exists, add id to (un)tag
            CHECK_ID="$(echo "$MOVIE_JSON" | jq '.['"$JSON_INDEX "'] | select((any(.tag[]; . == '"$MOVIE_ID"')) or (any(.untag[]; . == '"$MOVIE_ID"')))')"
            if [[ -n "$CHECK_ID" ]]; then
                echo "-----| Movie ID already exists '$MOVIE_ID'" | simpleLog; return 1
            fi
            NEW_JSON=$(echo "$MOVIE_JSON" | jq '.['"$JSON_INDEX"'].'"$JSON_KEY"' += ['"$MOVIE_ID"']')
    esac
    # Update movie_json
    if test_variable "$NEW_JSON"; then
        echo "-----| Updating data for api.." | simpleLog
        MOVIE_JSON="$NEW_JSON"
    fi
    return 0
}
process_movie_json() {
    local JSON_PATH JSON_MOVIE MOVIE_UPDATER MOVIE_TAG
    if ! test_variable "$MOVIE_JSON";then
        return 0;
    fi
    echo "-----| Processing movies by ID and rootpath." | simpleLog
    TAG_ID="$(get_tag_id)"
    while IFS= read -r JSON_PATH; do
        JSON_MOVIE=$(echo "$MOVIE_JSON" | jq -c '.[] | select(.path=="'"$JSON_PATH"'") | .tag')
        if test_variable "$JSON_MOVIE"; then
            if [[ -z "$MOVIE_TAG" ]]; then
                MOVIE_TAG="{\"movieIds\":$JSON_MOVIE,\"tags\":[$TAG_ID],\"applyTags\":\"add\"}"
            else
                MOVIE_TAG=$(echo "$MOVIE_TAG" | jq -c '.movieIds += '"$JSON_MOVIE"'')
            fi
        fi
        JSON_MOVIE=$(echo "$MOVIE_JSON" | jq -c '.[] | select(.path=="'"$JSON_PATH"'") | .untag')
        if test_variable "$JSON_MOVIE"; then
            MOVIE_UPDATER+=("{\"movieIds\":$JSON_MOVIE,\"tags\":[$TAG_ID],\"applyTags\":\"remove\",\"rootFolderPath\":\"$JSON_PATH\",\"moveFiles\":true}")
        fi
    done < <(echo "$MOVIE_JSON" | jq -r '.[] | .path')
    # Test to figure out why this is not working as expected.
    if [[ -n "$MOVIE_TAG" ]]; then
        api_caller -M PUT -E 'movie/editor' -D "$MOVIE_TAG" | simpleLog
        echo "-----| Tagging complete" | simpleLog
    fi
    for J in "${MOVIE_UPDATER[@]}"; do
        sleep 0.5
        api_caller -M PUT -E 'movie/editor' -D "$J" | simpleLog
    done
    if [[ -n "${MOVIE_UPDATER[*]}" ]]; then
        echo "-----| Untagging and updating movie folders complete" | simpleLog
    fi
    unset MOVIE_JSON; return 0
}
get_tag_id() {
    if [[ -n "$TAG_ID" ]];then echo "$TAG_ID";return 0;fi
    # Create tag if missing
    api_caller -M POST -E tag -D "{\"label\":\"$RADARR_TAG\"}"
    TAG_ID="$(api_caller -M GET -E tag | jq -r '.[] | select(.label=="'"$RADARR_TAG"'") | .id')"
    if ! test_variable "$TAG_ID"; then
        echo "Unable to find '$RADARR_TAG' tag" | simpleLog
        exit 1
    fi
    case "$TAG_ID" in
        ''|*[!0-9]*) 
            echo "TAG ID: '$TAG_ID' is not integer" | simpleLog
            exit 1;; *) echo "$TAG_ID"; return 0;;
    esac
}
movie_by_tag() {
    local TAG_ID
    TAG_ID="$(get_tag_id)"
    # Validate Tag ID
    case $TAG_ID in
        ''|*[!0-9]*)
            echo "Invalid Tag ID for function 'movie_by_tag'" | simpleLog; return 1;;
        *)
            # Filter Movies by Tag
            while IFS= read -r line; do
                # Check Movie release data
                movie_checker -D "$line"
            done < <(api_caller -M GET -E movie | jq -c '.[] | select(.tags[] | contains('"$TAG_ID"'))')
            ;;
    esac
}
simpleLog() {
    local MAX_SIZE GET_NAME PATH_NOEXT FILE_EXT REMOVE_OLDEST
    while read -r INPUTLINE; do
        if [[ -n "$LOG_PATH" ]]; then
            echo "$INPUTLINE" | tee -a "$LOG_PATH"
        else
            echo "$INPUTLINE"
        fi
    done
    if [[ -z "$LOG_PATH" ]]; then return 0; fi
    MAX_SIZE=200000 # Default size; 200KB in B
    if [[ $(stat -c%s "$LOG_PATH" 2>/dev/null) -ge $MAX_SIZE ]]; then
        GET_NAME="$(basename -- "$LOG_PATH")"
        PATH_NOEXT="$(dirname -- "$LOG_PATH")/${GET_NAME%.*}"
        FILE_EXT="${GET_NAME##*.}"

        REMOVE_OLDEST=true
        for i in {3..1}; do
            if [[ -f "$PATH_NOEXT-$i.$FILE_EXT" ]]; then
                if [[ "$REMOVE_OLDEST" == true ]]; then
                    rm -f "$PATH_NOEXT-$i.$FILE_EXT"
                else
                    cp "$PATH_NOEXT-$i.$FILE_EXT" "$PATH_NOEXT-$((i+1)).$FILE_EXT"
                fi
            fi
            REMOVE_OLDEST=false
        done
        cp "$LOG_PATH" "$PATH_NOEXT-1.$FILE_EXT"
        : > "$LOG_PATH"
    fi
}
#
# MAIN CODE
#
if [[ "$radarr_eventtype" == "MovieAdded" ]]; then
    # Tag movie if year is missing
    if [[ "$radarr_movie_year" == "0" ]]; then
        TAG_ID="$(get_tag_id)"
        echo "$radarr_movie_title (0)" | simpleLog
        echo "-----| Missing Year." | simpleLog
        echo "-----| Tagging: one movie." | simpleLog
        api_caller -M PUT -E 'movie/editor' -D "{\"movieIds\":[$radarr_movie_id],\"tags\":[$TAG_ID],\"applyTags\":\"add\"}" | simpleLog
        echo "-----| Tagging: complete." | simpleLog
        exit 0
    fi
    # Get Date for movie
    MOVIE_DATA=$(api_caller -M GET -E movie -i "$radarr_movie_id") 
    if [[ -z "$MOVIE_DATA" ]]; then
        echo "Missing movie data" | simpleLog
        exit 1
    fi
    movie_checker -D "$MOVIE_DATA"
    process_movie_json
fi
# If this is not a radarr event then check all movies with tag
if [[ -z "$radarr_eventtype" ]]; then
    movie_by_tag
    process_movie_json
fi
