# mpd_launcher
A script for starting up mpd and checking for endless play. This script is used for kiosk endless play in connection with the music player daemon and a raspberry pi.

## Configuration
The script checks at startup whether it is started with root privileges or with user privileges. You need to place the configuration file in a proper location:

**Global**

/etc/mpd_launcher.cf

**Local**

~/.config/mpd_launcher.cf

# TODO

* Add Makefile for easy installation
