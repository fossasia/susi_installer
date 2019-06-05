import os
import sys
from glob import glob
import shutil
import subprocess #nosec #pylint-disable type: ignore
import psutil

# To get media_daemon folder
if len(sys.argv) <= 1:
    raise Exception('Missing argument')

plugged_device = sys.argv[1]
plugged_device_name = os.path.basename(plugged_device)
plugged_device_name_len = len(plugged_device_name)
media_daemon_folder = os.path.dirname(os.path.abspath(__file__))
base_folder = os.path.dirname(os.path.dirname(os.path.dirname(media_daemon_folder)))
server_skill_folder = os.path.join(base_folder, 'susi_server/data/generic_skills/media_discovery')
server_settings_folder = os.path.join(base_folder, 'susi_server/data/settings')

def list_media_partitions():
    with open("/proc/partitions", "r") as f:
        partitions = []
        for line in f.readlines()[2:]:  # skip header lines
            words = [ word.strip() for word in line.split() ]
            minor_number = int(words[1])
            device_name = words[3]
            if device_name[0:plugged_device_name_len] == plugged_device_name:
                if not (minor_number % 16) == 0:
                    # only partitions have minor number 17, 18, ...
                    path = "/sys/class/block/" + device_name
                    if os.path.islink(path):
                        if os.path.realpath(path).find("/usb") > 0:
                            partitions.append("/dev/" + device_name)
        return partitions

def make_skill(): # pylint-enable
    partitions = list_media_partitions()
    if len(partitions) == 0:
        # try full disk without partition
        mount_devices = [ plugged_device ]
    for dev in partitions:
        subprocess.call(['udisksctl', 'mount', '-o', 'ro', '-b', dev])  #nosec #pylint-disable type: ignore
    # get mount points
    mntpts = []
    for part in psutil.disk_partitions():
        if part.device in partitions:
            mntpts.append(part.mountpoint)
    mp3_files = []
    ogg_files = []
    flac_files = []
    wav_files = []
    for mntpt in mntpts:
        mp3_files += glob(mntpt + '/**/*.[mM][pP]3', recursive = True)
        ogg_files += glob(mntpt + '/**/*.[oO]gg', recursive = True)
        flac_files += glob(mntpt + '/**/*.flac', recursive = True)
        wav_files += glob(mntpt + '/**/*.wav', recursive = True)
    f = open( media_daemon_folder +'/custom_skill.txt','w')
    music_path = list()
    for mp in mp3_files:
        music_path.append("{}".format(mp))
    for ogg in ogg_files:
        music_path.append("{}".format(ogg))
    for flac in flac_files:
        music_path.append("{}".format(flac))
    for wav in wav_files:
        music_path.append("{}".format(wav))
    song_list = " ".join( map ( lambda x: "file://" + x, music_path ) )
    # TODO format of the skill looks strange!!!
    skills = ['play audio','!console:Playing audio from your usb device','{"actions":[','{"type":"audio_play", "identifier_type":"url", "identifier":"' + str(song_list) +'"}',']}','eol']
    for skill in skills:
        f.write(skill + '\n')
    f.close()
    shutil.move(os.path.join(media_daemon_folder, 'custom_skill.txt'), server_skill_folder)
    with open(os.path.join(server_settings_folder, 'customized_config.properties'), 'a') as f2:
        f2.write('local.mode = true')
    subprocess.call(['sudo', 'systemctl', 'restart', 'ss-susi-server'])  #nosec #pylint-disable type: ignore

if __name__ == '__main__':
    make_skill()
