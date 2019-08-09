""" VLC Player module """

import os
import logging
import time
import random

from sclib import SoundcloudAPI, Track
import pafy
import vlc

# disable hwmixer and hope that crashes disappear
#from hwmixer import mixer
import urllib.parse
import requests
import xml

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

logger = logging.getLogger(__name__)

class VlcPlayer():

    def __init__(self):
        self.saved_softvolume = -1
        # self.saved_hardvolume = -1
        self.saved_hardvolume = 100
        self.instance = vlc.Instance("--no-video")
        self.player = self.instance.media_player_new()
        self.sayplayer = self.instance.media_player_new()
        self.list_player =  self.instance.media_list_player_new()
        self.list_player.set_media_player(self.player)
        self.sc_api = SoundcloudAPI()

    def playytb(self, vid):
        self.play(vid2youtubeMRL(vid))
    
    def playytbLink(self, link):
        self.play(link2youtubeMRL(link))

    def playscloud(self, identifier):
        #Url of the format: https://soundcloud.com/aries_ix/sayonara
        url = "https://souncloud.com" + identifier
        track = self.sc_api.resolve(url)
        try:
            assert type(track) is Track
        except AssertionError as error:
            logger.debug(error)
        
        filename = os.path.join(os.path.dirname(os.path.realpath(__file__)),"download.mp3")
        with open(filename, "wb+") as fp:
            track.write_mp3_to(fp)
        self.play(filename)

    def play(self, mrl_string):
        self.mrl = mrl_string.split(";")
        media_list = self.instance.media_list_new(self.mrl)
        self.list_player.set_media_list(media_list)
        self.list_player.play()
        self.softvolume(100, self.player)

    def playtunein(self, query_name):
        base_url = "http://opml.radiotime.com/Search.ashx?query=" + \
            urllib.parse.urlencode(query_name)
        resp = requests.get(base_url)
        resp_list = xml.dom.minidom.parse(resp)
        resp_list = resp_list.getElementsByTagName("outline")
        if not resp_list:
            return
        
        playing_mrl = resp_list[0].getAttribute("URL")
        self.play(playing_mrl)
        # playing_mrl = requests.get(playing_url)


    def next(self):
        if self.is_playing():
            self.list_player.next()

    def previous(self):
        if self.is_playing():
            self.list_player.previous()

    def restart(self):
        if self.is_playing():
            self.list_player.previous()
            time.sleep(0.01)
            self.list_player.next()

    def shuffle(self):
        if self.is_playing():
            self.list_player.stop()
            random.shuffle(self.mrl)
            media_list = self.instance.media_list_new(self.mrl)
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
        playing = set([vlc.State.Playing, vlc.State.Buffering, vlc.State.Opening])
        # wait some time to give vlc a chance to start up
        time.sleep(0.3)
        time_left = True
        while time_left == True:
            pstate = pl.get_state()
            if pstate not in playing:
                time_left = False
            # print("Sleeping for audio output")
            time.sleep(0.1)

    def is_playing(self):
        return self.list_player.is_playing()

    def beep(self, mrl):
        self.save_softvolume()
        self.say(mrl, False)

    def say(self, mrl, wait_restore = True):
        self.save_softvolume()
        if (self.list_player.is_playing()):
            # reduce volume to 20% of the current volume
            self.softvolume(int(0.2 * self.saved_softvolume), self.player)
            time.sleep(0.2)
        # play additional stream via sayplayer
        media = self.instance.media_new(mrl)
        self.sayplayer.set_media(media)
        self.sayplayer.play()
        if self.saved_softvolume > 0:
            self.softvolume(self.saved_softvolume, self.sayplayer)
        else:
            self.softvolume(100, self.sayplayer)
        if wait_restore:
            self.wait_till_end(self.sayplayer)
            self.restore_softvolume()

    def volume(self, val):
        # return mixer.volume(val)
        return (self.saved_hardvolume)

    def softvolume(self, val, pl):
        if (val is None):
            # absvol = mixer.volume(None)
            absvol = self.saved_hardvolume
            sf = pl.audio_get_volume()
            # sometimes the softvolume is bigger than 100 while hw volume is 100, catch that
            return min( 100, int(sf * 100 / absvol) )
        elif ((isinstance(val, int) or val.isdigit()) and (int(val) <= 100) and (int(val) >= 0)):
            p = int(val)
            # absvol = mixer.volume(None)
            absvol = self.saved_hardvolume
            softvol = min(absvol, round(absvol * p / 100))
            pl.audio_set_volume(softvol)
            return(softvol)
        else:
            raise Exception('Invalid argument to softvolume: ' + str(val))

    def save_softvolume(self):
        self.saved_softvolume = self.softvolume(None, self.player)
        return self.saved_softvolume

    def restore_softvolume(self):
        if (self.saved_softvolume >= 0):
            self.softvolume(self.saved_softvolume, self.player)
        return self.saved_softvolume

    def save_hardvolume(self):
        # self.saved_hardvolume = mixer.volume(None)
        return self.saved_hardvolume

    def restore_hardvolume(self):
        #if (self.saved_hardvolume >= 0):
        #    mixer.volume(self.saved_hardvolume)
        return self.saved_hardvolume

    

def vid2youtubeMRL(vid):
    url = 'https://www.youtube.com/watch?v=' + vid
    video = pafy.new(url)
    best = video.getbestaudio()
    return best.url

def link2youtubeMRL(url):
    video = pafy.new(url)
    best = video.getbestaudio()
    return best.url


vlcplayer = VlcPlayer()
