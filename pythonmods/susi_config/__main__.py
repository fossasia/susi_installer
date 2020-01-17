#!/usr/bin/env python3
#
# susi-config
# Konfiguration of SUSI.AI, via the config.json

import sys
import os
from . import SusiConfig

default_keys = {
    'default_stt':                'google',
    'default_tts':                'google',
    'watson_stt_config.username': '',
    'watson_stt_config.password': '',
    'watson_tts_config.username': '',
    'watson_tts_config.password': '',
    'login_credentials.email':    '',
    'login_credentials.password': '',
    'usage_mode':                 'anonymous',
    'room_name':                  'Office',
    'bing_speech_api_key':        '',
    'WakeButton':                 'enable',
    'hotword_engine':             'Snowboy',
    'data_base_dir':              '.',
    'flite_speech_file_path':     'extras/cmu_us_slt.flitevox',
    'detection_bell_sound':       'extras/detection-bell.wav',
    'problem_sound':              'extras/problem.wav',
    'recognition_error_sound':    'extras/recognition-error.wav',
    'timeout_error_sound':        'extras/error-tada.wav',
    'Device':                     'Desktop',
    'hotword_model':              '',
    'language':                   'en-US'
}

def usage(exitcode):
    print("""susi-config -- SUSI.AI configuration utility
Usage:
  susi-config init [-f]
         Create minimal configuration file, overwrite previous one with -f
  susi-config keys
         Lists all possible keys
  susi-config get [ key key ... ]
         Retrieves a set of keys, all if no argument is given
  susi-config set key=value [ key=value ... ]
         Sets a set of keys to values
  susi-config login
         Tries to log into the SUSI.AI Server
  susi-config install links DIR
         Install links to user programs into DIR
  susi-config install desktop user|system
         Install desktop files into user or system directories
  susi-config install systemd user|system
         Install systemd service files into user or system directories
""")
    sys.exit(exitcode)


def main(args):
    if len(args) == 1 or args[1] == "-h" or args[1] == "--help":
        usage(0)

    try:
        if args[1] == 'keys':
            cfg = SusiConfig()
            print("Possible keys:")
            for i in cfg.keys_conf.keys():
                print(f"  {i}")

        elif args[1] == 'set':
            cfg = SusiConfig()
            for kv in args[2:]:
                k,v = kv.split('=', 2)
                if k in cfg.keys_conf:
                    pass
                else:
                    raise ValueError('unknown key', k)
                cfg.get_set(k,v)

        elif args[1] == 'get':
            cfg = SusiConfig()
            if len(args) == 2:
                args = list(cfg.keys_conf.keys())
            else:
                args = args[2:]
            ret = []
            for k in args:
                v = cfg.get_set(k)
                if type(v) != type('str'):
                    ret.append(k + " = (unset)")
                else:
                    ret.append(k + " = " + str(v))
            for i in ret:
                print(i)

        elif args[1] == 'login':
            cfg = SusiConfig()
            if len(args) > 2:
                raise ValueError
            import susi_python as susi
            susi.sign_in(cfg.config['login_credentials']['email'],
                         cfg.config['login_credentials']['password'],
                         room_name=cfg.config['room_name'])

        elif args[1] == 'init':
            if len(args) == 2:
                force = False
            elif len(args) == 3:
                if args[2] == '-f':
                    force = True
                else:
                    raise ValueError
            else:
                raise ValueError

            cfg = SusiConfig()
            for k,v in default_keys.items():
                if force:
                    cfg.config[k] = v
                else:
                    cfg.config.setdefault(k,v)


        # susi-config install links DIR
        # susi-config install desktop user|system
        # susi-config install systemd user|system
        elif args[1] == 'install':
            if len(args) != 4:
                raise ValueError

            if args[2] == 'links':
                if os.path.exists(args[3]):
                    # TODO link all kind of scripts to args[3]
                    print(f"TODO installing links into {args[3]}")
                else:
                    raise ValueError
            elif args[2] == 'desktop':
                if args[3] == 'user':
                    destdir = str(Path.home()) + '/.config/share/applications'
                elif args[3] == 'system':
                    destdir = '/usr/local/share/applications'
                else:
                    raise ValueError
                print(f"TODO installing desktop files into {destdir}")
            elif args[2] == 'systemd':
                # TODO should we install some services into systemduserunitdir = /usr/lib/systemd/user?
                if args[3] == 'user':
                    destdir = str(Path.home()) + "/.config/systemd/user"
                elif args[3] == 'system':
                    destdir = self.__run_pkgconfig("/lib/systemd/system",
                            'pkg-config', 'systemd', '--variable=systemdsystemunitdir')
                else:
                    raise ValueError
                print(f"TODO installing systemd files into {destdir}")
            else:
                raise ValueError

        else:
            raise ValueError

    except ValueError as ex:
        print("Invalid input")
        usage(1)



if __name__ == '__main__':
    main(sys.argv)

