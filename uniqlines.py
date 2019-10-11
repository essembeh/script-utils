#!/usr/bin/python3

import sys
from argparse import ArgumentParser
from pathlib import Path


if __name__ == "__main__":
    parser = ArgumentParser(description="uniqlines")
    parser.add_argument(
        "-f",
        "--file",
        type=Path,
        metavar="FILE",
        help="file where uniq lines are stored",
    )
    args = parser.parse_args()

    uniqs = []
    if args.file and args.file.exists():
        with args.file.open() as fp:
            for line in filter(None, map(str.strip, fp.readlines())):
                if line not in uniqs:
                    uniqs.append(line)

    try:
        for line in map(str.strip, sys.stdin):
            if len(line) > 0 and line not in uniqs:
                print(line, flush=True)
                uniqs.append(line)
    except BaseException:
        pass
    finally:
        if args.file:
            with args.file.open("w") as fp:
                fp.write("\n".join(uniqs))

