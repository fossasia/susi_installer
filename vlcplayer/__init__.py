""" VLC Player module """

import vlc
import pafy
import time
from hwmixer import mixer

#
# we have two mixers available
# - software mixer via python-vlc
# - hardware mixer via hwmixer/mixer which controls Master only
# The total audio output is the product of the two (by 100*100)
# BUT
# if one adjusts sets the volume via python_vlc && the master is less than
# the desired output, then BOTH software and master is adusted to the new
# desired output!
# Similarily, if one changes the HW mixer, the values of the software mixer
# are scaled down!
#
# When starting, the *last* volume of the vlc player is used
#
# Thus we will do the following
# - when starting, adjust the softvolume to be == with hwvolume
# - when silencing, do this as fractional of the hwvolume
# - all values send to volume adjustments of vlc player are
#   fraction between [0, current_master_volume]


class VlcPlayer():

    def __init__(self):
        self.saved_volume = -1
        self.instance = vlc.Instance("--no-video")
        self.player = self.instance.media_player_new()
        self.sayplayer = self.instance.media_player_new()
        self.list_player =  self.instance.media_list_player_new()
        self.list_player.set_media_player(self.player)

    def playytb(self, vid):
        self.play(vid2youtubeMRL(vid))

    def play(self, mrl):
        media = self.instance.media_new(mrl)
        media_list = self.instance.media_list_new([mrl])
        self.player.set_media(media)
        self.list_player.set_media_list(media_list)
        self.list_player.play()
        self.softvolume(100, self.player)

    def pause(self):
        if self.is_playing():
            self.list_player.pause()

    def resume(self):
        # pause works like a button, thus doing both pause and resume
        if not self.is_playing():
            self.list_player.pause()

    def stop(self):
        self.list_player.stop()

    def wait_till_end(self, pl):
        playing = set([vlc.State.Playing, vlc.State.Buffering])
        time_left = True
        while time_left == True:
            pstate = pl.get_state()
            if pstate not in playing:
                time_left = False
            print("Sleeping for audio output")
            time.sleep(0.1)

    def is_playing(self):
        return self.list_player.is_playing()

    def beep(self, mrl):
        self.save_volume()
        self.say(mrl, False)

    def say(self, mrl, wait_restore = True):
        curvol = -1
        if (self.list_player.is_playing()):
            cursoftvol = self.softvolume(None, self.player)
            print("CurVolume = ", cursoftvol)
            # reduce volume to 20% of the current volume
            self.softvolume(int(0.2 * cursoftvol), self.player)
            time.sleep(0.2)
        # play additional stream via sayplayer
        media = self.instance.media_new(mrl)
        self.sayplayer.set_media(media)
        self.sayplayer.play()
        if curvol > 0:
            self.softvolume(cursoftvol, self.sayplayer)
        else:
            self.softvolume(100, self.sayplayer)
        if wait_restore:
            self.wait_till_end(self.sayplayer)
            # readjust volume of the previous music playback
            self.softvolume(cursoftvol, self.player)

    def volume(self, val):
        return mixer.volume(val)

    def softvolume(self, val, pl):
        if (val is None):
            absvol = mixer.volume(None)
            sf = pl.audio_get_volume()
            return int(sf * 100 / absvol)
        elif ((isinstance(val, int) or val.isdigit()) and (int(val) <= 100) and (int(val) >= 0)):
            p = int(val)
            absvol = mixer.volume(None)
            softvol = min(absvol, round(absvol * p / 100))
            pl.audio_set_volume(softvol)
        else:
            raise Exception('Invalid argument to softvolume: ' + str(val))

    def save_volume(self):
        self.saved_volume = mixer.volume(None)

    def restore_volume(self):
        if (self.saved_volume >= 0):
            mixer.volume(self.saved_volume)


def vid2youtubeMRL(vid):
    url = 'https://www.youtube.com/watch?v=' + vid
    video = pafy.new(url)
    best = video.getbestaudio()
    return best.url


            
vlcplayer = VlcPlayer()
