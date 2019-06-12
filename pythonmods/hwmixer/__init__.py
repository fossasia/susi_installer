""" HW Mixer module """

import alsaaudio

class HwMixer():

    saved_volume = -1

    def __init__(self):
        self.mixerid = ''
        for i in alsaaudio.mixers():
            if i == 'Master' or i == 'PCM' or i == 'Speaker':
                self.mixerid = i
        if self.mixerid == '':
            raise Exception('Cannot find mixer')
        self.mixer = alsaaudio.Mixer(control=self.mixerid)

    def svol(self):
        vols = self.mixer.getvolume()
        return int(sum(vols)/len(vols))

    def volume(self, val):
        if (val is None):
            return self.svol()
        elif (val == 'up'):
            self.mixer.setvolume(min(100, self.svol() + 10))
        elif (val == 'dn'):
            self.mixer.setvolume(max(0, self.svol() - 10))
        elif ((isinstance(val, int) or val.isdigit()) and (int(val) <= 100) and (int(val) >= 0)):
            self.mixer.setvolume(int(val))
        else:
            raise Exception('Unknown volume control')

    def save_volume(self):
        self.saved_volume = self.svol()

    def restore_volume(self):
        if (self.saved_volume > 0):
            self.mixer.setvolume(self.saved_volume)

mixer = HwMixer()
