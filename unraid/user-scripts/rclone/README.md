# RCLONE

Scripts taken from [SpaceInvaderOne's video](https://www.youtube.com/watch?v=-b9Ow2iX2DQ) and what I could find online regarding setting up rclone on unraid.

⚠️ **Warning** The SpaceInaderOnes video is very outdated and a lot has changed in unraid, I will do my best to provide a text tutorial on how to set this up.

#### Installing Rclone
- **Unraid > APPS**
  - Search for rclone and install the plugin by Waseh
- **Unraid > SETTINGS > rclone**
  - Make sure the branch is `Stable`.
  - If you have an existing config you can paste it into the config and then hit apply.
    - ℹ️ You can then go to User Scripts plugin to add and setup the schedule.[^1]
  - If you don't you'll need to configure it. [Config Tutorial](#rclone-config-tutorial)

## RCLONE MOUNT
- **Schedule:** `At Startup of Array`

## RCLONE UNMOUNT
- **Schedule:** `At Stopping of Array`

## Rclone Config Tutorial

- ℹ️ You can do this through the terminal window on unraid by clicking on the icon "**\>\_**" (top right) or you can
  use windows/linux/mac command prompt (or putty) choice is yours[^2]
  
- ⚠️ If ssh does not work for you, go to **Unraid > SETTINGS > Management Access** and (disable then) enable.

- ℹ️ TIP: [download and extract rclone](https://rclone.org/downloads/) for your main operating system and open a second terminal/command prompt on that system,
  then `cd a:\path\to\rclone`, when you go through the process of configuring rclone in your ssh terminal, you'll need to complete the process on another terminal.

I'm going to use google in this example as I don't want to re-configure my dropbox..

I'm only going to setup the non-encrypted remote, so to encrypt you would go through this process again except when selecting your storage, you wold choose

```
14 / Encrypt/Decrypt a remote
   \ (crypt)
```

I also suggest using `crypt-name` and `dcrypt-name`, with the encryption you only need to set this up once for one remote, then you can go into your config and copy/paste that part of the configuration and change it to work with another remote.

REMOTE SSH TERMINAL

```
unraid> rclone config

e) Edit existing remote
n) New remote
d) Delete remote
r) Rename remote
c) Copy remote
s) Set configuration password
q) Quit config
e/n/d/r/c/s/q> n

Enter name for new remote.
name>dcrypt-gdrive

Option Storage.
Type of storage to configure.
Choose a number from below, or type in your own value.

>> NOTE: look through this to find your storage provider (here are two examples)
13 / Dropbox
   \ (dropbox)
18 / Google Drive
   \ (drive)
Storage>18

Option client_id.
Google Application Client Id
Setting your own is recommended.
See https://rclone.org/drive/#making-your-own-client-id for how to create your own.
If you leave this blank, it will use an internal key which is low performance.
Enter a value. Press Enter to leave empty.
client_id> <REMOVED>   

Option client_secret.
OAuth Client Secret.
Leave blank normally.
Enter a value. Press Enter to leave empty.
client_secret> <REMOVED>

Option scope.
Comma separated list of scopes that rclone should use when requesting access from drive.
Choose a number from below, or type in your own value.
Press Enter to leave empty.
 1 / Full access all files, excluding Application Data Folder.
   \ (drive)
 2 / Read-only access to file metadata and file contents.
   \ (drive.readonly)
   / Access to files created by rclone only.
 3 | These are visible in the drive website.
   | File authorization is revoked when the user deauthorizes the app.
   \ (drive.file)
   / Allows read and write access to the Application Data folder.
 4 | This is not visible in the drive website.
   \ (drive.appfolder)
   / Allows read-only access to file metadata but
 5 | does not allow any access to read or download file content.
   \ (drive.metadata.readonly)
scope> 1 >> NOTE: 1 is what most people want, if you're not sure then choose 1.

Option service_account_file.
Service Account Credentials JSON file path.
Leave blank normally.
Needed only if you want use SA instead of interactive login.
Leading `~` will be expanded in the file name as will environment variables such as `${RCLONE_CONFIG_DIR}`.
Enter a value. Press Enter to leave empty.
service_account_file> 

Edit advanced config?
y) Yes
n) No (default)
y/n> n

Use web browser to automatically authenticate rclone with remote?
 * Say Y if the machine running rclone has a web browser you can use
 * Say N if running rclone on a (remote) machine without web browser access
If not sure try Y. If Y failed, try N.

y) Yes (default)
n) No >> NOTE: the rclone we're configuring is not on the same system so we choose 'no'
y/n>n

Option config_token.
For this to work, you will need rclone available on a machine that has a web browser available.
For more help and alternate methods see: https://rclone.org/remote_setup/
Execute the following on the machine with the web browser (same rclone version recommended):
        rclone authorize "drive" "[really long authcode]"
Then paste the result.
Enter a value.
config_token>[really long confirmation code]

>> NOTE: For config_token, refer to the other terminal.

Configure this as a Shared Drive (Team Drive)?

y) Yes
n) No (default)
y/n> n

>> NOTE: I highly suggest using teamdrive and shared accounts on google
         if you have the option to use them, these can be added later.

Configuration complete.
Options:
- type: drive
- client_id: 486701372951-jppjai8jf1ndi9rbbqmcd52bu0sk8k8g.apps.googleusercontent.com
- client_secret: 53JsaasayLsHhns1hcFJIPsb
- scope: drive
- token: {"access_token":"<removed>","token_type":"Bearer","refresh_token":"<removed>","expiry":"<removed>"}
- team_drive: 
Keep this "dcrypt-gdrive" remote?
y) Yes this is OK (default)
e) Edit this remote
d) Delete this remote
y/e/d> y

NOTE: Thats all there is to it. Now you can add your mount scripts to unraid, making sure to use your remote names.
```
    
OTHER TERMINAL ON OUR SYSTEM

```    
A:\rclone-v1.65.0-windows-amd64>rclone authorize "drive" "[really long authcode]"
2023/12/31 22:00:40 NOTICE: Make sure your Redirect URL is set to "http://127.0.0.1:53682/" in your custom config.
2023/12/31 22:00:40 NOTICE: If your browser doesn't open automatically go to the following link: http://127.0.0.1:53682/auth?state=<removed>
2023/12/31 22:00:40 NOTICE: Log in and authorize rclone for access
2023/12/31 22:00:40 NOTICE: Waiting for code...

>> NOTE: Your browser should open a new tab and your provider will appear (this might display an error)
         Example: "Google hasn’t verified this app"
         This is the app you created on google so you can safely ignore this warning.

         Click Advanced, then click "Go to My OCAMLDrive (unsafe)", now click Continue.

         This will vary depending on the cloud provider. But once approved the following will appear.

2023/12/31 22:01:45 NOTICE: Got code
Paste the following into your remote machine --->
[really long confirmation code]
<---End paste
```

[^1]: [How to install User Script and add a script](/UnknownWitcher/Kaer-Morhen/tree/main/unraid/user-scripts#installing-user-script-and-adding-scripts-to-it).
[^2]: To run ssh on windows, open command prompt, then enter `ssh username@<ip or host>`, (for now) hit enter and type yes. 
In Putty, under Session category enter `username@<ip or host>`, make sure port is `20` and then click Open, you can also save this for future sessions.
