# RCLONE

Scripts taken from [SpaceInvaderOne's video](https://www.youtube.com/watch?v=-b9Ow2iX2DQ) and what I could find online regarding setting up rclone.

⚠️ **Warning** This SpaceInaderOnes' video is very outdated and a lot has changed in unraid, I will do my best to provide a text tutorial on how to set this up.

#### Installing Rclone
- **Unraid > APPS**
  - Search for rclone and install the plugin by Waseh
- **Unraid > SETTINGS > rclone**
  - Make sure the branch is `Stable`.
  - If you have an existing config you can paste it into the config and then hit apply.
    - ℹ️ You can then go to User Scripts plugin to add and setup the schedule.[^1]
  - If you don't you'll need to configure it. [^2]
    - ℹ️ You can do this through the terminal window on unraid by clicking on the icon "**\>\_**" (top left) or you can
      use windows command prompt (or putty) choice is yours[^3]
    - ⚠️ if ssh does not work for you, go to **SETTINGS > Management Access** and (disable then) enable again.

[^1]: [How to install User Script and add a script](/UnknownWitcher/Kaer-Morhen/tree/main/unraid/user-scripts#installing-user-script-and-adding-scripts-to-it).
[^2]: Information coming soon.
[^3]: To run ssh on windows, open command prompt, then enter `ssh username@<ip or host>`, (for now) hit enter and type yes. 
In Putty, under Session category enter `username@<ip or host>`, make sure port is `20` and then click Open, you can also save this for future sessions.

## RCLONE MOUNT
- **Schedule:** `At Startup of Array`

## RCLONE UNMOUNT
- **Schedule:** `At Stopping of Array`
