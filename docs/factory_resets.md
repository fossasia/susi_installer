# Factory Resets
[Factory Reset](../factory_reset/factory_reset.py)

Currently, our factory reset is configured on the GPIO port 17 of the Raspberry Pi, i.e. when the button configured to the port 17 or the one connected on the ReSpeaker Pi Hat is pressed long enough, one of three actions is taken:

- Press between 7 and 15 seconds: the speaker is switched to access point mode.
  This is necessary in case the WLAN SSID has changed, or was misconfigured.
- Press between 15 and 25 seconds: a soft reset is executed, which restores the original
  software, but keeps configuration and server data.
- Press longer than 25 seconds: a hard reset is performed, the unit is reset to the original state.

## Developer information

The factory reset daemon is implemented in [factory_reset.py](../raspi/factory_reset/factory_reset.py).
Depending on the time the button was hold, either the [wap.sh](../raspi/access_point/wap.sh) is called,
or the [factory_reset.sh](../raspi/factory_reset/factory_reset.sh).


