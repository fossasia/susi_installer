#!/usr/bin/env python3

import sys
import time
import re
import uuid

import requests
import json_config
import geocoder

def get_token(login,password):
    url = 'http://api.susi.ai/aaa/login.json?type=access-token'
    PARAMS = {
        'login':login,
        'password':password,
    }
    r1 = requests.get(url, params=PARAMS).json()
    return r1['access_token']

def device_register(access_token):
    g = geocoder.ip('me')
    mac=':'.join(re.findall('..', '%012x' % uuid.getnode()))
    url='https://api.susi.ai/aaa/addNewDevice.json?&name=SmartSpeaker'
    PARAMS = {
        'room':'home',
        'latitude':str(g.lat),
        'longitude':str(g.lng),
        'macid':mac,
        'access_token':access_token
    }
    print(PARAMS)
    r1 = requests.get(url, params=PARAMS).json()
    return r1

config = json_config.connect('/home/pi/SUSI.AI/config.json')
user = config['login_credentials']['email']
password = config['login_credentials']['password']

try:
    access_token=get_token(user,password)
    print(device_register(access_token))
    print(access_token)
except:
    time.sleep(5)
    print("retrying")
