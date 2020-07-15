# Installation of SUSI.AI Personal Assistant

This repository provides installation packages for the SUSI.AI Personal Assistant,
both for desktop installation as well as images for the SUSI.AI Smart Speaker
based on Raspberry Pi.

## Quickstart

If you want to get SUSI.AI Personal Assistant installed quickly without reading
all the small print, here are two avenues you can select: Either use our
pre-built images, or install using our scripts.

### Installation via install scripts

Get the installer source by downloading the *Source Code*
from the Github [SUSI Installer release page](https://github.com/fossasia/susi_installer/releases/latest).

Optionally you can also clone the git repository.

After that, a fully automated installation of SUSI.AI and all necessary requirements can be
achieved by running
```
install.sh
```
Note that this will use `sudo` and you will get asked for the password.

This script calls first `install-requirements.sh` and then `install-susi.sh`
with adequate arguments.

This will be default install SUSI.AI into `$HOME/.susi.ai`, adds desktop entries
as well as systemd unit files for starting and stopping the various services.


### Installation via pre-built images

#### Step 1: Download the SUSI.AI Smart Assistant package

Get the installer package SUSIAI-release-YYYYMMDD.S.tar.gz (or SUSIAI-build-YYYYMMDD.S.tar.gz) from
the Github [SUSI Installer release page](https://github.com/fossasia/susi_installer/releases/latest).


#### Step 2: Unpack the package to your preferred location

The package unpacks into a directory
```
SUSI.AI
```
which can be placed anywhere in your system. We generally
recommend placing it into
```
$HOME/SUSI.AI
```
but feel free to move it somewhere else.

#### Step 3: Install necessary dependencies

The SUSI.AI Smart Assistant depends on a lot of additional
software that can be installed using the included script
```
bash install-requirements.sh --system-install --with-deepspeech
```
For other options, please see below for details.

If `sudo` is not an option, the following method can be used
```
bash install-requirements.sh --sudo-cmd ""
```
This method is much less tested, because the required Python modules will
be installed into your home directory (`~/.local/lib`). On the other hand,
no `sudo` permissions are needed, and everything can be done as local user.


#### Optional step 1: Linking start/stop scripts

There are several script to start, stop, and configure SUSI.AI
available in `.../SUSI.AI/bin`, but this directory is usually not
in your PATH environment variable.

If you don't want to call the scripts always with full path, you
can either add `.../SUSI.AI/bin` to your PATH
```bash
PATH=.../SUSI.AI/bin:$PATH ; export PATH
```
or link the scripts to one of the directories already in your
PATH
```
.../SUSI.AI/bin/susi-config install links <SOME_DIR>
```
where `<SOME_DIR>` is the place where the links are created.

So for example
```
.../SUSI.AI/bin/susi-config install links ~/bin
```
would make the SUSI.AI scripts available in `~/bin`


#### Optional step 2: Adding entries to the DE menus

You can add menu entries to your desktop environment by calling
```
.../SUSI.AI/bin/susi-config install desktop user
```
Having done this, the following items should be
available in your desktop environment menu:

- **SUSI Server** - starts the SUSI Server, a necessary component
- **SUSI.AI Personal Assistant** - starts the privacy assistant in the background
- **SUSI.AI Personal Assistant - Application Window** - an application that
  allows interaction via an GUI
- **SUSI.AI Personal Assistant - Configuration** - configuration of various
  parameters of SUSI.AI

More programs and services will be added over time.


#### Optional step 3: Adding Systemd integration

Systemd integration can be achieved by installing several
.service files into the respective locations using
```
.../SUSI.AI/bin/susi-config install systemd user
```

After installation of the systemd service files, the SUSI.AI Personal
Assistant can be started once by typing:
```
systemctl --user start ss-susi-server
systemctl --user start ss-susi-linux
```
If you want to enable the assistant permantenly on your desktop, use
```
systemctl --user enable ss-susi-server
systemctl --user enable ss-susi-linux
```


### Available options for the installation scripts

For more controlled installation with lots of options to be configured,
see below for the detailed explanation of the installation scripts.


## Starting and stopping SUSI.AI

To start the SUSI.AI Smart Assistant, first you need to start the
SUSI.AI Server, by either calling
```
$HOME/.susi.ai/bin/susi-server start
```
or, if systemd integration was installed, by calling
```
systemd --user start ss-susi-server
```

After this, you are ready to start SUSI.AI Smart Assistant by either calling
```
$HOME/.susi.ai/bin/susi-linux start
```
or, if systemd integration was installed, by calling
```
systemd --user start ss-susi-linux
```

You can stop the two service in the similar way:
```
$HOME/.susi.ai/bin/susi-linux stop
$HOME/.susi.ai/bin/susi-server stop
```
or, if systemd integration was installed, by calling
```
systemd --user stop ss-susi-linux
systemd --user stop ss-susi-server
```




## Prerequisites

See details in (PREREQUISITES.md)[PREREQUISITES.md].

### Installation of requirements

The provided script `install-requirements` checks that the above mentioned
programs are available, checks the version number of the available `pip3`
binary, updating it if necessary using `pip3` itself, and then uses `pip3`
to install the missing requirements.

The script uses `sudo` to obtain `root` rights to install the necessary Python
libraries.

Possible options:
```
  --trust-pip      Don't do version checks on pip3, trust it to be new enough
  --branch BRANCH  If no local checkouts are available, use the git remotes
                   with branch BRANCH to get requirement files (default: development)
  --raspi          Do additional installation tasks for the SUSI.AI Smart Speaker
  --sudo-cmd CMD   Use CMD instead of the default sudo
  --system-install Try installing necessary programs, only supported for some distributions
  --sys-installer ARG   Select a system installer if not automatically detected, one of "apt" or "dnf"
  --with-deepspeech Install DeepSpeech and en-US model data
  --no-install-node Don't install node and npm from NodeSource
                   If Node and NPM are available in sufficiently new versions,
                   no update/install will be done anyway
  --no-clean       Don't remove temp directory and don't use --no-cache-dir with pip3
  --quiet          Silence pip on installation
```



## Installation of SUSI.AI

The installaction script `install-susi.sh` carries out the actual installation
on the target system. It checks that the above set of programs is availabe,
clones the necessary git repositories from github, and installs Systemd
unit files to allow starting/enabling the respective programs. On the
Raspberry based SUSI.AI Smart Speaker, several further tasks are carried
out to set up audio playback, sound device setup etc.

### Installation modes

The installation can be carried out in either `user` moder or `system`
mode:

- `user mode`: All files are installed into the directory `SUSI.AI`
  in the home directory of the current user (the location can be configured).
  Systemd unit files into the current user's systemd configuration directory.
  Utility programs for SUSI.AI are installed into `SUSI.AI/bin`.

- `system mode`: All files are installed into the directory `SUSI.AI` in
  `/usr/local` (again, the location can be configured), and systemd unit
  files are installed in the system-wide systemd configuration directories.
  Utility programs for SUSI.AI are installed into `/usr/local/bin`.

  In `system mode` a new dedicated user for the SUSI.AI server process
  is necessary, and will be created. By default it will be named
  `_susiserver`.


### Command line options for `install-susi.sh`

The behaviour of the installation script can be changed with the following
command line options:
```
  --system         install system-wide
  --prefix <ARG>   (only with --system) install into <ARG>/lib/SUSI.AI
  --destdir <ARG>  (only without --system) install into <ARG>
                   defaults to $HOME/SUSI.AI
  --susi-server-user <ARG> (only with --system)
                   user under which the susi server is run, default: _susiserver
  --dev            use development branch
  --with-coral     install support libraries for the Coral device (Raspberry)
```

### Configuration file ###

During installation a configuration file is generated in `$XDG_CONFIG_HOME/SUSI.AI/config.json`,
which normally is `~/.config/SUSI.AI/config.json`. This file is read from various
parts of the SUSI.AI system. Changes to this file are preferrably made
by calling `susi-config` which is installed into `SUSI.AI/bin`.

## SUSI.AI Smart Speaker

During installation of the SUSI.AI Smart Speaker, further tasks are
performed, and the behaviour cannot be changed using command line options.
