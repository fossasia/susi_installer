## Playing Music on your Smart Speaker

According to the June 2019 build of Susibian - https://github.com/fossasia/susi_installer/releases/tag/release-20190626.0

## Play Online Music

The Smart Speaker currently supports playing music via YouTube. Sound cloud integration is coming soon.

### Play Music From Youtube

Usage : `SUSI, play <name_of_song>`

Example : `SUSI, play Radioactive` or `SUSI, play Imagine Dragons Radioactive`

The user has to say 'play <song_name>' after the hotword 'SUSI' to make SUSI search that song name on YouTube and play it via the Smart Speaker.

## Play Offline Music

SUSI supports playing local music from any USB device connected to the smart speaker. SUSI can either play all songs from the USB device or songs from a specific artist, genre or album.

### Play all music on the USB device

Usage: `Play, Audio`

This will play all audio from the USB device connected to the speaker. SUSI Smart speaker currently supports the following audio formats:
- MP3
- FLAC
- OGG
- WAV

#### Play All Songs From an Artist

Usage : `SUSI, play <artist_name> from USB`\
Example : `SUSI, play Linkin Park from USB`

This will play and queue all songs from the given artist if found on the USB Device.

#### Play a Specific Music Genre

Usage : `SUSI, play <Genre> from USB`\
Example : `SUSI, play Hard Rock from USB`

This will play and queue songs from the USB device that matches the given genre.

#### Play an Album

Usage : `SUSI, play <album_name> from USB`\
Example : `SUSI, play Hybrid Thoery from USB`

This will play and queue songs from a specific Album Name.

**Note**: The above three skills depends on the metadata of the file. The file should have relevant metadata for these skills to work.

### Play Back Control

Usage : `SUSI, <control_keyword>`

Example : `SUSI, pause` or `SUSI, resume`

#### Available Music Playback Control keywords

* **Pause** : Pause the currently playing music

* **Resume** : Resume the currently playing music if paused

* **Restart** : Restart the currently playing Music

* **Next** : Go to the next song in the current playlist.

* **Previous** : Plays the previous song in the current playlist.

* **shuffle** : Shuffles all songs in the current playlist and play again.

**Note** : Playlist is made for offline Music skills such as play audio or play album from USB.
