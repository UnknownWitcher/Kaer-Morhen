# PMM CONFIGURATIONS

### Folder Structure
**How I organise my assets**
* config/assets/main/films
* config/assets/main/shows
* config/assets/anime/films
* config/assets/anime/shows
* config/assets/kids/films
* config/assets/kids/shows
* config/assets/collections

```
Example:
* config/assets/main/films/2 Fast 2 Furious (2003) [tmdb-584]/poster.jpg
* config/assets/main/films/2 Fast 2 Furious (2003) [tmdb-584]/background.jpg
* config/assets/collections/Arrowverse_poster.jpg
* config/assets/collections/Arrowverse_bg.jpg
```
**How I organise my metadata**
* /config/Metadata/\<library name\>
```
Example:
config/Metadata/films
config/Metadata/shows
config/Metadata/anime films
config/Metadata/kids tv
```
I want to future proof this as much as possible so right now all images are local but I am considering adding every image to github or an alternative other than local. My main concern is relying on something like posterdb or imgur and the images being removed 2+ years from now.
