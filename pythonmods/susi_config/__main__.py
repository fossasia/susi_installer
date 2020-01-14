#!/usr/bin/env python3
#
# susi-config
# Konfiguration of SUSI.AI, via the config.json

import sys
import os
from . import SusiConfig

if __name__ == '__main__':
    cfg = SusiConfig()
    cfg.main(sys.argv)

