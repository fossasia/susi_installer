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
import subprocess

class SusiConfig():
    def __init__(self, conffile = None, data_dir = "."):
        if 'XDG_CONFIG_HOME' in os.environ:
            confdir = os.path.join(os.environ['XDG_CONFIG_HOME'], "SUSI.AI")
        else:
            confdir = os.path.join(os.environ['HOME'], ".config", "SUSI.AI")
        if conffile:
            self.conffile = conffile
        else:
            self.conffile = os.path.join(confdir, "config.json")
        if not os.path.exists(confdir):
            os.makedirs(confdir)
        self.defaults = {
            'roomname':                     { 'default': 'Office' },
            'language':                     { 'default': 'en_US' },
            'device':                       { 'default': 'Desktop' },
            'wakebutton':                   { 'default': 'enabled', 
                                              'options' : [ 'enabled', 'disabled', 'not available' ] },
            'stt':                          { 'default': 'google', 
                                              'options': [ 'google', 'watson', 'bing',
                                                           'pocketsphinx', 'deepspeech-local' ] },
            'tts':                          { 'default': 'google', 
                                              'options': [ 'google', 'watson', 'flite' ] },
            'watson.stt.user':              { 'default': '' },
            'watson.stt.pass':              { 'default': '' },
            'watson.tts.user':              { 'default': '' },
            'watson.tts.pass':              { 'default': '' },
            'watson.tts.voice':             { 'default': '' },
            'bing.api':                     { 'default': '' },
            'susi.user':                    { 'default': '' },
            'susi.pass':                    { 'default': '' },
            'susi.mode':                    { 'default': 'anonymous',
                                              'options': [ 'anonymous', 'authenticated' ] },
            'hotword.engine':               { 'default': 'Snowboy',
                                              'options': [ 'Snowboy', 'PocketSphinx' ] },
            'hotword.model':                { 'default': '' },
            'path.base':                    { 'default': '.' },
            'path.flite_speech':            { 'default': 'susi_linux/extras/cmu_us_slt.flitevox' },
            'path.sound.detection':         { 'default': 'susi_linux/extras/detection-bell.wav' },
            'path.sound.problem':           { 'default': 'susi_linux/extras/problem.wav' },
            'path.sound.error.recognition': { 'default': 'susi_linux/extras/recognition-error.wav' },
            'path.sound.error.timeout':     { 'default': 'susi_linux/extras/error-tada.wav' }
        }
        self.config = json_config.connect(self.conffile)
        for k,v in self.defaults.items():
            self.config.setdefault(k,v['default'])

        self.susiai_path = os.path.realpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), "../../.."))

    def __run_pkgconfig(self, default, *args):
        try:
            runresult = subprocess.run(args, capture_output=True)
            ret = runresult.stdout.decode('utf-8').rstrip()
            if ret == '':
                ret = default
        except FileNotFoundError:
            ret = default
        return ret


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
            self.config['hotword.engine'] = 'PocketSphinx'
    
        if found is True:
            print("Snowboy is available on this platform")
            if use_snowboy:
                self.config['hotword.engine'] = 'Snowboy'
                print('\n Snowboy set as default Hotword Detection Engine \n')
            else:
                self.config['hotword.engine'] = 'PocketSphinx'
                print('\n PocketSphinx set as default Hotword Detection Engine \n')
        else:
            print('\n Snowboy not configured Properly\n')
            self.config['hotword.engine'] = 'PocketSphinx'
            print('\n PocketSphinx set as default Hotword Detection Engine \n')
    
    
    def get(self, k):
        return self.get_set(k)

    def set(self, k, v):
        return self.get_set(k, v)
    
    def get_set(self, k, v = None):
        if k in self.defaults:
            pass
        else:
            raise ValueError('unknown key', k)
        
        if k == 'wakebutton':
            if not (v is None):
                if v == 'y' or v == 'n' or v == 'enable' or v == 'disable':
                    enable = (v == 'y' or v == 'enable')
                    try:
                        import RPi.GPIO
                        print("\nDevice supports RPi.GPIO")
                        if enable:
                            self.config[k] = 'enabled'
                            self.config['device'] = 'RaspberryPi'
                        else:
                            self.config[k] = 'disabled'
                    except ImportError:
                        print("\nThis device does not support RPi.GPIO")
                        self.config[k] = 'not available'
                    except RuntimeError:
                        print("\nThis device does not support RPi.GPIO")
                        self.config[k] = 'not available'
                else:
                    raise ValueError(f"unsupported value for {k}", v)
            return self.config[k]

        elif k == 'hotword.engine':
            if not (v is None):
                if v == 'y' or v == 'n' or v == 'Snowboy' or v == 'PocketSphinx':
                    self.request_hotword_choice( v == 'y' or v == 'Snowboy' )
                else:
                    raise ValueError(f"unsupported value for {k}", v)
            return self.config[k]

        elif k == 'path.base':
            if not (v is None):
                self.config[k] = v
            # make the return value resolve "." to the location of SUSI.AI directory
            if self.config[k] == '.':
                return self.susiai_path
            else:
                return self.config[k]


        else:
            # default case, check if options are defined, otherwise
            # just set the default
            if not (v is None):
                if 'options' in self.defaults[k]:
                    if not (v in self.defaults[k]['options']):
                        raise ValueError(f"unsupported value for {k}",v)
                self.config[k] = v
            return self.config[k]

