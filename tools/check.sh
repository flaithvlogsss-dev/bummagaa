#!/bin/bash
cd "$(dirname "$0")/.."
godot --headless --path . --editor --quit >/dev/null 2>&1
godot --headless --path . res://tools/CheckScripts.tscn 2>&1 | grep -E -A1 "SCRIPT ERROR|^ERROR|FAILED|CANNOT|check_scripts|WARNING" | grep -E "ERROR|FAILED|CANNOT|at:|check_scripts|WARNING" | grep -v "Failed to compile depended" | head -${1:-50}
