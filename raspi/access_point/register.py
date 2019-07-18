#!/usr/bin/env python3

import sys
import time

import requests
import json_config

def get_token(login,password):
    url = 'http://api.susi.ai/aaa/login.json?type=access-token'
    PARAMS = {
        'login':login,
        'password':password,
    }
    r1 = requests.get(url, params=PARAMS).json()
    return r1['access_token']

def device_register(access_token):
    url='https://api.susi.ai/aaa/addNewDevice.json?&macid=21:12:23:34:12:23&name=meow&room=home&latitude=12.1&longitude=23.3'
    PARAMS = {
        'access_token':access_token
    }
    r1 = requests.get(url, params=PARAMS).json()
    return r1
config = json_config.connect('/home/pi/SUSI.AI/config.json')
user = config['login_credentials']['email']
password = config['login_credentials']['password']


print("hello")
try:
    access_token=get_token(user,password)
    print(device_register(access_token))
    print(access_token)
except:
    time.sleep(5)
    print("retrying")
