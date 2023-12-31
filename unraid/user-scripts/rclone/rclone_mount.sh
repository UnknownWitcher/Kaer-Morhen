#!/bin/bash

mkdir -p /mnt/disks/db_films
mkdir -p /mnt/disks/db_shows

rclone mount --max-read-ahead 1024k --allow-other dcrypt-films: /mnt/disks/db_films &
rclone mount --max-read-ahead 1024k --allow-other dcrypt-shows: /mnt/disks/db_shows &
