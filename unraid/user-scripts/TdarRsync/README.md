# TdarRsync
>I needed a script that would copy files from my cloud storage to unraid, I was originally going to use rclone copy but this was just an easier way to handle this.

**CONFIGURATION**
| Name  | Example | Details | Optional |
| ------------- | ------------- | ------------- | ------------- |
| source     | /mnt/disks/series | Location we're copying from  | ❌ |
| target     | /mnt/user/downloads/series | Location we're copying to | ❌ |
| database   | /mnt/user/downloads | Where do you want the database to be stored  | ❌ |
| subfolder  | /Title (2024)/Season 01 | Allows you to specify a subfolder witin the source path  | ✔️ |

- The subfolder allows you to be specific with what you want to download and transcode, if you want to download everything then you leave this option empty.
- The database is pretty simple, it creates an empty 0B file in a similar structure to the source, so that when we loop through the directory, all the script
needs to do is check to see whether or not this file exists in our database folder.

*How the script works based on the above values*
##### rsync
`rsync -a "/mnt/disks/series/Title (2024)/Season 01/S01E01.mkv" "/mnt/user/downloads/series/Title (2024)/Season 01"`
##### database
`/mnt/user/downloads/tdarrsyncDB/Title (2024)/Season 01/S01E01.tsdb`
##### TDARR LIBRARY CONFIGURATION
###### Note: These are the options that are required for this to work, everything else is optional but I would recommend enabling Health checks
|     Name     |    Value    |
| ------------- | ------------- |
|Source| same as target |
| Folder Watch     | ✔️ |
| Process Library  | ✔️ |
| Transcodes  | ✔️ |
