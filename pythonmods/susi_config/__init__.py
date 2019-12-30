#!/usr/bin/env python3
#
# susi-config
# Konfiguration of SUSI.AI, via the config.json

import sys
import os
import json_config
import requests
from pathlib import Path
from importlib import util


class SusiConfig():
    #
    # susi-config set key=value ...
    # susi-config get key ...
    # susi-config login
    #
    # key value(s)
    # stt google|watson|bing|pocketsphinx
    # tts google|watson|flite
    # watson.stt.user <value>
    # watson.stt.pass <value>
    # watson.tts.user <value>
    # watson.tts.pass <value>
    # bing.api <value>
    # wakebutton enable|disable
    # susi.user <value>
    # susi.pass <value>
    # susi.mode authenticated|anonymous
    # roomname <value>
    # hotword Snowboy|PocketSphinx
    # data_base_dir <value>
    # flite_speech_file_path <value>
    # detection_bell_sound <value>
    # problem_sound <value>
    # recognition_error_sound <value>
    
    keys_conf = {
            'stt': 'default_stt',
            'tts': 'default_tts',
            'watson.stt.user': 'watson_stt_config.username',
            'watson.stt.pass': 'watson_stt_config.password',
            'watson.tts.user': 'watson_tts_config.username',
            'watson.tts.pass': 'watson_tts_config.password',
            'susi.user': 'login_credentials.email',
            'susi.pass': 'login_credentials.password',
            'susi.mode': 'usage_mode',
            'roomname': 'room_name',
            'bing.api': 'bing_speech_api_key',
            'wakebutton': 'WakeButton',
            'hotword': 'hotword_engine',
            'data_base_dir': 'data_base_dir',
            'flite_speech_file_path': 'flite_speech_file_path',
            'detection_bell_sound': 'detection_bell_sound',
            'problem_sound': 'problem_sound',
            'recognition_error_sound': 'recognition_error_sound',
            'device': 'Device'
        }
    

    def __init__(self, working_dir):
        # TODO check for existing file?
        self.config = json_config.connect(working_dir + '/config.json')
        self.config.setdefault('data_base_dir', working_dir + '/susi_linux')
        self.config.setdefault('flite_speech_file_path', 'extras/cmu_us_slt.flitevox')
        self.config.setdefault('detection_bell_sound', 'extras/detection-bell.wav')
        self.config.setdefault('problem_sound', 'extras/problem.wav')
        self.config.setdefault('recognition_error_sound', 'extras/recognition-error.wav')

    def setup_wake_button(self, enable = False):
        try:
            import RPi.GPIO
            print("\nDevice supports RPi.GPIO")
            if enable:
                self.config['WakeButton'] = 'enabled'
                self.config['Device'] = 'RaspberryPi'
            else:
                self.config['WakeButton'] = 'disabled'
        except ImportError:
            print("\nThis device does not support RPi.GPIO")
            self.config['WakeButton'] = 'not available'
        except RuntimeError:
            print("\nThis device does not support RPi.GPIO")
            self.config['WakeButton'] = 'not available'


    def request_hotword_choice(self, use_snowboy = True):
        """ Method to request user for default Hotword Engine and configure it in settings.
        """
        try:
            print("Checking for Snowboy Availability...")
            snowboy_available = util.find_spec('snowboy')
            found = snowboy_available is not None
    
        except ImportError:
            print("Some Error Occurred.Snowboy not configured properly.\nUsing PocketSphinx as default engine for Hotword. Run this script again to change")
            found = False
            self.config['hotword_engine'] = 'PocketSphinx'
    
        if found is True:
            print("Snowboy is available on this platform")
            if use_snowboy:
                self.config['hotword_engine'] = 'Snowboy'
                print('\n Snowboy set as default Hotword Detection Engine \n')
            else:
                self.config['hotword_engine'] = 'PocketSphinx'
                print('\n PocketSphinx set as default Hotword Detection Engine \n')
        else:
            print('\n Snowboy not configured Properly\n')
            self.config['hotword_engine'] = 'PocketSphinx'
            print('\n PocketSphinx set as default Hotword Detection Engine \n')
    
    
    
    def get_set(self, k, v = None):
        if k in self.keys_conf:
            pass
        else:
            raise ValueError('unknown key', k)
    
        if k == "stt":
            if not (v is None):
                if v == 'google' or v == 'watson' or v == 'bing' or v == 'pocketsphinx':
                    self.config[self.keys_conf[k]] = v
                else:
                    raise ValueError(k,v)
            return self.config[self.keys_conf[k]]
        elif k == 'tts':
            if not (v is None):
                if v == 'google' or v == 'watson' or v == 'flite':
                    self.config[self.keys_conf[k]] = v
                else:
                    raise ValueError(k, v)
            return self.config[self.keys_conf[k]]
        elif k == 'watson.stt.user':
            if not (v is None):
                self.config['watson_stt_config']['username'] = v
            return self.config['watson_stt_config']['username']
        elif k == 'watson.stt.pass':
            if not (v is None):
                self.config['watson_stt_config']['password'] = v
            return self.config['watson_stt_config']['password']
        elif k == 'watson.tts.user':
            if not (v is None):
                self.config['watson_tts_config']['username'] = v
            return self.config['watson_tts_config']['username']
        elif k == 'watson.tts.pass':
            if not (v is None):
                self.config['watson_tts_config']['password'] = v
            return self.config['watson_tts_config']['password']
        elif k == 'susi.user':
            if not (v is None):
                self.config['login_credentials']['email'] = v
            return self.config['login_credentials']['email']
        elif k == 'susi.pass':
            if not (v is None):
                self.config['login_credentials']['password'] = v
            return self.config['login_credentials']['password']
        elif k == 'roomname':
            if not (v is None):
                self.config[self.keys_conf[k]] = v
            return self.config[self.keys_conf[k]]
        elif k == 'bing.api':
            if not (v is None):
                self.config[self.keys_conf[k]] = v
            return self.config[self.keys_conf[k]]
        elif k == 'wakebutton':
            if not (v is None):
                if v == 'y' or v == 'n' or v == 'enable' or v == 'disable':
                    setup_wake_button( v == 'y' or v == 'enable')
                else:
                    raise ValueError(k, v)
            return self.config[self.keys_conf[k]]
        elif k == 'susi.mode':
            if not (v is None):
                if v == 'authenticated' or v == 'anonymous':
                    self.config[self.keys_conf[k]] = v
                else:
                    raise ValueError(k, v)
            return self.config[self.keys_conf[k]]
        elif k == 'hotword':
            if not (v is None):
                if v == 'y' or v == 'n' or v == 'Snowboy' or v == 'PocketSphinx':
                    self.request_hotword_choice( v == 'y' or v == 'Snowboy' )
                else:
                    raise ValueError(k, v)
            return self.config[self.keys_conf[k]]
        elif k == 'data_base_dir':
            if not (v is None):
                self.config[self.keys_conf[k]] = v
            return self.config[self.keys_conf[k]]
        elif k == 'flite_speech_file_path':
            if not (v is None):
                self.config[self.keys_conf[k]] = v
            return self.config[self.keys_conf[k]]
        elif k == 'detection_bell_sound':
            if not (v is None):
                self.config[self.keys_conf[k]] = v
            return self.config[self.keys_conf[k]]
        elif k == 'problem_sound':
            if not (v is None):
                self.config[self.keys_conf[k]] = v
            return self.config[self.keys_conf[k]]
        elif k == 'recognition_error_sound':
            if not (v is None):
                self.config[self.keys_conf[k]] = v
            return self.config[self.keys_conf[k]]
        elif k == 'device':
            if not (v is None):
                self.config[self.keys_conf[k]] = v
            return self.config[self.keys_conf[k]]
    
        else:
            raise ValueError(k, v)
    
 
    def main(self, args):
        if len(args) == 1:
            print("""
    Usage:
      susi-config get [ key key ... ]
      susi-config set key=value [ key=value ... ]
      susi-config login
    """)
            sys.exit(1)
    
        try:
            if args[1] == 'set':
                for kv in args[2:]:
                    k,v = kv.split('=', 2)
                    if k in self.keys_conf:
                        pass
                    else:
                        raise ValueError('unknown key', k)
                    self.get_set(k,v)
    
            elif args[1] == 'get':
                if len(args) == 2:
                    args = list(self.keys_conf.keys())
                else:
                    args = args[2:]
                ret = []
                for k in args:
                    v = self.get_set(k)
                    if type(v) != type('str'):
                        ret.append(k + " = (unset)")
                    else:
                        ret.append(k + " = " + str(v))
                for i in ret:
                    print(i)
    
            elif args[1] == 'login':
                import susi_python as susi
                susi.sign_in(self.config['login_credentials']['email'],
                             self.config['login_credentials']['password'],
                             room_name=self.config['room_name'])
    
            else:
                raise ValueError
    
        except ValueError as ex:
            print('Invalid input', ex, args)
    

