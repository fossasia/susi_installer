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
plugged_device_name = os.path.basename(device)
plugged_device_name_len = len(plugged_device_name)
media_daemon_folder = os.path.dirname(os.path.abspath(__file__))
base_folder = os.path.dirname(os.path.dirname(os.path.dirname(media_daemon_folder)))
server_skill_folder = os.path.join(base_folder, 'susi_server/data/generic_skills/media_discovery')
server_settings_folder = os.path.join(base_folder, 'susi_server/data/settings')
server_restart_script = os.path.join(base_folder, 'susi_server/bin/restart.sh')

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
    mount_devices = list_media_partitions(device)
    if len(partitions) == 0:
        # try full disk without partition
        mount_devices = [ device ]
    for dev in mount_devices:
        subprocess.call(['udisksctl', 'mount', '-b', dev])  #nosec #pylint-disable type: ignore
    # get mount points
    mntfs = []
    for part in psutil.disk_partitions():
        if part.device in mount_devices:
            mntfs.append((part.device, part.mountpoint, part.fstype))
    # from here TODO!!!


    name_of_usb = get_mount_points()
    usb = name_of_usb[1]
    mp3_files = glob(str(usb) + '/*.mp3')
    ogg_files = glob(str(usb) + '/*.ogg')
    flac_files = glob(str(usb) + '/*.flac')
    wav_files = glob(str(usb) + '/*.wav')
    f = open( media_daemon_folder +'/custom_skill.txt','w')
    music_path = list()
    for mp in mp3_files:
        music_path.append("{}".format(usb) + "/{}".format(mp))
    for ogg in ogg_files:
        music_path.append("{}".format(usb) + "/{}".format(ogg))
    for flac in flac_files:
        music_path.append("{}".format(usb) + "/{}".format(flac))
    for wav in wav_files:
        music_path.append("{}".format(usb) + "/{}".format(wav))
    song_list = " ".join(music_path)
    skills = ['play audio','!console:Playing audio from your usb device','{"actions":[','{"type":"audio_play", "identifier_type":"url", "identifier":"file://'+str(song_list) +'"}',']}','eol']
    for skill in skills:
        f.write(skill + '\n')
    f.close()
    shutil.move(os.path.join(media_daemon_folder, 'custom_skill.txt'), server_skill_folder)
    with open(os.path.join(server_settings_folder, 'customized_config.properties'), 'a') as f2:
        f2.write('local.mode = true')
    subprocess.call(['sudo', 'bash', server_restart_script])  #nosec #pylint-disable type: ignore

def get_usb_devices():
    sdb_devices = map(os.path.realpath, glob('/sys/block/sd*'))
    usb_devices = (dev for dev in sdb_devices
        if 'usb' in dev.split('/')[5])
    return dict((os.path.basename(dev), dev) for dev in usb_devices)

def get_mount_points(devices=None):
    devices = devices or get_usb_devices() # if devices are None: get_usb_devices
    output = subprocess.check_output(['mount']).splitlines() #nosec #pylint-disable type: ignore
    output = [tmp.decode('UTF-8') for tmp in output ] # pytlint-enable
    def is_usb(path):
        return any(dev in path for dev in devices)
    usb_info = (line for line in output if is_usb(line.split()[0]))
    return [(info.split()[0], info.split()[2]) for info in usb_info]

if __name__ == '__main__':
    make_skill()
