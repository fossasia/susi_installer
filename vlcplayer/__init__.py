""" VLC Player module """

import vlc
import pafy
import time



class VlcPlayer():

    saved_volume = -1

    def __init__(self):
        self.instance = vlc.Instance("--no-video")
        self.player = self.instance.media_player_new()
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

    def pause(self):
        if self.is_playing():
            self.list_player.pause()

    def resume(self):
        # pause works like a button, thus doing both pause and resume
        if not self.is_playing():
            self.list_player.pause()

    def stop(self):
        self.list_player.stop()

    def wait_till_end(self):
        playing = set([vlc.State.Playing, vlc.State.Buffering])
        time_left = True
        while time_left == True:
            pstate = self.list_player.get_state()
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
            curvol = self.volume(None)
            self.volume(20)
            time.sleep(0.2)
        # create a temporary player to say something, then continue to play
        tmpPlayer = VlcPlayer()
        if (curvol > 0):
            tmpPlayer.volume(curvol)
        else:
            # if we don't have any volume available, use a default of 50
            tmpPlayer.volume(50)
        tmpPlayer.play(mrl)
        if wait_restore:
            tmpPlayer.wait_till_end()
            if (curvol >= 0):
                self.volume(curvol)

    def volume(self, val):
        if (val is None):
            return self.player.audio_get_volume()
        elif (val == 'up'):
            perc = self.player.audio_get_volume()
            newperc = min(100, perc + 10)
            self.player.audio_set_volume(newperc)
        elif (val == 'dn'):
            perc = self.player.audio_get_volume()
            newperc = max(0, perc - 10)
            self.player.audio_set_volume(newperc)
        elif ((isinstance(val, int) or val.isdigit()) and (int(val) <= 100) and (int(val) >= 0)):
            self.player.audio_set_volume(int(val))
        else:
            raise Exception('Unknown volume control')

    def save_volume(self):
        self.saved_volume = self.player.audio_get_volume()

    def restore_volume(self):
        if (self.saved_volume > 0):
            self.player.audio_set_volume(self.saved_volume)

def vid2youtubeMRL(vid):
    url = 'https://www.youtube.com/watch?v=' + vid
    video = pafy.new(url)
    best = video.getbestaudio()
    return best.url


            
vlcplayer = VlcPlayer()
