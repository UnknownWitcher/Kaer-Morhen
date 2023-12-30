# TdarRsync
I needed a script that would copy files from my cloud storage to unraid, then have tdarr processes those files and move them to my array.

###### important: Relative path is maintained when downloading.
###### important: Tdarr needs to move/delete the file out of target path after processing

##### HOW IT WORKS
- `rclone mount` **[source](#configuration)**
- Script reads through source path.
  - Checking each file against our database folder.
    - Files are ignored if they have already been downloaded.
      - File path and target path sent to **[rsync](#rsync)**
        - Once download completes **[database](#database)** is updated.
          - Once **file limit 10** is reached, stop downloading.
            - Every 60s check to see if the target files still exists in the target path
              - When 5 files are processed by tdarr
                - Start downloading to refill limit.
- **[Tdarr library](#tdarr-library-configuration)** monitors target path using **Folder Watch**
  - Flow/Transcode plugins used to process target file
    - Target file replaced with processed file then moved while keeping `Relative Path`
    - Or processed file moved while maintaining `Relative Path` and target file deleted

##### CONFIGURATION
| Name  | Example | Details | Optional |
| ------------- | ------------- | ------------- | ------------- |
| source     | /mnt/disks/series | Location we're copying from  | ❌ |
| target     | /mnt/user/downloads/series | Temporary location we're copying to | ❌ |
| database   | /mnt/user/downloads | Where do you want the database to be stored  | ❌ |
| subfolder  | /Title (2024)/Season 01 | Allows you to specify a subfolder witin the source path  | ✔️ |

- Target - should be a temporary location and tdarr needs to be configured to move the processed file to the media location.
- The subfolder allows you to be specific with what you want to download and transcode, if you want to download everything then leave this option empty.
- The database is pretty simple, it creates an empty 0B file in a similar structure to the source, so that when we loop through the directory, all the script
needs to do is check to see whether or not this file exists in our database folder.

*How the script works based on the above values*
##### rsync
`rsync -a "/mnt/disks/series/Title (2024)/Season 01/S01E01.mkv" "/mnt/user/downloads/series/Title (2024)/Season 01"`
##### database
`/mnt/user/downloads/tdarrsyncDB/Title (2024)/Season 01/S01E01.tsdb`

The script relies on the files being moved after they're processed by tdarr.

##### TDARR LIBRARY
###### Note: These options are required in order for tdarr to find the files and process them, other settings depend on your needs.
|     Name     |    Value    |
| ------------- | ------------- |
| Source           | [same as target](#configuration) |
| Folder Watch     | ✔️ |
| Process Library  | ✔️ |

I also have **transcode** and **health check** enabled and in my **flow** I have tdarr replace the original file (e.g, `/mnt/user/downloads/series/Title (2024)/Season 01/S01E01.mkv`)
and then I have that file moved to my media folder with `Keep Relative Path` enabled (e.g, `/mnt/user/series/Title (2024)/Season 01/S01E01.mkv`)

If you're not using the new flow feature then this should still be doable with the classic transcode options although it may require the creation of a plugin to do the moving/delete original file at the target location.
