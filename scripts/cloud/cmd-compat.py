#!/usr/bin/env python3
"""Run the release checker's fixed /d /c executable invocation on Linux."""
import os
import sys

args = sys.argv[1:]
if len(args) < 3 or args[:2] != ['/d', '/c']:
    raise SystemExit('Only cmd.exe /d /c EXECUTABLE ARGS is supported')
os.execv(args[2], args[2:])
