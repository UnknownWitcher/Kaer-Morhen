# Kaer-Morhen
Personal scripts that I am using/working on.

### /rclone/upload.sh
The goal of this script was to have something that automatically switches between service accounts to avoid google errors/limitation such as the user rate limit or when it reaches the 750GB limit.

To do this I have setup some custom rules that can be enabled or disabled within the configuration section, if a rule has been triggered and it's enabled, then it will kill the current upload session and switch to another service account.

At least thats the goal, this script as of right now is uploading files to my shared drives, I haven't had the chance to run into any of my rules so as of right now they're untested.

### Configuration

`SA_JSON_FOLDER=""` this is the folder to your service accounts, which should all be json files.

`RC_SOURCE=("")` this should be a local folder that you want to upload from, example; **"__/media/local/movies__"**

`RC_DESTINATION=("")` this is your google mount:path you want to upload to **"__gd_mount:Movies__"**

`RC_CONFIG=""` If your rclone config is not in the default path, then enter that path here, otherwise just leave it blank.

`RC_SETTINGS=("")` Customisable rclone settings

`RC_LOG_FILE=""` Customisable, it's up to you where you want rclone logs to be store as well as the file name.ext

`RC_LOG_TYPE=""` What type of output do you want from rclone.

`RC_DRY_RUN=` It is strongly recommended to set this to true when you're first running the script or if you make changees to rclones settings.

`SA_RULES=()` Rules that force rclone to switch to a new service account.

### `RC_SOURCE` and `RC_DESTINATION`

With these variables, you can have multiple source and destination paths added if needed.

Example 1:
```
RC_SOURCE=(
    "/mnt/media/local/Shows"
    "/mnt/media/local/Movies"
    "/mnt/media/local/Music"
)
RC_DESTINATION=(
    "gd_series:Shows"
    "gd_films:Movies"
    "gd_crypt:Music"
)
```
Example 2:
```
RC_SOURCE=(
    "/mnt/media/local/"
)
RC_DESTINATION=(
    "gd_crypt:Media"
)
```
Both the source and destination must contain the same amount of values, so if you have 2 source paths you must enter 2 destinations.

### `SA_RULES` **untested**

In this script I have all the rules set to true with the limit set to 1, this is something that really needs tested, however, I wont be able to test the 750G rule for another 2 weeks and have yet to run into any other issues in order to get these triggred.

`"limit" 1` how many rules have to be triggered before we switch to another service account, default 1.

`"more_than_750" false` When daily 750G limit is reached, **default false**.

`"user_rate_limit" false` When rclone reports the user rate limit error, **default false**.

`"all_transfers_zero" false` When transfer size is 0, **default false**.

`"no_transfer_between_checks" true` When the amount of transfers after 100 checks is 0 **default true**.

