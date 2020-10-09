#!/usr/bin/python3

import argparse
import logging
import shutil
from argparse import ArgumentParser
from pathlib import Path


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
    group = parser.add_mutually_exclusive_group()
    group.add_argument(
        "-v",
        "--verbose",
        dest="level",
        action="store_const",
        const=logging.DEBUG,
        help="print more information",
    )
    group.add_argument(
        "-q",
        "--quiet",
        dest="level",
        action="store_const",
        const=logging.WARN,
        help="print less information",
    )
    group = parser.add_mutually_exclusive_group()
    group.add_argument(
        "-d",
        "--directory",
        action="store_true",
        help="also dispach directories, by default they are ignored",
    )
    group.add_argument(
        "-r",
        "--recursive",
        action="store_true",
        help="process content of directory given in arguments",
    )
    group = parser.add_mutually_exclusive_group()
    group.add_argument(
        "-l",
        "--link",
        dest="operation",
        action="store_const",
        const=link,
        default=move,
        help="do symbolic links instead of moving files",
    )
    group.add_argument(
        "-c",
        "--copy",
        dest="operation",
        action="store_const",
        const=copy,
        help="copy files instead of moving them",
    )
    parser.add_argument(
        "-o",
        "--output",
        metavar="FOLDER",
        dest="destdir",
        default=Path.cwd(),
        type=Path,
        help="destination folder",
    )
    parser.add_argument(
        "files",
        metavar="FILE",
        nargs=argparse.REMAINDER,
        type=Path,
        help="files to move/copy/link",
    )

    args = parser.parse_args()
    logging.basicConfig(
        level=args.level or logging.INFO, format="[%(levelname)s] %(message)s"
    )

    if not args.destdir.is_dir():
        logging.error("Invalid destination directory: {0}".format(args.destdir))
        exit(1)

    subdirs = tuple(filter(Path.is_dir, args.destdir.iterdir()))

    if len(subdirs) == 0:
        logging.error("Cannot find any folder in {0}".format(args.destdir))
        exit(1)

    def iter_items(source: Path):
        if source.exists():
            if source in subdirs:
                pass
            elif source.is_dir():
                if args.directory:
                    yield source
                elif args.recursive:
                    for i in source.iterdir():
                        yield from iter_items(i)
            else:
                yield source

    def process_file(source: Path):
        candidate = tuple(filter(lambda d: source.name.startswith(d.name), subdirs))
        if len(candidate) == 0:
            logging.warning("No foldsubdirectoryer for {0}".format(source))
        elif len(candidate) > 1:
            logging.warning("Multiple candidate for {0}".format(source))
        else:
            dest = candidate[0] / source.name
            if dest.exists():
                logging.debug(
                    "{source} already exists in {dest}".format(
                        dest=dest.parent, source=source
                    )
                )
            else:
                logging.info(
                    "{prefix}{operation} {source:} -> {dest}".format(
                        operation=args.operation.__name__,
                        source=source,
                        dest=dest,
                        prefix="(dryrun) " if args.dryrun else "",
                    )
                )
                if not args.dryrun:
                    try:
                        args.operation(source, dest)
                    except BaseException as e:
                        logging.error(e)

    for source in args.files:
        for x in iter_items(source):
            process_file(x)
