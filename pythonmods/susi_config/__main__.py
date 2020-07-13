#!/usr/bin/env python3
#
# susi-config
# Konfiguration of SUSI.AI, via the config.json

# TODO
# - configuration of susi server dedicated user in system install
# - creation of susi server user etc (see below)
# - uninstall: rm -rf ~/SUSI.AI  ~/.config/SUSI.AI/ ~/.local/share/systemd/user/ss-susi-*
#

import sys
import os
import re
import logging
import subprocess
import shutil
from pathlib import Path
from . import SusiConfig

logger = logging.getLogger(__name__)

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
  susi-config (un)install links DIR
         Install or uninstall links to user programs into DIR
  susi-config (un)install desktop user|system|raspi
         Install or uninstall desktop files into user or system directories
         (or for the SUSI Smart Speaker when `raspi' is given)
  susi-config (un)install systemd user|system|raspi
         Install or uninstall systemd service files into user or system directories
         (or for the SUSI Smart Speaker when `raspi' is given)
  susi-config uninstall [user|system]
         Uninstall the complete SUSI.AI system
         This includes uninstalling systemd and desktop integration,
         but links need to be uninstalled manually.
         Defaults to `user' uninstall method, unless specified.

Notes:
  - if path.base key is a literal . ("."), susi-config get path.base
    will try to return the absolute and resolved path of SUSI.AI directory
""")
    sys.exit(exitcode)


def sed(in_file, out_file, needle, replacement):
    logger.debug(f"sed-ing {in_file} to {out_file}")
    with open(in_file, "r") as source:
        lines = source.readlines()
    with open(out_file, "w") as dest:
        for line in lines:
            dest.write(re.sub(needle, replacement, line))

def __run_pkgconfig(default, *args):
    try:
        # capture_output only available on Python 3.7 onward :-(
        # runresult = subprocess.run(args, scapture_output=True)
        runresult = subprocess.run(args, stderr=subprocess.PIPE, stdout=subprocess.PIPE)
        ret = runresult.stdout.decode('utf-8').rstrip()
        if ret == '':
            ret = default
    except FileNotFoundError:
        ret = default
    return ret


# susi-config (un)install links DIR
# susi-config (un)install desktop user|system|raspi
# susi-config (un)install systemd user|system|raspi
# susi-config uninstall [user|system]
def install_uninstall(args):
    if args[1] == 'install' and len(args) != 4:
        raise ValueError("incorrect invocation of install action", args[2:])
    if args[1] == 'uninstall' and len(args) > 4:
        raise ValueError("incorrect invocation of uninstall action", args[2:])

    if args[1] == 'uninstall':
        uninstall_mode = "other" # uninstall links or systemd or desktop, dealt with below
        if len(args) == 2:
            uninstall_mode = "user"
        elif len(args) == 3:
            if args[2] == "user" or args[2] == "system":
                uninstall_mode = args[2]
            else:
                raise ValueError("Incorrect invocation of uninstall action", args[2:])
        if uninstall_mode == "user" or uninstall_mode == "system":
            cfg = SusiConfig()
            susiai_dir = os.path.realpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), "../../.."))
            if not os.path.isdir(susiai_dir):
                raise ValueError("cannot find SUSI.AI directory", susiai_dir)
            # determine whether the installation is a user or system installation
            homedir = os.path.realpath(os.environ['HOME'])
            install_in_home = (os.path.commonprefix([susiai_dir, homedir]) == homedir)
            if (install_in_home and uninstall_mode == "user") or (not install_in_home and uninstall_mode == "system"):
                pass
            else:
                print(f"Uninstall mode `{uninstall_mode}' does not match location of SUSI.AI installation {susiai_dir}, not removing!")
                return
            answer = ""
            while answer not in ["y", "n"]:
                answer = input(f"Do you want to remove the complete SUSI.AI from\n  {susiai_dir}\nAnswer [Y/N]? ").lower()
            if answer == "y":
                install_uninstall("foo", "uninstall", "systemd", uninstall_mode)
                install_uninstall("foo", "uninstall", "desktop", uninstall_mode)
                try:
                    shutil.rmtree(susiai_dir)
                except OSError as e:
                    print("Error: %s : %s" % (susiai_dir, e.strerror))
                try:
                    os.remove(cfg.conffile)
                except OSError as e:
                    print("Error: %s : %s" % (cfg.conffile, e.strerror))
                print("Finished.")
            else: # not a Y answer
                print("Ok, not removing SUSI.AI")

            sys.exit(0)

        else: # uninstall_mode is neither user nor system
            raise ValueError("Incorrect invocation of uninstall action", args[2:])


    if args[2] == 'links':
        if not os.path.exists(args[3]):
            raise ValueError("target directory not existing", args[3])
        susiai_bin = os.path.realpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), "../../../bin"))
        if not os.path.isdir(susiai_bin):
            raise ValueError("cannot find SUSI.AI/bin directory", susiai_bin)
        for f in os.listdir(susiai_bin):
            susipath = os.path.join(susiai_bin, f)
            ospath = os.path.join(args[3], f)
            if args[1] == 'install':
                os.symlink(susipath, ospath)
            else: # unistall
                if os.path.islink(ospath):
                    if os.readlink(ospath) == susipath:
                        # the link is present and points to our own file, remove it
                        os.remove(ospath)
            # should we warn about anything unusual?


    elif args[2] == 'desktop':
        if args[3] == 'user' or args[3] == 'raspi':
            destdir = str(Path.home()) + '/.local/share/applications'
        elif args[3] == 'system':
            destdir = '/usr/local/share/applications'
        else:
            raise ValueError("unknown mode for install desktop", args[3])
        susiai_dir = os.path.realpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), "../../.."))
        if not os.path.isdir(susiai_dir):
            raise ValueError("cannot find SUSI.AI directory", susiai_dir)
        susi_linux_dir = os.path.join(susiai_dir, 'susi_linux')
        susi_server_dir = os.path.join(susiai_dir, 'susi_server')
        if not os.path.isdir(susi_linux_dir):
            raise ValueError("cannot find SUSI.AI susi_linux directory", susi_linux_dir)
        if not os.path.isdir(susi_server_dir):
            raise ValueError("cannot find SUSI.AI susi_server directory", susi_server_dir)
        if args[1] == 'install':
            os.makedirs(destdir, exist_ok=True)
        desktop_files = []
        server_desktop_dir = os.path.join(susi_server_dir, "system-integration/desktop")
        linux_desktop_dir = os.path.join(susi_linux_dir, "system-integration/desktop")
        for f in os.listdir(server_desktop_dir):
            if f.endswith("desktop.in"):
                desktop_files.append((f[:-3], os.path.join(server_desktop_dir, f)))
        for f in os.listdir(linux_desktop_dir):
            if f.endswith("desktop.in"):
                desktop_files.append((f[:-3], os.path.join(linux_desktop_dir, f)))
        for f,p in desktop_files:
            target = os.path.join(destdir, f)
            if args[1] == 'install':
                sed(p, target, '@SUSIDIR@', susiai_dir)
            else:
                if os.path.isfile(target):
                    os.remove(target)


    elif args[2] == 'systemd':
        susiai_dir = os.path.realpath(os.path.join(os.path.dirname(os.path.realpath(__file__)), "../../.."))
        systemd_system_dir = __run_pkgconfig("/lib/systemd/system",
            'pkg-config', 'systemd', '--variable=systemdsystemunitdir')
        systemd_user_dir = __run_pkgconfig("/usr/lib/systemd/user",
            'pkg-config', 'systemd', '--variable=systemduserunitdir')
        systemd_home_user = str(Path.home()) + "/.config/systemd/user"
        if args[3] == 'user':
            if args[1] == 'install':
                os.makedirs(systemd_home_user, exist_ok=True)
                sed(os.path.join(susiai_dir,'susi_linux/system-integration/systemd/ss-susi-linux.service.in'),
                    os.path.join(systemd_home_user, 'ss-susi-linux.service'),
                    '@SUSIDIR@', susiai_dir)
                destfile = os.path.join(systemd_home_user, 'ss-susi-server.service')
                sed(os.path.join(susiai_dir,'susi_server/system-integration/systemd/ss-susi-server.service.in'),
                    destfile, '@SUSIDIR@', susiai_dir)
                # we need to remove the line with ^User=
                with open(destfile, "r") as source:
                    lines = source.readlines()
                with open(destfile, "w") as dest:
                    for line in lines:
                        if not line.startswith('User='):
                            dest.write(line)
                # do the same for etherpad
                if os.path.isdir(os.path.join(susiai_dir,'susi_server/data/etherpad-lite')):
                    destfile = os.path.join(systemd_home_user, 'ss-etherpad-lite.service')
                    sed(os.path.join(susiai_dir,'susi_installer/system-integration/systemd/ss-etherpad-lite.service.in'),
                        destfile, '@SUSIDIR@', susiai_dir)
                    # we need to remove the line with ^User=
                    with open(destfile, "r") as source:
                        lines = source.readlines()
                    with open(destfile, "w") as dest:
                        for line in lines:
                            if not line.startswith('User='):
                                dest.write(line)
                else:
                    print(f"susi-config: etherpad-lite not found in {susiai_dir}/susi_server/data/, skipping systemd file installation")

            else: # uninstall
                if os.path.isfile(os.path.join(systemd_home_user, 'ss-susi-linux.service')):
                    os.remove(os.path.join(systemd_home_user, 'ss-susi-linux.service'))
                if os.path.isfile(os.path.join(systemd_home_user, 'ss-susi-server.service')):
                    os.remove(os.path.join(systemd_home_user, 'ss-susi-server.service'))
                if os.path.isfile(os.path.join(systemd_home_user, 'ss-etherpad-lite.service')):
                    os.remove(os.path.join(systemd_home_user, 'ss-etherpad-lite.service'))

        elif args[3] == 'system':
            if args[1] == 'install':
                os.makedirs(systemd_system_dir, exist_ok=True)
                sed(os.path.join(susiai_dir,'susi_linux/system-integration/systemd/ss-susi-linux@.service.in'),
                    os.path.join(systemd_system_dir, 'ss-susi-linux@.service'),
                    '@SUSIDIR@', susiai_dir)
                sed(os.path.join(susiai_dir,'susi_linux/system-integration/systemd/ss-susi-linux.service.in'),
                    os.path.join(systemd_user_dir, 'ss-susi-linux.service'),
                    destfile, '@SUSIDIR@', susiai_dir)
                destfile = os.path.join(systemd_system_dir, 'ss-susi-server.service')
                sed(os.path.join(susiai_dir,'susi_server/system-integration/systemd/ss-susi-server.service.in'),
                    destfile, '@SUSIDIR@', susiai_dir)
                # replace @SUSI_SERVER_USER@
                # TODO make _susi_server configurable!
                sed(destfile, destfile, '@SUSI_SERVER_USER@', '_susiserver')
                # TODO do the rest from install.sh
                #     $SUDOCMD useradd -r -d /nonexistent $SUSI_SERVER_USER
                #     $SUDOCMD mkdir -p /var/lib/susi-server/data
                #     $SUDOCMD chown $SUSI_SERVER_USER:$SUSI_SERVER_USER /var/lib/susi-server/data
                #     $SUDOCMD ln -s /var/lib/susi-server/data susi_server/data
                #     $SUDOCMD cp ss-susi-server.service $systemdsystem
                #     $SUDOCMD systemctl daemon-reload || true
                #
                # Install etherpad if available
                if os.path.isdir(os.path.join(susiai_dir,'etherpad')):
                    destfile = os.path.join(systemd_system_dir, 'ss-etherpad-lite.service')
                    sed(os.path.join(susiai_dir,'susi_installer/system-integration/systemd/ss-etherpad-lite.service.in'),
                        destfile, '@SUSIDIR@', susiai_dir)
                    sed(destfile, destfile, '@SUSI_ETHERPAD_USER@', '_susiserver')

            else: # uninstall
                if os.path.isfile(os.path.join(systemd_system_dir, 'ss-susi-linux@.service')):
                    os.remove(os.path.join(systemd_system_dir, 'ss-susi-linux@.service'))
                if os.path.isfile(os.path.join(systemd_user_dir, 'ss-susi-linux.service')):
                    os.remove(os.path.join(systemd_user_dir, 'ss-susi-linux.service'))
                if os.path.isfile(os.path.join(systemd_system_dir, 'ss-susi-server.service')):
                    os.remove(os.path.join(systemd_system_dir, 'ss-susi-server.service'))
                if os.path.isfile(os.path.join(systemd_system_dir, 'ss-etherpad-lite.service')):
                    os.remove(os.path.join(systemd_system_dir, 'ss-etherpad-lite.service'))


        elif args[3] == 'raspi':
            if args[1] == 'install':
                os.makedirs(systemd_system_dir, exist_ok=True)
                sed(os.path.join(susiai_dir,'susi_linux/system-integration/systemd/ss-susi-linux@.service.in'),
                    os.path.join(systemd_system_dir, 'ss-susi-linux@.service'),
                    '@SUSIDIR@', susiai_dir)
                destfile = os.path.join(systemd_system_dir, 'ss-susi-server.service')
                sed(os.path.join(susiai_dir,'susi_server/system-integration/systemd/ss-susi-server.service.in'),
                    destfile, '@SUSIDIR@', susiai_dir)
                sed(destfile, destfile, '@SUSI_SERVER_USER@', 'pi')
                destfile = os.path.join(systemd_system_dir, 'ss-etherpad-lite.service')
                sed(os.path.join(susiai_dir,'susi_installer/system-integration/systemd/ss-etherpad-lite.service.in'),
                    destfile, '@SUSIDIR@', susiai_dir)
                sed(destfile, destfile, '@SUSI_ETHERPAD_USER@', 'pi')
            else: # uninstall
                if os.path.isfile(os.path.join(systemd_system_dir, 'ss-susi-linux@.service')):
                    os.remove(os.path.join(systemd_system_dir, 'ss-susi-linux@.service'))
                if os.path.isfile(os.path.join(systemd_user_dir, 'ss-susi-linux.service')):
                    os.remove(os.path.join(systemd_user_dir, 'ss-susi-linux.service'))
                if os.path.isfile(os.path.join(systemd_system_dir, 'ss-susi-server.service')):
                    os.remove(os.path.join(systemd_system_dir, 'ss-susi-server.service'))
                if os.path.isfile(os.path.join(systemd_system_dir, 'ss-etherpad-lite.service')):
                    os.remove(os.path.join(systemd_system_dir, 'ss-etherpad-lite.service'))

        else:
            raise ValueError
    else:
        raise ValueError("unknown variant of install action", args[2])




def main(args):
    if len(args) == 1 or args[1] == "-h" or args[1] == "--help":
        usage(0)

    try:
        if args[1] == 'keys':
            cfg = SusiConfig()
            print("Possible keys (if no options listed then the value is free form):")
            for i in cfg.defaults.keys():
                if 'options' in cfg.defaults[i]:
                    print(f"  {i} -- possible values: {', '.join(cfg.defaults[i]['options'])}")
                else:
                    print(f"  {i}")

        elif args[1] == 'set':
            cfg = SusiConfig()
            ans = [ "Values set to:" ]
            for kv in args[2:]:
                k,v = kv.split('=', 2)
                if k in cfg.defaults:
                    pass
                else:
                    raise ValueError('unknown key', k)
                newv = cfg.get_set(k,v)
                ans.append(f"  {k} = {newv} (requested {v})")
            print("\n".join(ans))

        elif args[1] == 'get':
            cfg = SusiConfig()
            if len(args) == 2:
                args = list(cfg.defaults.keys())
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
                raise ValueError("too many arguments for action", 'login')
            import susi_python as susi
            susi.sign_in(cfg.config['susi.user'],
                         cfg.config['susi.pass'],
                         room_name=cfg.config['roomname'])

        elif args[1] == 'init':
            if len(args) == 2:
                force = False
            elif len(args) == 3:
                if args[2] == '-f':
                    force = True
                else:
                    raise ValueError("unsupported option to init", args[2])
            else:
                raise ValueError("unsupported options to init", args[2:])

            cfg = SusiConfig()
            for k,v in cfg.defaults.items():
                if force:
                    cfg.config[k] = v['default']
                else:
                    cfg.config.setdefault(k,v['default'])

        elif args[1] == 'install' or args[1] == 'uninstall':
            install_uninstall(args)

        else:
            raise ValueError("unknown action", args[1])

    except ValueError as ex:
        print("Invalid input: ", ex)
        usage(1)



if __name__ == '__main__':
    main(sys.argv)

