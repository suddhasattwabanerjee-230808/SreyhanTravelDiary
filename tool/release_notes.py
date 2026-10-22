"""Prints the CHANGELOG.md section for a version, for the release page and
the in-app update's notes.

    python3 tool/release_notes.py 0.6.0
"""

import os
import re
import sys

version = sys.argv[1]
with open(os.path.join(os.path.dirname(__file__), "..", "CHANGELOG.md")) as f:
    text = f.read()
match = re.search(rf"^## \[{re.escape(version)}\][^\n]*\n(.*?)(?=^## \[|\Z)", text, re.M | re.S)
if not match:
    sys.exit(f"CHANGELOG.md has no section for {version}")
print(match.group(1).strip())
