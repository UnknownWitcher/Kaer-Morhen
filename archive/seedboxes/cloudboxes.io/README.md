# cloudboxes.io

### The purpose of this project.

This provider (for some strange reason) does not allow users to use systemd which means we cannot run rclone as a service, instead we have to run 
it as a script using supervisord, this results in phantom rclone mounts being created which severely drops performance, it doesn't matter if you 
use the rclone browser container or if you install rclone in terminal and run the mount through supervisord, this issue persisted.

At the time, while using gdrive I created shell scripts that handled this issue but then this provider made changes in January 2023 to try 
and combat the rclone issue, basically they kill your mounts when you stop/start any container which is a major issue if you're running a media server
for the family and need to restart a different container because now nobody can use that media server until the mounts start working again.

This is where I ran into issues, majority of the time the mounts wouldn't re-mount, I decided to switch to python since most of the features needed already
existed, so I didn't have to find ways to recreate them in bash, after trial and error it works pretty well, I would like to say it's flawless but 
realistically it works 99% of the time, over the past 12 months after some minor updates to the code, I've not had to look at it or worry too much about it
not re-mounting.

