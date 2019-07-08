import sys
import os
import subprocess

import logging

from flask import Flask , render_template , request, flash, redirect, session, abort, g, url_for
from flask import jsonify
from werkzeug.security import generate_password_hash, check_password_hash

from vlcplayer import vlcplayer

app = Flask(__name__)
logger = logging.getLogger(__name__)

logger = logging.getLogger(__name__)
dir_path = os.path.dirname(os.path.realpath(__file__))
mountPath = os.path.join('/media',os.getlogin())


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

@app.route('/control')
def index():
    return render_template('index.html')

@app.route('/login', methods=['POST', 'PUT'])
def login():
    if check_pass(request.form['password']):
        session['logged_in'] = True
    else:
        flash('wrong password!')
    return redirect(url_for('index'))

@app.route('/set_password', methods=['GET', 'POST'])
def set_password():
    if request.method == 'POST':
        write_pass(request.form['password'])
        return redirect(url_for('index'))
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

if __name__ == '__main__':
    app.secret_key = os.urandom(12)
    app.run(debug=False, port=7070, host='0.0.0.0')
