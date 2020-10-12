# Prerequisites

The installation script expects certain programs and libraries being installed
on the system, in particular the following programs need to be available
(not necessarily for the installation, but also for operation of SUSI.AI
programs afterwards). The following table lists the required programs and
the respective packages in Debian/Buster and Fedora 31:

| Program | Debian/Ubuntu/Mint   | Fedora 31   | openSUSE Leap 15.1 | Arch Linux |
| ------- | -------------------- | ----------- | ------------------ |------------|
| git     | git                  | git         | git | git |
| wget    | wget                 | wget        | wget | wget |
| curl    | curl                 | curl        | curl | curl |
| sox     | sox                  | sox (1)     | sox | sox |
| java    | default-jre-headless | java-1.8.0-openjdk-headless | java-1_8_0-openjdk-headless | jre-openjdk-headless |
| vlc     | vlc-bin              | vlc (2)     | vlc | vlc |
| flac    | flac                 | flac        | flac | flac |
| python3 | python3              | python3     | python3 | python3 |
| pip3    | python3-pip          | python3-pip | python3-pip | python3-pip |
| - (3)   | python3-setuptools   | python3-setuptools | python3-setuptools | python3-setuptools |
| - (4)   | libatlas3-base       | blas        | libopenblas_pthreads0 | libopenblas_pthreads0 |
| node/nodejs (5) | nodejs           | ?           | ? | ? |


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

## List of Python packages

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


