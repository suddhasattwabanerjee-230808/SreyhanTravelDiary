"""Prints the Android build number for pubspec.yaml's version: 10000 * major
+ 100 * minor + patch (0.6.0 -> 600, 1.2.3 -> 10203). It only ever goes up
with the version, which is what the in-app updater compares. Builds up to
0.5.1 used 100 + the CI run number (at most 111), all below 600.

    python3 tool/build_number.py            # from pubspec.yaml
    python3 tool/build_number.py --version  # just the version, e.g. 0.6.0
"""

import os
import re
import sys

with open(os.path.join(os.path.dirname(__file__), "..", "pubspec.yaml")) as f:
    version = re.search(r"^version:\s*([0-9]+)\.([0-9]+)\.([0-9]+)", f.read(), re.M)

major, minor, patch = (int(x) for x in version.groups())
if minor > 99 or patch > 99:
    sys.exit("minor and patch must stay below 100")
print(f"{major}.{minor}.{patch}" if "--version" in sys.argv else 10000 * major + 100 * minor + patch)
