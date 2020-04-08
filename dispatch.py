#!/usr/bin/python3

import argparse
import shutil
from argparse import ArgumentParser
from pathlib import Path

from pytput import Style


def move(source, dest):
    source.rename(dest)


def copy(source, dest):
    if source.is_dir():
        shutil.copytree(str(source), str(dest))
    else:
        shutil.copy(str(source), str(dest))


def link(source, dest):
    dest.symlink_to(source.resolve())


if __name__ == "__main__":
    parser = ArgumentParser(description="File dispatcher")
    parser.add_argument(
        "-n",
        "--dryrun",
        action="store_true",
        help="dryrun mode, don't move/copy/link any file",
    )
    parser.add_argument(
        "-d",
        "--directory",
        action="store_true",
        help="also dispach directories, by default they are ignored",
    )
    group = parser.add_mutually_exclusive_group()
    group.add_argument(
        "-l",
        "--link",
        action="store_const",
        const=link,
        dest="operation",
        default=move,
        help="do symbolic links instead of moving files",
    )
    group.add_argument(
        "-c",
        "--copy",
        action="store_const",
        const=copy,
        dest="operation",
        help="copy files instead of moving them",
    )
    parser.add_argument(
        "files",
        metavar="FILE",
        nargs=argparse.ONE_OR_MORE,
        type=Path,
        help="files to move/copy/link",
    )
    parser.add_argument(
        "destdir", metavar="DEST_DIR", type=Path, help="destination folder"
    )

    args = parser.parse_args()

    if not args.destdir.is_dir():
        raise ValueError("Invalid destination directory: {0}".format(args.destdir))

    subdirs = tuple(filter(Path.is_dir, args.destdir.iterdir()))

    if len(subdirs) == 0:
        raise ValueError("Cannot find any folder in {0}".format(args.destdir))

    for source in args.files:
        if source.exists() and (args.directory or not source.is_dir()):
            candidate = next(
                iter(
                    sorted(
                        filter(
                            lambda x: source != x and source.name.startswith(x.name),
                            subdirs,
                        ),
                        key=lambda x: len(x.name),
                        reverse=True,
                    )
                ),
                None,
            )
            if candidate is None:
                print(
                    Style.RED.apply(
                        "No subdirectory for {source}".format(source=source)
                    )
                )
                continue

            dest = candidate / source.name
            if dest.exists():
                print(Style.YELLOW.apply("{dest} already exists".format(dest=dest)))
                continue

            message = "{operation} {source:} -> {dest}".format(
                operation=args.operation.__name__, source=source, dest=dest,
            )
            if args.dryrun:
                print(Style.DIM.apply("(dryrun)"), Style.CYAN.apply(message))
                continue

            try:
                args.operation(source, dest)
                print(Style.GREEN.apply(message))
            except BaseException as e:
                print(Style.RED.apply(message), Style.RED.apply(e))
