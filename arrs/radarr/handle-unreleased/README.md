# handle-unreleased.sh

### What is this??
This script updates movie folders when we get closer to their release date, this is adjusted in the configuration section of the script. The reason we do this is because radarr does not automatically correct folder names for movies that do not have a year because they've just been announced, we also have issues with movies that do not have an official name yet. So we could end up with movie folders that look like this.
```
/I Am Legend 2 () [tmdb-945956]/

/Avatar 5 (2028) [tmdb-393209]/

/Untitled Ghostbusters - Afterlife Sequel (2023) [tmdb-967847]/
```
### How movies are tagged using this script
![tagging movies](https://user-images.githubusercontent.com/82295355/200149523-4381f763-e0ae-4319-8532-6158c59ce391.gif)
### How movies are untagged using this script
![untagging movies](https://user-images.githubusercontent.com/82295355/200166486-8223183a-c5ff-461b-ac85-de5334203201.gif)

### Requirements

**jq** - `sudo apt install jq` - current version tested: 1.6

**curl** - `sudo apt install curl` - current version tested: 7.68.0

### Configuration

**RADARR_API_KEY** - get this in `settings > general > security > api key`

**RADARR_URL** - the address you use to access radarr, i.e; http://localhost:7878

**RADARR_TAG** - I use `unreleased` for my tag, but set this to whatever you prefer.

**MAX_AVAILABILITY** - This creates a date X day/month/year(s) into the future, any release date beyond this date will be tagged.

**LOG_PATH** - Radarr handles errors for the script under `System > Events` and they can log the scripts output when debug is enabled, leaving this blank won't stop the script from printing this information to console, it just wont store the information in its log.

### Adding this script to radarr

Go to Radarr `Settings > Connect` and click the plus icon, then select `Custom Script`. Ignore the "Disabled" label, the script still functions, I can only assume this is a bug.

![handle-unreleased](https://user-images.githubusercontent.com/82295355/200163714-18e85c6f-a67c-4343-9cb7-989e3416bc37.jpg)

### How it works

The script performs three checks to determin if the movie should be tagged.

1. Missing Year? if the year is missing we can instantly tag the movie and skip all other checks.

2. Has the movie been released? if the movie status is "released" then we skip the last check.

3. Is the release date before or after `MAX_AVAILABILITY` date? if it's after then we tag it.

`MAX_AVAILABILITY="2 month"` - As I am writing this it is Nov 6th 2022, in 2 months it will be `Fri 6 January 2023`, if I use this value, then any movie that is released after that date will be tagged, if you run the script outside of radarr (i.e manually, cron) and the movie is release before that date, then it will be untagged and it's folder will be updated.

#### RADARR API HANDLING

**STAGE ONE** - Initial checks

When triggered by radarr, the first check `1` does not require api access as radarr sends this information to the script, the last two checks `2,3` requires api access. The script will pull the movies data in one api call, this will happen each time a movie with a year is added to radarr.

When not triggered by radarr, the script makes a single api call to grab all your movies, it filters by `RADARR_TAG` and ignores unmonitored movies, this means we only grab movies that have the tag and are marked as "monitored".

**STAGE TWO** - Tagging/Untagging and updating folder names.

When triggered by radarr, if the script is tagging a movie, it will make one api call, this will happen each time a movie is added to radarr and requires tagging.

When not triggered by radarr, the script will store the ID and rootpath for each tagged movie that needs untagged, the amount of api calls required for this will depend on how many root folders there are..

If 1,000 movies are going to be untagged and they all share the same root folder, then only one api call is needed.

If 1,000 movies are going to be untagged but 300 of them are in a different root folder, then there would be two api calls.

The reason for this is so that the script can update the movie folders, it does this by telling radarr to move your existing movies (that are being untagged) to the same root path that they already exist in, this doesn't move anything it just tricks radarr into renaming their folders. [Thanks to trash guides for this](https://trash-guides.info/Radarr/Tips/Radarr-rename-your-folders/).

**OTHER API STUFF**

The script will attempt to create the `RADARR_TAG` if it does not exist and then grabs the tags ID, this always occurs in a new instance of the script, so a normal run, whether we're tagging or untagging (assuming we're only dealing with one root folder), means there will be up to 3 api calls each time the script runs.

### Final thoughts

I will continue to try and find ways to improve this script. As a fun yet terrifying experiment I decided to tag all of my movies `3255` and run the script manually, the initial api call to get all the movies took about 9 seconds and then the entire process of checking each movie took about 14m35s before making two api calls to radarr in order to untag and rename my folders (estimate 6s to complete). I wanted to see how well this worked. I also forgot that I have `2014` movies marked as unmonitored, so only `1241` movies went through the entire checking process.
