Installation of SUSI.AI Smart Assistant System
==============================================

TODO TODO merge with the main README.md!!!


Step 1: Download the SUSI.AI Smart Assistant package
----------------------------------------------------

Get the installer package SUSIAI-YYYYMMDDHHMM.tar.gz from
https://github.com/fossasia/susi_installer/releases/latest


Step 2: Unpack the package to your preferred location
-----------------------------------------------------

The package unpacks into a directory
	SUSI.AI
which can be placed anywhere in your system. We generally
recommend placing it into
	~/SUSI.AI
but feel free to move it somewhere else.

Step 3: Install necessary dependencies
--------------------------------------
The SUSI.AI Smart Assistant depends on a lot of additional
software that can be installed using the included script
	install-requirements.sh
which can install dependencies either system wide or locally,
with or without sudo. Please see the help output below:

Possible options:
  --trust-pip      Don't do version checks on pip3, trust it to be new enough
  --branch BRANCH  If no local checkouts are available, use the git remotes
                   with branch BRANCH to get requirement files (default: development)
  --raspi          Do additional installation tasks for the SUSI.AI Smart Speaker
  --sudo-cmd CMD   Use CMD instead of the default sudo
  --system-install Try installing necessary programs, only supported for some distributions
  --sys-installer ARG   Select a system installer if not automatically detected, one of "apt" or "dnf"
  --no-clean       Don't remove temp directory and don't use --no-cache-dir with pip3
  --quiet          Silence pip on installation

We recommend running this script as someone with sudo permissions as follows

	bash install-requirements.sh --system-install

*******************

After this, you are ready to start SUSI.AI Smart Assistant by

- first starting the SUSI.AI Server
	.../SUSI.AI/bin/start-susi-server
- then starting the SUSI.AI Assistant
	.../SUSI.AI/bin/start-susi-linux

(where .../SUSI.AI is the path you have choosen)



Optional step 1: Linking start/stop scripts
-------------------------------------------
There are several script to start, stop, and configure SUSI.AI
available in .../SUSI.AI/bin, but this directory is usually not
in your PATH environment variable.

If you don't want to call the scripts always with full path, you
can either add .../SUSI.AI/bin to your PATH
	(sh) PATH=.../SUSI.AI/bin:$PATH ; export PATH
or link the scripts to one of the directories already in your
PATH
	.../SUSI.AI/bin/susi-config install links <SOME_DIR>
where <SOME_DIR> is the place where the links are created.

So for example

	.../SUSI.AI/bin/susi-config install links ~/bin

would make the SUSI.AI scripts available in ~/bin


Optional step 2: Adding entries to the DE menus
-----------------------------------------------
You can add menu entries to your DE environment by calling

	.../SUSI.AI/bin/susi-config install desktop user


Optional step 3: Adding Systemd integration
-------------------------------------------
Systemd integration can be achieved by installing several
.service files into the respective locations using

	.../SUSI.AI/bin/susi-config install systemd user




Appendix: System wide installation
==================================
Desktop entries and systemd service files can also be installed
into system wide directories, but this needs careful consideration
and multi-user support is under ongoing development.

