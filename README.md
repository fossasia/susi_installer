# Installation of SUSI.AI Personal Assistant

This repository provides installation packages for the SUSI.AI Personal Assistant,
both for desktop installation as well as images for the SUSI.AI Smart Speaker
based on Raspberry Pi.

## Quickstart

If you want to get SUSI.AI Personal Assistant installed quickly without reading
all the small print, here is a quickstart.

### Step 1: Download the SUSI.AI Smart Assistant package

Get the installer package SUSIAI-release-YYYYMMDD.S.tar.gz from
the Github [SUSI Installer release page](https://github.com/fossasia/susi_installer/releases/latest).


### Step 2: Unpack the package to your preferred location

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

### Step 3: Install necessary dependencies

The SUSI.AI Smart Assistant depends on a lot of additional
software that can be installed using the included script
```
install-requirements.sh
```
which can install dependencies either system wide or locally,
with or without sudo. Please see the help output below:

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
  --no-clean       Don't remove temp directory and don't use --no-cache-dir with pip3
  --quiet          Silence pip on installation
```

We recommend running this script as someone with sudo permissions as follows
```
bash install-requirements.sh --system-install --with-deepspeech
```
See below for a detailed list of requirements. 

If `sudo` is not an option, the following method can be used
```
bash install-requirements.sh --sudo-cmd ""
```
This method is much less tested, because the required Python modules will
be installed into your home directory (`~/.local/lib`). On the other hand,
no `sudo` permissions are needed, and everything can be done as local user.


### Step 4: Run the actual install script

Installation of the SUSI.AI Smart Assistant is done by the included script
```
install.sh
```
Please see the help output below:
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
We recommend running this script without any extra options:
```
bash install.sh
```


After this, you are ready to start SUSI.AI Smart Assistant by

- first starting the SUSI.AI Server
```
$HOME/SUSI.AI/bin/susi-server start
```
- then starting the SUSI.AI Assistant
```
$HOME/SUSI.AI/bin/susi-linux start
```

(where `$HOME/SUSI.AI` is the path you have choosen)

You can stop the two service in the similar way:
```
$HOME/SUSI.AI/bin/susi-linux stop
$HOME/SUSI.AI/bin/susi-server stop
```


### Optional step 1: Linking start/stop scripts

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


### Optional step 2: Adding entries to the DE menus

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


### Optional step 3: Adding Systemd integration

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


### Additional options

For more controlled installation with lots of options to be configured,
see below for the detailed explanation of the installation scripts.


## Prerequisites

The installation script expects certain programs and libraries being installed
on the system, in particular the following programs need to be available
(not necessarily for the installation, but also for operation of SUSI.AI
programs afterwards). The following table lists the required programs and
the respective packages in Debian/Buster and Fedora 31:

| Program | Debian/Ubuntu/Mint   | Fedora 31   | openSUSE Leap 15.1 |
| ------- | -------------------- | ----------- | ------------------ |
| git     | git                  | git         | git |
| wget    | wget                 | wget        | wget |
| sox     | sox                  | sox (1)     | sox |
| java    | default-jre-headless | java-1.8.0-openjdk-headless | java-1_8_0-openjdk-headless |
| vlc     | vlc-bin              | vlc (2)     | vlc |
| flac    | flac                 | flac        | flac |
| python3 | python3              | python3     | python3 |
| pip3    | python3-pip          | python3-pip | python3-pip |
| - (3)   | python3-setuptools   | python3-setuptools | python3-setuptools |
| - (4)   | libatlas3-base       | blas        | libopenblas_pthreads0 |
| node/nodejs (5) | nodejs           | ?           | ? |


(1) `sox` is not available in CentOS 8, this will probably make some of the
functionality break.

(2) On Fedora and CentOS, VLC is not available by default and the RPMFusion
repository needs to be enabled. The procedure is described
[here](https://docs.fedoraproject.org/en-US/quick-docs/setup_rpmfusion/).
If the `--system-install` command line option is used with
`install-requirements.sh`, this will be done automatically.

(3) `python3-setuptools` doesn't provide a binary, but it is required to be
installed, otherwise installations of other packages using `pip3` will
not work.

(4) Some package providing `libcblas` is necessary.

(5) If either `node` or `nodejs` binary is available, EtherPad for communication
with the SUSI Server is installed.


The above packages (plus two packages, see below under (\*)) can be optionally
installed by `install-requirements.sh` by adding the command line option
`--system-install`. Other options are installation on Debian using
`sudo apt-get install PKGS`, on Fedora `sudo dnf install PKGS`, on openSUSE
`sudo zypper install PKGS` (but read the note (1) and (2) above!).

Furthermore, a considerable list of Python libraries are required for full
operation. The script `install-requirements` will install them using `pip3`
if they are not already installed. That means, at installation time one
can decide to either use the distribution (Debian, Fedora,...) provided
packages or those directly available from the PyPy distribution.

To ensure that additional repositories can be used, `pip3` needs to be
at least at version 19 to ensure we can specify additional repositories
in the requirement files. The `install-requirements` script will update
`pip3` if this requirement is not fulfilled.

### List of Python packages

In the following we give the list of Python packages that are required
as of 12/2019. The definitive list is obtained from the `requirements.txt`
files in the repositories of `susi_installer`, `susi_python`, and `susi_linux`.

We provide PIP package names and Debian package names if available, and will
try to provide updated lists for other distributions, too.

| PIP | Debian/Buster | Ubuntu 18.04/Mint 19.2 |Fedora 31 | openSuSE Leap 15.1 |
| --- | --- | --- | --- | --- |
| setuptools            | python3-setuptools | python3-setuptools	    | python3-setuptools  | python3-setuptools  |
| pyalsaaudio		| python3-alsaaudio  | -			    | python3-alsaaudio   | - |
| pafy			| python3-pafy	     | python3-pafy		    | -                   | - |
| mutagen		| python3-mutagen    | python3-mutagen		    | python3-mutagen     | python3-mutagen |
| colorlog		| python3-colorlog   | python3-colorlog		    | python3-colorlog    | python3-colorlog |
| (\*) pyaudio		| python3-pyaudio    | python3-pyaudio		    | python3-pyaudio     | python3-PyAudio |
| (\*) python-Levenshtein	| python3-levenshtein | python3-levenshtein	    | python3-Levenshtein | python3-Levenshtein |
| python-vlc		| python3-vlc	     | -			    | python3-vlc         | -
| requests_futures	| python3-requests-futures | python3-requests-futures | ?                 | python3-requests-futures |
| service_identity	| python3-service-identity | python3-service-identity | python3-service-identity | - |
| watson-developer-cloud | python3-watson-developer-cloud | python3-watson-developer-cloud | -    | - |
| youtube-dl>=2019.6.21	| youtube-dl	     | youtube-dl		    | youtube-dl          | python3-youtube-dl |
| requests>=2.13.0	| python3-requests   | python3-requests		    | python3-requests    | python3-requests |
| flask			| python3-flask	     | python3-flask		    | python3-flask       | python3-Flask |
| pocketsphinx==0.1.15	| - (version wrong)  | - | - | - |
| google_speech		| -		     | - | - | - |
| json_config		| -		     | - | - | - |
| rx>=3.0.0a0		| -		     | - | - | - |
| snowboy==1.3.0	| -		     | - | - | - |
| speechRecognition==3.8.1 | -		     | - | - | - |
| websocket-server	| -		     | - | - | - |
| async_promises	| -		     | - | - | - |
| geocoder		| -		     | - | - | - |
| soundcloud-lib	| -		     | - | - | - |

(\*) The packages `pyaudio` and `python-Levenshtein` **should** be installed
via the system manager due to their dependencies on external libraries,
in particular `libportaudio`. If `--system-install` is passed to
`install-requirements.sh`, these two packages will be installed, too.

Indirect requirements when installing some of the above

| PIP | Debian/Ubuntu/LinuxMint | Fedora/openSUSE | Requested by |
| --- | --- | --- | -- |
| click			| python3-click		| python3-click | geocoder |
| future		| python3-future	| python3-future | geocoder |
| six			| python3-six		| python3-six | geocoder |
| decorator		| python3-decorator	| python3-decorator | geocoder |
| ratelim		| -			| - | geocoder |
| bs4			| -			| - | soundcloud-lib |
| aiohttp		| python3-aiohttp	| python3-aiohttp | soundcloud-lib |
| beautifulsoup4	| python3-bs4		| python3-beautifulsoup4 | soundcloud-lib |
| typing		| -			| - | async_promises |
| web-cache		| -			| - | google_speech  |


Packages that are only required for installation on the Raspbian based
SUSI.AI smart speaker:

| PIP      | Debian/Buster | Fedora |
| -------- | --- | --- |
| spidev   | -   | python3-spidev |
| RPi.GPIO | -   | - |


Installation of some of these packages requires adding an extra repository
for `pip3` using `--extra-index-url https://repo.fury.io/fossasia/`.
This is done automatically by the `install-requirements` script.


### Installation of requirements

The provided script `install-requirements` checks that the above mentioned
programs are available, checks the version number of the available `pip3`
binary, updating it if necessary using `pip3` itself, and then uses `pip3`
to install the missing requirements.

The script uses `sudo` to obtain `root` rights to install the necessary Python
libraries.


## Installation of SUSI.AI

The installaction script `install.sh` carries out the actual installation
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


### Command line options for `install.sh`

The behaviour of the installation script can be changed with the following
command line options:

- `--system`: enable `system mode` installation, the default is
  `user mode` installation
- `--destdir DIR`: (only in `user mode`) determines the installation
  location in `user mode`. This is the *full* path, not relative to the
  home directory of the user.
- `--prefix DIR`: (only in `system mode`) determines the directory into
  which the `SUSI.AI` directory will be put.
- `--susi-server-user STRING`: (only in `system mode`) specifies the name
  of the dedicated user for the SUSI.AI server user. Will be created if
  not existing already.

### Configuration file ###

During installation a configuration file is generated in `$XDG_CONFIG_HOME/SUSI.AI/config.json`,
which normally is `~/.config/SUSI.AI/config.json`. This file is read from various
parts of the SUSI.AI system. Changes to this file are preferrably made
by calling `susi-config` which is installed into `SUSI.AI/bin`.

## SUSI.AI Smart Speaker

During installation of the SUSI.AI Smart Speaker, further tasks are
performed, and the behaviour cannot be changed using command line options.
