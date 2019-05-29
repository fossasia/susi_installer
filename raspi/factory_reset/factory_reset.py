import os
import time
import logging
import subprocess  # nosec #pylint-disable type: ignore

import RPi.GPIO as GPIO

logger = logging.getLogger(__name__)
current_folder = os.path.dirname(os.path.abspath(__file__))
factory_reset = current_folder + '/factory_reset.sh'
wap_script = os.path.abspath(current_folder + '/../access_point/wap.sh')

try:
    GPIO.setmode(GPIO.BCM)
    GPIO.setup(17, GPIO.IN, pull_up_down=GPIO.PUD_UP)
    while True:
        if GPIO.input(17) == 1:
            time.sleep(0.2)
            pass
        elif GPIO.input(17) == 0 :
            start = time.time()
            while GPIO.input(17) == 0 :
                time.sleep(0.2)
            end = time.time()
            total = end - start
            if total >= 25 :
                print("hard FACTORY RESET")
                logger.info("hard factory reset initiated")
                subprocess.Popen(['sudo','bash', factory_reset, 'hard'])
            elif total >= 15 :
                print("soft FACTORY RESET")
                logger.info("soft factory reset initiated")
                subprocess.Popen(['sudo','bash', factory_reset, 'soft'])
            elif total >= 7 :
                print("switch to access point mode")
                logger.info("switch to access mode initiated")
                subprocess.Popen(['sudo','bash', wap_script])
            logger.info(total)
            time.sleep(0.2)

except KeyboardInterrupt:
    GPIO.cleanup()

GPIO.cleanup()
