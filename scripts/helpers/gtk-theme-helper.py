#!/usr/bin/env python

import json
from os.path import join, isfile
from argparse import ArgumentParser
from lib.glib import get_user_config_dir

# When run as a program, returns 0 if the user configuration
# has the dark theme setting turned on, otherwise returns 1
#
# Replicates the config directory behaviour of mypaint - handling
# the -c flag if provided.


def main():
    """
    Load the user settings for mypaint if they exist, and check
    the value of the dark theme option. If the file does not exist
    or the parsing fails we fall back to the default state
    (dark theme being enabled).
    """
    # We only care about the config option and ignore any other flags
    parser = ArgumentParser()
    parser.add_argument("-c", "--config", nargs="?", metavar="DIR", type=str)
    args, _ = parser.parse_known_args()

    if args.config is None:
        confdir = join(get_user_config_dir(), u"mypaint")
    else:
        confdir = args.config

    settings_path = join(confdir, u"settings.json")

    if isfile(settings_path):
        try:
            with open(settings_path, "rb") as fp:
                settings = json.loads(fp.read().decode("utf-8"))
                dark_theme = settings.get("ui.dark_theme_variant", True)
                if not dark_theme:
                    # Dark theme has been disabled by the user
                    return 1
        except Exception as e:
            print(e)
            print("Could not load settings file, falling back to default")

    # The dark theme is enabled by default
    return 0


if __name__ == "__main__":
    exit(main())
