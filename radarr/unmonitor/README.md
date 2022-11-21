# unmonitor.sh

### What is this??
This script will automatically unmonitor a movie once the movie has been downloaded and imported. It's a simple script but I made it for a someone on a plex group that prefers to unmonitor their media once it has been downloaded.

### Requirements

**curl** - `sudo apt install curl` - current version tested: 7.68.0, you can type `which curl` into your terminal to see if you already have curl installed.

### Configuration

**RADARR_API_KEY** - get this in `settings > general > security > api key`

**RADARR_URL** - the address you use to access radarr, i.e; http://localhost:7878

### Adding this script to radarr

Go to Radarr `Settings > Connect` and click the plus icon, then select `Custom Script`.

![image](https://user-images.githubusercontent.com/82295355/203098219-b837bcf9-1bdb-49db-8c2d-425e125d8ea1.png)
