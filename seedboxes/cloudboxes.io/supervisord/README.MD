# supervisord (deprecated)

### This contains modified versions of my shell scripts that I use within supervisord.

WARNING: I may not be able to test every modified version of my original shell scripts, 
some parts of my script cannot be shared, they're also not as user friendly 
as I'd like them to be, in order to share how I have my box setup, it requires me to
modify the code, however, I am more than happy to help resolve any issues you my encounter

- rclone-movies.sh

     This was modified to be similar to a systemctl service files,
     for each mount you want to createm you would duplicate this
     shell script, rename it and then configure it for that specific
     mount.
     
     **supervisord config examples**
    ```
    [program:rclone-movies]
    command=/mnt/shared/scripts/supervisord/rclone-movies.sh
    autostart=true
    user=<SSH_USERNAME>
    stopsignal=TERM
    ```
    ```
    [program:rclone-series]
    command=/mnt/shared/scripts/supervisord/rclone-series.sh
    autostart=true
    user=<SSH_USERNAME>
    stopsignal=TERM
    ```
- rclone-service.sh

     This version closely resembles my own, this allows you to run
     multiple mounts from within one shell script.
     
     **supervisord config examples**
    ```
    [program:rclone-movies]
    command=/mnt/shared/scripts/supervisord/rclone-service.sh movies
    autostart=true
    user=<SSH_USERNAME>
    stopsignal=TERM
    ```
    ```
    [program:rclone-series]
    command=/mnt/shared/scripts/supervisord/rclone-service.sh series
    autostart=true
    user=<SSH_USERNAME>
    stopsignal=TERM
    ```

- rclone-upload.sh

  Coming soon

- mergerfs-service.sh

  Coming Soon
