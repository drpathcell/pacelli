#!/usr/bin/env python3
"""Extract user-facing string literals from PacelliApp Swift sources.

Heuristics cover the SwiftUI constructs used in this codebase:
String(localized:), Text/Button/TextField/Toggle/Picker/Label/Section/
navigationTitle/ContentUnavailableView/searchable/alert/confirmationDialog/
Tab/NavigationLink/ProgressView/accessibilityLabel.

Usage: python3 extract_strings.py [--json]
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent / "Sources"

PATTERNS = [
    r'String\(\s*localized:\s*\n?\s*"((?:[^"\\]|\\.)*)"',
    r'\bText\(\s*"((?:[^"\\]|\\.)*)"\s*\)',
    r'\bButton\(\s*"((?:[^"\\]|\\.)*)"',
    r'\bTextField\(\s*"((?:[^"\\]|\\.)*)"',
    r'\bSecureField\(\s*"((?:[^"\\]|\\.)*)"',
    r'\bToggle\(\s*"((?:[^"\\]|\\.)*)"',
    r'\bPicker\(\s*"((?:[^"\\]|\\.)*)"',
    r'\bLabel\(\s*"((?:[^"\\]|\\.)*)"',
    r'\bSection\(\s*"((?:[^"\\]|\\.)*)"\s*\)',
    r'\.navigationTitle\(\s*"((?:[^"\\]|\\.)*)"',
    r'ContentUnavailableView\(\s*\n?\s*"((?:[^"\\]|\\.)*)"',
    r'\bTab\(\s*"((?:[^"\\]|\\.)*)"',
    r'\bDatePicker\(\s*\n?\s*"((?:[^"\\]|\\.)*)"',
    r'prompt:\s*"((?:[^"\\]|\\.)*)"',
    r'\.alert\(\s*\n?\s*"((?:[^"\\]|\\.)*)"',
    r'confirmationDialog\(\s*\n?\s*"((?:[^"\\]|\\.)*)"',
    r'\.accessibilityLabel\(\s*"((?:[^"\\]|\\.)*)"\)',
    r'NavigationLink\(\s*"((?:[^"\\]|\\.)*)"',
    r'ProgressView\(\s*"((?:[^"\\]|\\.)*)"',
    r'description:\s*Text\(\s*\n?\s*"((?:[^"\\]|\\.)*)"',
]

found = set()
for swift in sorted(ROOT.rglob("*.swift")):
    text = swift.read_text()
    for pat in PATTERNS:
        for m in re.finditer(pat, text, re.MULTILINE):
            s = m.group(1)
            if not s:
                continue
            # Skip SF-symbol-ish identifiers (no spaces, contains dot).
            if "." in s and " " not in s:
                continue
            found.add(s)

strings = sorted(found)
if "--json" in sys.argv:
    print(json.dumps(strings, ensure_ascii=False))
else:
    for s in strings:
        print(repr(s))
    print(f"\n{len(strings)} strings", file=sys.stderr)
