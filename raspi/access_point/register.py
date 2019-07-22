#!/usr/bin/env python3

import sys
import time
import re
import uuid
import os
import subprocess
import logging

import requests
import json_config
import geocoder

current_folder = os.path.dirname(os.path.abspath(__file__))

logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

config = json_config.connect('/home/pi/SUSI.AI/config.json')
user = config['login_credentials']['email']
password = config['login_credentials']['password']
room = config['room_name']

def get_token(login,password):
    url = 'http://api.susi.ai/aaa/login.json?type=access-token'
    PARAMS = {
        'login':login,
        'password':password,
    }
    r1 = requests.get(url, params=PARAMS).json()
    return r1['access_token']

def device_register(access_token,room):
    g = geocoder.ip('me')
    mac=':'.join(re.findall('..', '%012x' % uuid.getnode()))
    url='https://api.susi.ai/aaa/addNewDevice.json?&name=SmartSpeaker'
    PARAMS = {
        'room':room,
        'latitude':str(g.lat),
        'longitude':str(g.lng),
        'macid':mac,
        'access_token':access_token
    }
    r1 = requests.get(url, params=PARAMS).json()
    return r1

for i in range(3):
    try:
        access_token=get_token(user,password)
        out=device_register(access_token,room)
        logger.debug(str(out))
        break
    except:
        if i != 2:
            time.sleep(5)
            logger.warning("Failed to register the device,retrying.")
        else:
            logger.warning("Resetting the device to hotspot mode")
            config['usage_mode']="anonymous"
            config['login_credentials']['email']=""
            config['login_credentials']['password']=""
            subprocess.Popen(['sudo','bash', 'susi_installer/raspi/access_point/wap.sh'])
os.system('sudo systemctl disable ss-susi-register.service')
