#!/usr/bin/env python

# Strip out settings with default values from brush data,
# provided that they have no input mappings (brush dynamics).
# The exception is the paint_mode setting, which is retained
# even if it is default.

import json
import sys

CNKEY = "internal_name"
SKIP = {"paint_mode"}


def get_setting_defaults(brushsettings_filename):
    with open(brushsettings_filename) as f:
        brushsettings = json.loads(f.read())
    settings = brushsettings["settings"]
    return {s[CNKEY]: s["default"] for s in settings if s[CNKEY] not in SKIP}


def strip_defaults(brush, defaults):
    settings_dict = brush["settings"]
    settings_to_remove = set()
    for cname, values in settings_dict.items():
        if cname not in defaults:
            continue
        baseval = values.get("base_value", 0.0)
        inputs = values["inputs"]
        if not inputs and baseval == defaults[cname]:
            settings_to_remove.add(cname)
    for cname in settings_to_remove:
        settings_dict.pop(cname)
    return brush


def compact_json_string(data):
    return json.dumps(data, separators=(',', ':'))


def strip_files(settings_file, *brush_files):
    defaults = get_setting_defaults(settings_file)
    for bfile in brush_files:
        print(bfile)
        with open(bfile) as fr:
            bjson = json.loads(fr.read())
        with open(bfile, 'w') as fw:
            fw.write(compact_json_string(strip_defaults(bjson, defaults)))


if __name__ == "__main__":
    # First argument should be the location of the file brushsettings.json
    # Subsequent arguments should be .myb files (json data) to be minified.
    exit(strip_files(sys.argv[1], *(sys.argv[2:])))
