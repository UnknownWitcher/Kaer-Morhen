# TdarRsync
I needed a script that would do the following
- [x] Download media files from cloud storage to local storage (cache).
- [x] Preserve relative paths.
- [x] Limit total amount of media files on cache at one time.
- [x] Avoid re-downloading the same files.

### ⚙️ Configuration
| Name  | Example | Details | Optional |
| ------------- | ------------- | ------------- | ------------- |
| source     | /mnt/disks/series | The location we are copying from  | ❌ |
| target[^1]     | /mnt/user/downloads/series | Temporary location we are copying to | ❌ |
| database[^2]   | /mnt/user/downloads | Where do you want the database to be stored  | ❌ |
| subfolder[^3]  | /Title (2024)/Season 01 | Allows you to specify a subfolder witin the source path  | ✔️ |
| file limit[^4] | 10 | How many files to download before pausing to let tdarr process | ❌ |

[^1]: Target should always be a temporary path, tdarr uses this as its source and then moves the processed file to its final location.
[^2]: Database is the path where we store empty 0 byte duplicates of our files, this is used to identify files we've already downloaded.
[^3]: Subfolder allows you to be more specific about what you want to download from the source path. This **MUST** be a folder to work
and there are no limits to how many subfolders you can add to this.
[^4]: File limit ensures that the cache being used to store these files doesn't get full while tdarr is processing them, i find 10 is a good limit for my internet connection.

### ☊ Tdarr Library - basic requirements
|     Name     |    Value    | Necessity |
| ------------- | ------------- | ------------- |
| Source         | [target](#%EF%B8%8F-configuration) | Required |
| Folder Watch   | ✔️ | Required |
| Process Library| ✔️ | Required |
| Transcodes     | ✔️ | Recommended |
| Health Checks  | ✔️ | Recommended |
>**Note:** With the exception of the required settings, everything else is up to you, as long as tdarr processes the files and removes it
from the target directory then this script will work.

### 🐞 BUGS
>These are issues that I have encountered while using this script, hopefully I resolve all of them.
- [x] ~~Issue: Empty directories are not being removed.~~ Solved: Added cleaner with trap exit.
- [x] ~~Issue: queue limit is not checked during startup.~~ Solved: Add check to count existing files in target.
- [x] ~~Issue: Database can fail to update if user aborts script just as a file is downloaded.~~ Solved: Added check to cleaner function.
