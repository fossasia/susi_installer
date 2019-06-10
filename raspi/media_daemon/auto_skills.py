import os
import sys
from glob import glob
import shutil
import syslog
import eyed3

# To get media_daemon folder
if len(sys.argv) <= 1:
    raise Exception('Missing argument')

mntpt = sys.argv[1]
media_daemon_folder = os.path.dirname(os.path.abspath(__file__))
base_folder = os.path.dirname(os.path.dirname(os.path.dirname(media_daemon_folder)))
server_skill_folder = os.path.join(base_folder, 'susi_server/data/generic_skills/media_discovery')

def make_skill(): # pylint-enable
    syslog.syslog("Generating audio skills for USB drive at " + mntpt)
    mp3_files = glob(mntpt + '/**/*.[mM][pP]3', recursive = True)
    ogg_files = glob(mntpt + '/**/*.[oO]gg', recursive = True)
    flac_files = glob(mntpt + '/**/*.flac', recursive = True)
    wav_files = glob(mntpt + '/**/*.wav', recursive = True)
    f = open( base_folder + '/susi_installer/raspi/media_daemon/custom_skill.txt', 'w')
    music_path = list()
    artists={}
    for mp in mp3_files[:]:
        music_path.append("{}".format(mp))
        audiofile = eyed3.load(mp)
        artists.setdefault(audiofile.tag.artist, []).append(mp)
    for ogg in ogg_files:
        music_path.append("{}".format(ogg))
    for flac in flac_files:
        music_path.append("{}".format(flac))
    for wav in wav_files:
        music_path.append("{}".format(wav))
    # we choose ; as separation char since this seems not to be used in
    # any normal file system path naming
    song_list = ";".join( map ( lambda x: "file://" + x, music_path ) )
    skills = ['play audio','!console:Playing audio from your usb device','{"actions":[','{"type":"audio_play", "identifier_type":"url", "identifier":"' + str(song_list) +'"}',']}','eol']
    for skill in skills:
        f.write(skill + '\n')
    f.write("\n")

    for artist_name in artists:
        song_list = ";".join( map ( lambda x: "file://" + x, artists[artist_name] ) )
        skills_artist = ['play '+ artist_name +' from usb','!console:Playing audio from your usb device','{"actions":[','{"type":"audio_play", "identifier_type":"url", "identifier":"' + str(song_list) +'"}',']}','eol']
        for skill in skills_artist:
            f.write(skill + '\n')
        f.write("\n")
    f.close()

    shutil.move(os.path.join(media_daemon_folder, 'custom_skill.txt'), os.path.join(server_skill_folder, 'custom_skill.txt'))
    syslog.syslog("Added skills based on " + str(len(music_path)) + " songs from " + mntpt)

if __name__ == '__main__':
    make_skill()
