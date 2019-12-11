# Installation of SUSI.AI Personal Assistant

This repository provides installation script for SUSI.AI for Linux Desktops
as well as for our development SUSI.AI Smart Speaker based on Raspberry Pi.

## Prerequisites

The installation script expects certain programs and libraries being installed
on the system, in particular the following programs need to be available
(not necessarily for the installation, but also for operation of SUSI.AI
programs afterwards):

	git wget sox java vlc flac python3 pip3

Furthermore, a considerable list of Python libraries are required for full
operation. The script `install-dependencies` will install them using `pip3`
if they are not already installed. That means, at installation time one
can decide to either use the distribution (Debian, Fedora,...) provided
packages or those directly available from the PyPy distribution.

To ensure that additional repositories can be used, `pip3` needs to be
at least at version 18 to ensure we can specify additional repositories
in the requirement files. The `install-dependencies` script will update
`pip3` if this requirement is not fulfilled.


### List of Python packages

In the following we give the list of Python packages that are required
as of 12/2019. The definitive list is obtained from the `requirements.txt`
files in the repositories of `susi_installer`, `susi_python`, and `susi_linux`.

We provide PIP package names and Debian package names if available, and will
try to provide updated lists for other distributions, too.

| PIP | Debian/Buster | Fedora |
| --- | --- | --- |
| setuptools            | python3-setuptools                    | |
| pyalsaaudio		| python3-alsaaudio			| |
| pafy			| python3-pafy				| |
| mutagen		| python3-mutagen			| |
| colorlog		| python3-colorlog			| |
| pyaudio		| python3-pyaudio			| |
| python-Levenshtein	| python3-levenshtein			| |
| python-vlc		| python3-vlc				| |
| requests_futures	| python3-requests-futures		| |
| service_identity	| python3-service-identity		| |
| watson-developer-cloud | python3-watson-developer-cloud	| |
| youtube-dl>=2019.6.21	| youtube-dl				| |
| requests>=2.13.0	| python3-requests			| |
| flask			| python3-flask				| |
| pocketsphinx==0.1.15	| - (version wrong)			| |
| google_speech		| -					| |
| json_config		| -					| |
| rx>=3.0.0a0		| -					| |
| snowboy==1.3.0	| -					| |
| speechRecognition==3.8.1 | -					| |
| websocket-server	| -					| |
| async_promises	| -					| |
| geocoder		| -					| |
| soundcloud-lib	| -					| |

Indirect dependencies when installing some of the above

| PIP | Debian/Buster | Fedora | Requested by |
| --- | --- | --- |
| click			| python3-click		| | geocoder |
| future		| python3-future	| | geocoder |
| six			| python3-six		| | geocoder |
| decorator		| python3-decorator	| | geocoder |
| ratelim		| -			| | geocoder |
| bs4			| -			| | soundcloud-lib |
| aiohttp		| python3-aiohttp	| | soundcloud-lib |
| beautifulsoup4	| python3-bs4		| | soundcloud-lib |
| typing		| -			| | async_promises |
| web-cache		| -			| | google_speech  |


Packages that are only required for installation on the Raspbian based
SUSI.AI smart speaker:
| PIP | Debian/Buster | Fedora | 
| --- | --- | --- |
| spidev   | | |
| RPi.GPIO | | |


Installation of some of these packages requires adding an extra repository
for `pip3` using `--extra-index-url https://repo.fury.io/fossasia/`.
This is done automatically by the `install-dependencies` script.


### Installation of dependencies

The provided script `install-dependencies` checks that the above mentioned
programs are available, checks the version number of the available `pip3`
binary, updating it if necessary using `pip3` itself, and then uses `pip3`
to install the missing dependencies.

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


## SUSI.AI Smart Speaker

During installation of the SUSI.AI Smart Speaker, further tasks are
performed, and the behaviour cannot be changed using command line options.



