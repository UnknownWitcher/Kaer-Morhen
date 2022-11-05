# radarr scripts
**My OS:** Ubuntu 22.04.1 LTS
## handle-unreleased.sh

**RADARR_API_KEY** get this in `settings > general > security > api key`

**RADARR_URL** the address you use to access radarr, if this script is local then you could use http://localhost:7878

**RADARR_TAG** I use `unreleased` for my tag, but set this to whatever you prefer.

**MAX_AVAILABILITY** This creates a range between the current date and X day/month/year(s) from now

**LOG_PATH** Radarr handles errors for the script under `System > Events` and they can log the scripts output when debug is enabled, leaving this blank wont stop the script from printing, it just wont store the information in a log.

### Adding this script to radarr

Once you have saved the script as `scriptname.sh` where scriptname is whatever you want to call it and you've configured the settings.

Go to Radarr `Settings > Connect`, click the plus icon, choose `Custom Script`.

Uncheck everything except `On Mobie Added`, then add the path to the script and Save it. Now it might say `Disabled` right beside `On Movie Added` but this must be a bug as the script works.

### Examples

`MAX_AVAILABILITY="6 month"`, would give us the date range `November 5th 2022 - Fri 05 May 2023`, because today is Nov 5th and 6 months from now is May 5th.

When a movie is added to radarr and it does not meet one of the following requirements.

1. Year is not missing.
2. Release date within **Date Range**
3. Current status is **released**

Then it will automatically be given the tag which was configured under `RADARR_TAG`

When you run this script manually or automatically using cron, then it looks at every movie with the `RADARR_TAG` and rechecks it, if it meets all the requirements then it is untagged and the movies path is updated to ensure the movie folder has the correct information.

So if an unreleased 'tagged' movie looked like this `/data/media/Films/Movies/Avatar - The Way of Water (2023) [tmdb-76600]`

Upon untagging and updatting the path, it would be corrected to this `/data/media/Films/Movies/Avatar - The Way of Water (2022) [tmdb-76600]`
