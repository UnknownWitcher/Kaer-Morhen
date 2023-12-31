# RCLONE

⚠️ **WARNING - UNDER CONSTRUCTIONS README IS NOT COMPLETE**

Scripts taken from [SpaceInvaderOne's video](https://www.youtube.com/watch?v=-b9Ow2iX2DQ) and what I could find online regarding setting up rclone.

⚠️ **Warning** This SpaceInaderOnes' video is very outdated and a lot has changed in urnaid, I will do my best to provide a text tutorial on how to set this up.

#### Installing Rclone
- Unraid > APPS
  - Search for rclone and install the plugin by Waseh
- Unraid > SETTINGS > rclone
  - Make sure the branch is `Stable`.
  - If you have an existing config you can paste it into the config and then hit apply.
    - ℹ️ You can then move on to adding the scripts and setting up a schedule.
  - If you don't we'll need to configure it.
    - ℹ️ You can do this through the terminal window on unraid by clicking on the icon "**\>\_**" (top left) or you can
      use windows command prompt (or putty) choice is yours
    - if ssh does not work for you, go to Settings > Management Access and enable or disable then enable again.
    

## RCLONE MOUNT
- **Schedule:** `At Startup of Array`

## RCLONE UNMOUNT
- **Schedule:** `At Stopping of Array`
