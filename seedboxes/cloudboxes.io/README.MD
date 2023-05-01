# cloudboxes.io

## The purpose of this project.

This provider (for some strange reason) does not allow users to use systemd which means we cannot run rclone as a service, instead we have to run it as a script using supervisord, so I decided to create mount scripts that act in a similar way to the service file which prevents alot of the issues caused by how this provider handles rclone mounts and it works.. worked as I am one of the few users that don't cause i/o issues with my mounts due to how I have my rclones configured and how I have my scripts setup.

## Current Project

- New Mount Script - 01/May/2023
- New Upload Script - 01/May/2023

## Important

Recent changes to how this provider handles rclone mounts has caused my mounting script to become obsolete. I have been working on a new script to get things mounted however there are still some issues I can't seem to get around, I won't be updating my mount script on here until I can get it working 99.99% of the time, right now it works maybe 70% of the time.

The issue seems to be the cache (VFS), I've enabled debugging but nothing incidates any issues, so I don't know if the cache is getting corrupted or something but every now and again rclone wont re-mount, rclone itself is still running and I can access the api but the mount will not show up.

The only solution I've found is to delete the cache for that mount, however, I've read some posts/comments on the rclone forum and github that seems to indicate that eventually it will mount but that is not ideal for this provider.

**My current idea**

1. Attempt to mount for 30-60 seconds.
2. IF mount fails, stop rclone and delete the cache for this mount.
3. Attempt to mount for 30-60 seconds.
4. IF mount fails, throw error.

We don't want to remount everytime rclone is unmounted then mounted, so I think the best solution is to try and mount first, if the mount does not exist after x seconds, then we stop rclone and remove the cache for that mount.
