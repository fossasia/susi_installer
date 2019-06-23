from flask import Flask , render_template , request, flash, redirect, session, abort, g, url_for
from flask import jsonify
import sys
import os
from vlcplayer import vlcplayer

app = Flask(__name__)
f=open("pass.txt", "r")
stored_token = f.readline().splitlines()[0]

def do_return(msg, val):
    dm = {"status": msg}
    resp = jsonify(dm)
    resp.status_code = val
    return resp

@app.before_request
def before_request_callback():
    if request.endpoint != 'login' and request.endpoint != 'login_index' and stored_token!='default' and not session.get('logged_in') and request.remote_addr != '127.0.0.1':
        return redirect('/login_page')

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/login_page')
def login_index():
    return render_template('login.html')

@app.route('/login', methods=['POST', 'PUT'])
def login():
    if request.form['password'] == stored_token:
        session['logged_in'] = True
    else:
        flash('wrong password!')
    return index()

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
@app.route('/volume', methods=['POST', 'PUT'])
def volume_route():
    try:
        vlcplayer.volume(request.args.get('val'))
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


if __name__ == '__main__':
    app.secret_key = os.urandom(12)
    app.run(debug=False, port=7070, host='0.0.0.0')
