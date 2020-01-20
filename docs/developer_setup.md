
Setting up SUSI.AI for development on a desktop machine
=======================================================

Choose your own development place
```
DEVDIR=~/SUSI.AI
```

Install necessary packages
--------------------------

Run the script `install-requisites.sh` with `sudo`. See the toplevel
`README.md` for details.


Install SUSI.AI
---------------

Get various repositories (replace with `https://github.com/fossasia/...` for anonymous checkout)
```
cd $DEVDIR
git clone git@github.com:fossasia/susi_linux.git
git clone git@github.com:fossasia/susi_api_wrapper.git
git clone git@github.com:fossasia/susi_server.git
git clone git@github.com:fossasia/susi_skill_data.git
```

Update `susi_server` git submodules
```
cd $DEVDIR
cd susi_server
git submodule update --recursive --remote
git submodule update --init --recursive
```

We need to link several python modules into `susi_linux` to be able to
run it directly from the directory:
```
cd $DEVDIR
ln -s ../susi_api_wrapper/python_wrapper/susi_python susi_linux/
ln -s ../susi_installer/pythonmods/vlcplayer susi_linux/
ln -s ../susi_installer/pythonmods/hwmixer susi_linux/
for i in "susi_python vlcplayer hwmixer ; do
  echo "/$i" >> susi_linux/.git/info/exclude
done
```

Download speech data for flite TTS
-----------------------------------
We need to get the TTS data files
```
cd $DEVDIR
cd susi_linux
if [ ! -f "extras/cmu_us_slt.flitevox" ]
then
    wget "http://www.festvox.org/flite/packed/flite-2.0/voices/cmu_us_slt.flitevox" -P extras
fi
```

Optional: update youtube.lua
----------------------------
Probably only on stretch, it might be necessary to update youtube.lua
```
cd $DEVDIR
wget https://raw.githubusercontent.com/videolan/vlc/master/share/lua/playlist/youtube.lua
sudo mv youtube.lua /usr/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH)/vlc/lua/playlist/youtube.luac
```


Build `susi_server`
-------------------
```
cd $DEVDIR
cd susi_server
./gradlew build
```

Run `susi_server`
-----------------
```
cd $DEVDIR
cd susi_server
./bin/start.sh
```

Run `susi_linux`
----------------
```
cd $DEVDIR
cd susi_linux
python3 -m main -vv
```

