import sys
import os
import subprocess

import logging
import json_config

from flask import Flask , render_template , request, flash, redirect, session, abort, g, url_for
from flask import jsonify
from werkzeug.security import generate_password_hash, check_password_hash

from vlcplayer import vlcplayer

app = Flask(__name__)
logger = logging.getLogger(__name__)

logger = logging.getLogger(__name__)
dir_path = os.path.dirname(os.path.realpath(__file__))
mountPath = '/media'

wifi_search_folder = os.path.join(dir_path, '../access_point')
susiconfig = '/home/pi/SUSI.AI/bin/susi-config'


def do_return(msg, val):
    dm = {"status": msg}
    resp = jsonify(dm)
    resp.status_code = val
    return resp

def check_pass(passw=''):
    f=open(dir_path+'/pass.txt', "r")
    get_pass = f.readline().splitlines()[0]
    if (passw=='' and get_pass=='default') or (check_password_hash(get_pass,passw)):
        return True
    else:
        return False

def write_pass(passw):
    fw=open(dir_path+"/pass.txt","w+")
    fw.write(str(generate_password_hash(passw)))
    session['logged_in'] = False

@app.before_request
def before_request_callback():
    if request.endpoint != 'login' and request.endpoint != 'static' and not\
       check_pass() and not session.get('logged_in') and request.remote_addr != '127.0.0.1':
        return render_template('login.html')

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/control')
def control():
    return render_template('control.html')

@app.route('/setup')
def setup():
    return render_template('setup.html')

@app.route('/login', methods=['POST', 'PUT'])
def setlogin():
    if check_pass(request.form['password']):
        session['logged_in'] = True
    else:
        flash('wrong password!')
    return redirect(url_for('control'))

@app.route('/set_password', methods=['GET', 'POST'])
def set_password():
    if request.method == 'POST':
        write_pass(request.form['password'])
        return redirect(url_for('control'))
    return render_template('password.html')

@app.route('/status', methods=['POST', 'PUT'])
def status_route():
    return do_return('Ok', 200)

# /play?ytb=???
# /play?mrl=???
@app.route('/play', methods=['POST', 'PUT'])
def play_route():
    if 'ytb' in request.args:
        vlcplayer.playytb(request.args.get('ytb'))
        return do_return('Ok', 200)
    elif 'mrl' in request.args:
        vlcplayer.play(request.args.get('mrl'))
        return do_return('Ok', 200)
    else:
        return do_return('Unknown play mode', 400)

# /volume?val=up
# /volume?val=down
# /volume?val=NN  0 <= NN <= 100
@app.route('/volume/<val>', methods=['POST', 'PUT'])
def volume_route(val):
    try:
        vlcplayer.volume(val)
        return do_return('Ok', 200)
    except Exception as e:
        logger.error(e)
        return do_return('Volume adjustment error' + e, 400)

# /say?mrl=???
@app.route('/say', methods=['POST', 'PUT'])
def say_route():
    if 'mrl' in request.args:
        vlcplayer.say(request.args.get('mrl'))
        return do_return('Ok', 200)
    else:
        return do_return('Missing mrl argument', 400)


@app.route('/beep', methods=['POST', 'PUT'])
def beep_route():
    if 'mrl' in request.args:
        vlcplayer.beep(request.args.get('mrl'))
        return do_return('Ok', 200)
    else:
        return do_return('Missing mrl argument', 400)


# /pause
# /resume
# /stop
@app.route('/pause', methods=['POST', 'PUT'])
def pause_route():
    vlcplayer.pause()
    return do_return('Ok', 200)

@app.route('/resume', methods=['POST', 'PUT'])
def resume_route():
    vlcplayer.resume()
    return do_return('Ok', 200)

@app.route('/stop', methods=['POST', 'PUT'])
def stop_route():
    vlcplayer.stop()
    return do_return('Ok', 200)

@app.route('/next', methods=['POST', 'PUT'])
def next_route():
    vlcplayer.next()
    return do_return('Ok', 200)

@app.route('/previous', methods=['POST', 'PUT'])
def previous_route():
    vlcplayer.previous()
    return do_return('Ok', 200)

@app.route('/restart', methods=['POST', 'PUT'])
def restart_route():
    vlcplayer.restart()
    return do_return('Ok', 200)

@app.route('/shuffle', methods=['POST', 'PUT'])
def shuffle_route():
    vlcplayer.shuffle()
    return do_return('Ok', 200)

@app.route('/save_softvolume', methods=['POST', 'PUT'])
def save_softvolume_route():
    vlcplayer.save_softvolume()
    return do_return('Ok', 200)

@app.route('/restore_softvolume', methods=['POST', 'PUT'])
def restore_softvolume_route():
    vlcplayer.restore_softvolume()
    return do_return('Ok', 200)

@app.route('/save_hardvolume', methods=['POST', 'PUT'])
def save_hardvolume_route():
    vlcplayer.save_hardvolume()
    return do_return('Ok', 200)

@app.route('/restore_hardvolume', methods=['POST', 'PUT'])
def restore_hardvolume_route():
    vlcplayer.restore_hardvolume()
    return do_return('Ok', 200)

# @app.route('/reset_smart_speaker/<type>', methods=['POST','PUT'])
# def reset_smart_speaker(type):
#     current_folder = os.path.dirname(os.path.abspath(__file__))
#     wap_script = os.path.abspath(current_folder + '/../access_point/wap.sh')
#     factory_reset = os.path.abspath(current_folder + '/../factory_reset/factory_reset.sh')
#     if type == 'hard' :
#         logger.info("hard FACTORY RESET")
#         logger.info("hard factory reset initiated")
#         subprocess.Popen(['sudo','bash', factory_reset, 'hard'])
#     elif type == 'soft' :
#         logger.info("soft FACTORY RESET")
#         logger.info("soft factory reset initiated")
#         subprocess.Popen(['sudo','bash', factory_reset, 'soft'])
#     elif type == 'AP' :
#         logger.info("switch to access point mode")
#         logger.info("switch to access mode initiated")
#         subprocess.Popen(['sudo','bash', wap_script])
#     return do_return('Ok', 200)

@app.route('/getdevice', methods=['GET'])
def get_mounted_device():
    folders = os.listdir(mountPath)
    devices = [{'name': d} for d in folders]

    return do_return(devices, 200)

@app.route('/getOfflineSong/<folder>', methods=['GET'])
def get_offline_song(folder):
    files = os.listdir(os.path.join(mountPath,folder))
    songs = [{'name': i} for i in files if i.endswith('.mp3') or i.endswith('.m4a') or i.endswith('.ogg') ]
    return do_return(songs, 200)

@app.route('/playOfflineSong/<folder>/<file>', methods=['PUT'])
def play_offine_song(folder, file):
    vlcplayer.stop()
    vlcplayer.play(os.path.join(mountPath, folder, file))
    return do_return('OK', 200)

@app.route('/playyoutube', methods=['PATCH'])
def play_from_youtubeLink():
    data = request.json
    vlcplayer.playytbLink(data['link'])
    return do_return('OK', 200)

@app.route('/install')
def install():
    return 'starting the installation script'

@app.route('/config', methods=['GET'])
def config():
    stt = request.args.get('stt')
    tts = request.args.get('tts')
    hotword = request.args.get('hotword')
    wake = request.args.get('wake')
    subprocess.Popen(['sudo', '-u', 'pi', susiconfig, 'set', "stt="+stt, "tts="+tts, "hotword="+hotword, "wakebutton="+wake])  #nosec #pylint-disable type: ignore
    # TODO we should check the actual return code of susi-linux-config-generator
    display_message = {"configuration":"successful", "stt": stt, "tts": tts, "hotword": hotword, "wake":wake}
    resp = jsonify(display_message)
    resp.status_code = 200
    subprocess.Popen(['sudo','bash', os.path.join(wifi_search_folder,'rwap.sh')])
    return resp # pylint-enable

@app.route('/auth', methods=['GET'])
def login():
    auth = request.args.get('auth')
    email = request.args.get('email')
    password = request.args.get('password')
    subprocess.call(['sudo', '-u', 'pi', susiconfig, 'set', "susi.mode="+auth, "susi.user="+email, "susi.pass="+password]) #nosec #pylint-disable type: ignore
    display_message = {"authentication":"successful", "auth": auth, "email": email, "password": password}
    if auth == 'authenticated' and email != "":
        os.system('sudo systemctl enable ss-susi-register.service')
    resp = jsonify(display_message)
    resp.status_code = 200
    return resp # pylint-enable

@app.route('/wifi_credentials', methods=['GET'])
def wifi_config():
    wifi_ssid = request.args.get('wifissid')
    wifi_password = request.args.get('wifipassd')
    subprocess.call(['sudo', 'bash', wifi_search_folder + '/wifi_search.sh', wifi_ssid, wifi_password])  #nosec #pylint-disable type: ignore
    display_message = {"wifi":"configured", "wifi_ssid":wifi_ssid, "wifi_password": wifi_password}
    resp = jsonify(display_message)
    resp.status_code = 200
    return resp  # pylint-enable

@app.route('/speaker_config', methods=['GET'])
def speaker_config():
    room_name = request.args.get('room_name')
    subprocess.call(['sudo', '-u', 'pi', susiconfig, 'set', 'roomname="'+room_name+'"']) #nosec #pylint-disable type: ignore
    display_message = {"room_name":room_name}
    resp = jsonify(display_message)
    resp.status_code = 200
    return resp

# the reboot service combines all other services in one call
# the current version allows anonymous operation mode
# todo: the front-end should provide an option for this

@app.route('/reboot', methods=['POST'])
def reboot():
    # speaker_config
    room_name = request.form['room_name']
    subprocess.call(['sudo', '-u', 'pi', susiconfig, 'set', 'roomname="'+room_name+'"']) #nosec #pylint-disable type: ignore

    # wifi_credentials
    wifi_ssid = request.form['wifissid']
    wifi_password = request.form['wifipassd']
    subprocess.call(['sudo', 'bash', wifi_search_folder + '/wifi_search.sh', wifi_ssid, wifi_password])  #nosec #pylint-disable type: ignore

    # auth
    auth = request.form['auth']
    email = request.form['email']
    password = request.form['password']

    subprocess.call(['sudo', '-u', 'pi', susiconfig, 'set', "susi.mode="+auth, "susi.user="+email, "susi.pass="+password])
    if auth == 'authenticated' and email != "":
        os.system('sudo systemctl enable ss-susi-register.service')

    # config
    stt = request.form['stt']
    tts = request.form['tts']
    hotword = request.form['hotword']
    wake = request.form['wake']
    subprocess.Popen(['sudo', '-u', 'pi', susiconfig, 'set', "stt="+stt, "tts="+tts, "hotword="+hotword, "wakebutton="+wake])  #nosec #pylint-disable type: ignore
    display_message = {"wifi":"configured", "room_name":room_name, "wifi_ssid":wifi_ssid, "auth":auth, "email":email, "stt":stt, "tts":tts, "hotword":hotword, "wake":wake, "message":"SUSI is rebooting"}
    resp = jsonify(display_message)
    resp.status_code = 200
    subprocess.Popen(['sudo','bash', os.path.join(wifi_search_folder,'rwap.sh')])
    return resp  # pylint-enable

if __name__ == '__main__':
    app.secret_key = os.urandom(12)
    app.run(debug=False, port=7070, host='0.0.0.0')
