#!/bin/bash

# Copyright (c) 2016 alinmear
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

# NAME
# 	mpd_launcher - client script for mpd
#
# DESCRIPTION
# 	This script is used in combination with a raspberry pi and volumio.
# 	It first makes a playlist with specified tracks or streams from urls.
# 	Then the script watches mpd that music is still played.

MPC="$(which mpc)"
MPC_OPTIONS=(repeat)
MODE="local" 
STREAMS=()
TRACKS=()

_conf_file_check=0
if [ "$(id -u)" != "0"  ]; then
    _global_conf="/etc/mpd_launcher.cf"
    _local_conf="~/.config/mpd_launcher.cf"
    if [ -f "${_global_conf}" ]; then
        source "${_global_conf}"
        _conf_file_check=0
    else
        _conf_file_check=1
    fi
else
    if [ -f "${_local_conf}" ]; then
        source "${_local_conf}"
        _conf_file_check=0
    else
        _conf_file_check=1
    fi
fi

[ ${_conf_file_check} != 0 ] && echo "No configs provided. Using Defaults, playing all local tracks in endless loop ..."

BACKEND=
BACKEND_NAME=
BACKENDS=("mopidy" "mpd")

# some eyecandy :)
OK_A="  $(tput setaf 2)* $(tput sgr 0)"
NOT_A="  $(tput setaf 4)* $(tput sgr 0)"
WARN_A="  $(tput setaf 3)* $(tput sgr 0)"
ERR_A="  $(tput setaf 1)* $(tput sgr 0)"

function init() {
    get_backend
    startup
    add_tracks 
    play
}

function add_tracks() {
    echo ">>>> Starting to add tracks"
    echo "${NOT_A} MODE set to ${MODE}"
    if [[ "${MODE}" == "local" ]]
    then
        # mpd
        [[ -z $TRACKS ]] && [[ "${BACKEND}" == 'mpd' ]] && \ 
        "${MPC}" clear > /dev/null && add_all_tracks && echo "${OK_A} added all Tracks in library to playlist" && return 0 || \
            echo "${ERR_A} No tracks found. Aborting ..." && exit 1

        # mopidy
        # @TODO: Add mopdiy all tracks from library
        [[ -z $TRACKS ]] && [[ "${BACKEND}" == 'mopidy' ]] && echo "${ERR_A} No Tracks found. Aborting ..." && exit 1

        # Tracks are provided. Add them
        "${MPC}" add $TRACKS && echo "${OK_A} added to playlist: ${TRACKS[@]}" && return 0  || return 1

        echo "${ERR_A} failed to add ${TRACKS[@]} to playlist. Aborting ..." 
        exit 1
    elif [[ "${MODE}" == "stream" ]]
    then 
        "${MPC}" add ${STREAMS[@]} && echo "${OK_A} added to playlist: ${STREAMS[@]}" && return 0 
        echo "${ERR_A} failed to add ${STREAMS[@]} to playlist" 
        exit 1 
    else
        echo "${ERR_A} Mode ${MODE} not found. Aborting ..."
        exit 1
    fi
}

function _check_process() {
    if pgrep -x "$1" > /dev/null
    then
        return 0
    else
        return 1
    fi
}

function startup() {
    echo ">>>> Starting ${BACKEND}" 

    if _check_process ${BACKEND_NAME}
    then
        echo "${NOT_A} ${BACKEND_NAME} already running" 
        return 0
                #echo ">>>> Starting ${BACKEND}" && (${BACKEND} 2> /dev/null 1> /dev/null &) && "$MPC" stop && sleep 5 && return 0
    else
        ${BACKEND} 2> /dev/null 1> /dev/null & 
        sleep 1 
        $MPC stop > /dev/null
        return 0
    fi
}

function get_backend() {
    for backend in ${BACKENDS[@]}
    do
        echo ">>>> Checking Backend ${backend}"
        check="$(which ${backend})"
        [[ $? == 0 ]] && BACKEND="${check}" && BACKEND_NAME="${backend}" && echo "${OK_A} ${BACKEND} found" && break || echo "${ERR_A} ${check} not found"
    done
    [[ -z ${BACKEND} ]] && (echo "${ERR_A} No backend found. Aborting ..." && exit 1)
}

function watch() {
echo ">>>> Beginning to watch ${BACKEND}"
while true
do
    pgrep ${BACKEND_NAME} 2>&1 > /dev/null && \
    ${MPC} | grep playing 2>&1 > /dev/null
    if [[ $? == 0 ]]
    then
        sleep 3
    else
        echo "${ERR_A} ${BACKEND} is not working probably. Trying to reset ..."
        # check whether backend is running or not first
        if _check_process ${BACKEND_NAME}
        then
            
            play || (clear_playlist && add_tracks && play || (reset && add_tracks && play || exit 1))
        else
            startup && add_tracks && play || exit 1
        fi
    fi
done
}

function clear_playlist() {
    echo ">>>> Clearing Playlist"
    ${MPC} clear
    [[ $? == 0 ]] && echo "${OK_A} successfuly cleared playlist" && return 0 || echo "${ERR_A} Some errors occurred while clearing the playlist" && return 1
}

function reset() {
    echo ">>>> Resetting ${BACKEND}"
    check_backend_running 2> /dev/null 1> /dev/null
    [[ $? == 0 ]] && killall -s15 "${BACKEND_NAME}" && [[ $? == 0 ]] && echo "${OK_A} killed ${BACKEND_NAME} with Signal 15" && sleep 3 
    check_backend_running 2> /dev/null 1> /dev/null
    [[ $? == 0 ]] && killall -s9 "${BACKEND_NAME}" && [[ $? == 0 ]] && echo "${OK_A} forced to kill ${BACKEND_NAME} with Signal 9" && sleep 3
    check_backend_running 2> /dev/null 1> /dev/null
    [[ $? == 0 ]] && echo "${ERR_A} Failed to kill ${BACKEND_NAME} with Signal 9! Exiting ..." && exit 1
    startup
    clear_playlist 
}

function set_options() {
    for option in ${MPC_OPTIONS[@]}
    do 
        ${MPC} ${option} on && echo "${OK_A} option ${option} enabled" && return 0 || echo "${WARN_A} failed to enable option ${option}" && return 1
    done
}

function play() {
    echo ">>>> Starting Playback"
    set_options
    ${MPC} play 2>&1 > /dev/null && echo "${OK_A} successfuly started playback" && ${MPC} | grep playing 2>&1 > /dev/null && return 0 || echo "${ERR_A} Some errors occurred while starting playback" && return 1
}

function add_all_tracks() {
    echo ">>>> Adding all tracks from library to playlist"
    "${MPC}" listall | "$MPC" add && \
        echo "${OK_A} Tracks successfuly added" && return 0 || echo "${ERR_A} Some errors occurred while adding tracks to playlist" && return 1
}

init
watch
