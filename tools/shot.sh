#!/bin/bash
# usage: shot.sh out.png [ENV=VAL ...]
cd "$(dirname "$0")/.."
OUT=$1; shift
env SHOT_OUT=$OUT "$@" timeout 150 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --audio-driver Dummy --rendering-method gl_compatibility --rendering-driver opengl3 res://tools/Screenshot.tscn 2>&1 | grep -E "saved|SCRIPT ERROR|^ERROR" | sort | uniq -c | head -8
