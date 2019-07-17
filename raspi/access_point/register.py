import sys
import requests
"""
This script is used to register the device after it has been setup. This script should perform the given function:
After configuration of the device is done through android app or manually, the SUSI.AI smart device will then shut down the hotspot and connect with your WiFi home network and online account.
If SUSI.AI is not able to connect to your home WiFi network after 3 times, it will restart the SUSI.AI hotspot again and you can start the setup process again.
If SUSI.AI connects successfully with the Internet and your account, it will show up in your list of connected devices and you can continue to configure its settings.
"""
#Get access token
url = 'https://api.susi.ai/aaa/login.json?'
PARAMS = {
    'login':sys.argv[1],
    'password':sys.argv[2],
    'type':'access-token'
}
r1 = requests.get(url, params=PARAMS).json()

#r2 = requests.get('https://api.susi.ai/aaa/addNewDevice.json?access_token=u8Sa26QGBGmxZOmc9Ew0WHN8FdcrL1&macid=21:12:23:34:12:23&name=meow&room=home&latitude=12.1&longitude=23.3')
print(r1['access_token'])
