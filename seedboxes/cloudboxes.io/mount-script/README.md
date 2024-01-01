# MOUNT SCRIPTS (01/01/2024)

This is my replacement mount script that has worked 99% of the time with this seedbox for the past 12 months.

### rc-mount.py
I tried to make this as simple as possible, bear in mind this is for my use case so I have not tested every option that rclone provides,
with that said this should work with every option.

### rc-mount.yml
This is an example of my config file with important information changed. Bear in mind I am using dropbox as my provider,
so if you're using a different provider then keep this in mind when modifying the config file.

### supervisor example

```conf
[program:db-films]
command=/usr/bin/python3 /mnt/shared/scripts/supervisord/rc-mount.py -p name
autostart=true
user=<your username>
stopsignal=TERM
startretries=10
autorestart=true
```

### CONFIGURATION

Install **python3** and Install the python package **yaml**.

With yaml I had to run it under sudo `sudo pip install yaml` for supervisor to recognise the package.

The config file works the same as entering the options directly into rclone the only difference is that we are excluding the dash `-` in the config file but the script adds this in for us.

**PROFILES**

**A profile is always required** as we use the profile name to tell rclone what options we want to mount with.

```yaml
profile:
    name:
        option: "value"
```

**Following options are required**

Bear in mind that even though these options are required it is typically a good idea to include other options to avoid api or other issues with your provider.

Documentation: [rclone_mount](https://rclone.org/commands/rclone_mount/) | [rc](https://rclone.org/rc) 

| option | example |
|:---:|:---:|
| source | `"remote:path/to/file"`|
| target | `"/path/to/local/mount"`|
| [rc](https://rclone.org/rc/#rc)                 | True               |
| [rc-addr](https://rclone.org/rc/#rc-addr-ip)    | `"127.0.0.1:5576"` |
| [rc-user](https://rclone.org/rc/#rc-user-value) | "username"         |
| [rc-pass](https://rclone.org/rc/#rc-pass-value) | "password"         |
