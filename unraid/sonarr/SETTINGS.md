## Media Management

### Episode Naming

**Replace Illegal Characters:** ✔️

**Colon Replacement:** `Smart Replace`

**Standard Episode Format:** 
```
{Series TitleYear} - S{season:00}E{episode:00} - {Episode CleanTitle} [{Preferred Words }{Quality Full}]{[MediaInfo VideoDynamicRange]}[{MediaInfo VideoBitDepth}bit]{[MediaInfo VideoCodec]}{[Mediainfo AudioCodec}{ Mediainfo AudioChannels]}{MediaInfo AudioLanguages}{-Release Group}
```

**Daily Episode Format:**

```
{Series TitleYear} - {Air-Date} - {Episode CleanTitle} [{Preferred Words }{Quality Full}]{[MediaInfo VideoDynamicRange]}[{MediaInfo VideoBitDepth}bit]{[MediaInfo VideoCodec]}{[Mediainfo AudioCodec}{ Mediainfo AudioChannels]}{MediaInfo AudioLanguages}{-Release Group}
```

**Anime Episode Format:** ℹ️ *This will be used in a different instance.*
```
{Series TitleYear} - S{season:00}E{episode:00} - {absolute:000} - {Episode CleanTitle} [{Preferred Words }{Quality Full}]{[MediaInfo VideoDynamicRange]}[{MediaInfo VideoBitDepth}bit]{[MediaInfo VideoCodec]}[{Mediainfo AudioCodec} { Mediainfo AudioChannels}]{MediaInfo AudioLanguages}{-Release Group}
```

**Series Folder Format:** *(advanced)*
```
{Series TitleYear} {tvdb-{TvdbId}}
```

**Season Folder Format:**
```
Season {season:00}
```
**Specials Folder Format:** *(advanced)*
```
Specials
```
**Multi Episode Style:** `Prefixed Range`

### Folders
**Create Empty Series Folders:** ❌

**Delete Empty Folders:** ❌

### Importing
**Episode Title Required:** *(advanced)* `Only for Bulk Season Releases`

**Skip Free Space Check:** *(advanced)* ❌

**Minimum Free Space:** *(advanced)* `50000` ℹ️ *50GB free storage should be enough for my use case*

**Use Hardlinks instead of Copy:** *(advanced)* ✔️

**Import Using Script:** *(advanced)* ❌ ℹ️ *will be testing and potentially using this in the future.*

**Import Extra Files:** ✔️

**Import Extra Files:** *(advanced)* `srt,ass,ssa`

### File Management

**Unmonitor Deleted Episodes:** ✔️ 

**Propers and Repacks:** `Do not Prefer` ℹ️ *Letting this upgrade has caused mw problems in the past.*

**Analyse video files:** *(advanced)* ✔️ ℹ️ *I normally have this unchecked when using cloud storage.*

**Rescan Series Folder after Refresh:** *(advanced)* `Always`

**Change File Date:** *(advanced)* `Local Air Date`

**Recycling Bin:** *(advanced)* `empty`

**Recycling Bin Cleanup:** *(advanced)* `7`

### Permissions

**Set Permissions:** *(advanced)* ✔️

**chmod Folder:** *(advanced)*  `755`

**chown Group:** *(advanced)* `empty`

**Root Folders**
- /tv/anime ℹ️ This will be used in a different instance.
- /tv/foreign
- /tv/kids
- /tv/shows
