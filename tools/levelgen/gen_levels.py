"""Generates scenes/world/District.tscn, scenes/shelter/Shelter.tscn and the information notes
the world places. Deterministic: run it again after editing district.py / shelter.py.

    python3 tools/levelgen/gen_levels.py
"""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from district import district
from shelter import shelter
from notes import write_notes

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

if __name__ == "__main__":
    notes = write_notes(ROOT)
    open(os.path.join(ROOT, "scenes/world/District.tscn"), "w").write(district().dump())
    open(os.path.join(ROOT, "scenes/shelter/Shelter.tscn"), "w").write(shelter().dump())
    print("levels written, %d notes" % len(notes))
