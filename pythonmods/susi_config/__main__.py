#!/usr/bin/env python3
#
# susi-config
# Konfiguration of SUSI.AI, via the config.json

import sys
import os
from . import SusiConfig

if __name__ == '__main__':
    cfg = SusiConfig(
            os.path.abspath(
                os.path.join(
                    os.path.dirname(os.path.dirname(os.path.abspath(__file__))) + '../../..')))
    cfg.main(sys.argv)

