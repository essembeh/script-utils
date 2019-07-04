#!/usr/bin/env python3

import argparse
import os
import subprocess
import sys
from argparse import ArgumentParser
from pathlib import Path
from tempfile import TemporaryDirectory

from termicolor import tc_print

COMMMANDS = (("x", "exit"), ("q", "umount and exit"), ("o", "xdg-open"), ("s", "shell"), ("m", "mount"), ("u", "umount"))


def execute(*command, cwd=None):
    cmd = [str(c) for c in command]
    tc_print("[{label:fg_green}] {cmd:fg_yellow}", label="exec", cmd=" ".join(cmd))
    subprocess.check_call(cmd, cwd=None if cwd is None else str(cwd))


if __name__ == "__main__":
    parser = ArgumentParser(description="Helper to mount temporary folders")
    parser.add_argument("--binary", action="store", help="binary to use for mount operation")
    parser.add_argument("extra_args", nargs=argparse.ONE_OR_MORE, help="arguments to pass to the mount command")
    args = parser.parse_args()

    # Get mount binary
    binary = args.binary
    if binary is None:
        prog = Path(sys.argv[0]).name
        if not prog.startswith("ez"):
            raise ValueError("Cannot find binary")
        binary = prog[2:]
    # Test mount binary
    subprocess.check_call([binary, "--version"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    # Create mountpoint
    mountpoint = None
    with TemporaryDirectory(prefix="ezmount-{0}-".format(binary), dir=".") as td:
        mountpoint = Path(td)
    mountpoint.mkdir()
    tc_print("[{label:fg_green}] Using mountpoint {mnt:fg_blue}", label="info", mnt=mountpoint)
    # Mount
    execute(binary, *args.extra_args, mountpoint)
    mounted = True
    # Question loop
    actions = [a for a, _ in COMMMANDS]
    while True:
        print()
        for cmd, desc in COMMMANDS:
            tc_print("{cmd:bold}: {desc:half_bright}", cmd=cmd, desc=desc)
        action = None
        while action not in actions:
            action = input("[{0}] ".format("/".join(actions))).strip().lower()
        print()
        # Mount/Umount
        if mounted and action in ("q", "u"):
            execute("fusermount", "-u", "-z", mountpoint)
            mounted = False
        elif not mounted and action in ("m", "o", "s"):
            execute(binary, *args.extra_args, mountpoint)
            mounted = True

        if action == "o":
            execute("xdg-open", mountpoint)
        elif action == "s":
            execute(os.getenv("SHELL", "bash"), cwd=mountpoint)

        if action in ("x", "q"):
            if not mounted:
                tc_print("[{label:fg_green}] Remove mountpoint {mnt:fg_blue}", label="info", mnt=mountpoint)
                mountpoint.rmdir()
            else:
                tc_print("[{label:fg_green}] Keeping mountpoint {mnt:fg_blue}", label="info", mnt=mountpoint)
            sys.exit(0)
