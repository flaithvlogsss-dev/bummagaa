#!/bin/bash
# Forward+ (Vulkan via lavapipe). usage: shotv.sh out.png [ENV=VAL ...]
cd "$(dirname "$0")/.."
OUT=$1; shift
env SHOT_OUT=$OUT VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/lvp_icd.json "$@" timeout 280 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --audio-driver Dummy res://tools/Screenshot.tscn 2>&1 | grep -E "saved|SCRIPT ERROR|^ERROR|Vulkan" | sort | uniq -c | head -8
