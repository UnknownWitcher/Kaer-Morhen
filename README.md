# Kaer-Morhen

>I had plans to store a variety of scripts that either I use or created for others to use
>but ended up not using my repo for a long time. I'm now moving to unraid and will need a
>new scripts for my arrs and a few other things. Even though odds are noone will ever see or
>use the things I share, they will however be a backup for me.

**FUTURE PLANS?**
##### Try to imrpove Autoscan.
  > The current autoscan I use by [Cloudbox/autoscan](https://github.com/Cloudbox/autoscan) is really useful and even though I'm moving away from cloud storage I do plan to continue using autoscan, however its major downside is the fact that it crashes if the media server is not online, which is an issue if autoscan starts before your media server or if your media server goes down temporarily.
  >
  > It might be easier to create a script that stores the scan requests into the database and bypasses autoscan entirely, meaning that even if it crashes the requests would still be sent to the database and autoscan can then handle those requests once it restarts, on top of this a script might be needed to check if it's offline and then check to see if the media server(s) are also offline.
  >
  > The other solution would be to build my own autoscan, give it the same features as their app and figure out a clean way to avoid
  > it from shutting down, my current idea would be to simply have an interval increase with the retries decreasing, so something like..
  > - 12 Retries - 5 minute intervals (60 minute)
  > - 06 Retries - 20 minute intervals (120 minute)
  > - 03 Retries - 60 minute intervals (180 minutes)
  > - 02 Retries - 120 minute intervals (240 minutes)
  > - 01 Retry   - 300 minute intervals (300 minutes)
  >   
  > Repeat..
  >
  > Assuming the media server isn't going to be down for an entire day/week, then this wouldn't be a huge issue and the database shouldn't
  > get too big with scan requests, which I believe is the reason why the cloudbox devs prefer autoscan to simply shutdown when one of the
  > media servers is offline.
  > 
  > Main issue with me doing this is that I don't know golang, although it could be a good learning experience, or I can just use python lol.
##### Fully automated tdarr setup with ARRs
  > With tdarrs' new flow feature, I believe it is now possible to fully automate every possible scenario that we may encounter when handling
  > media files, this wasn't possible with the old plugin method.
  >
  > **Process**
  > - Radarr|Sonarr - Downloads Remux
  >   - Tdarr - Processes it based on what it is (remux \> anime, movie, tv)
  >     - Radarr|Sonarr - Notified to rename file
  >       - Request Sent to Autoscan
  >         - Plex Scans File
  >
  > In general each Tdarr Flow will be designed to handle
  > - Every audio stream from 1 to 8 channel expected from dvd (remux)/bluray (remux)/web
  > - Every subtitle stream SRT/ASS/PGS - I would like a way to automatically convert PGS to SRT..
  > - Every video stream - I want to preserve HDR and encode everything to h265, although I want to use AV1 but it's not possible for me right now.
  > 
  > With regards to audio and subtitles, I would like a way to detect the language if the language metadata isn't available,
  > closest I can do by script is to check the title but a way to sample the audio and figure out the language would be awesome to do in the future.
##### Home Automations
  > I finally have a RaspPi so I might include scripts and general setup here as well as I want to get into home automation.
##### Secret Projects - I don't know if I'll share these as it could ruin a good thing.
