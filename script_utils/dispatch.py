#!/usr/bin/python3

import shutil
import sys
from argparse import ONE_OR_MORE, ArgumentParser
from pathlib import Path

from colorama import Fore, Style

ICON_OK = "✅"
ICON_ERROR = "🚩"
ICON_EXC = "💥"
ICON_UNKNOWN = "❓"
ICON_DRYRUN = "🙈"


def move(source, dest):
    assert source.exists() and not dest.exists()
    shutil.move(source, dest)


def copy(source, dest):
    assert source.exists() and not dest.exists()
    shutil.copy(source, dest)


def link(source, dest):
    assert source.exists() and not dest.exists()
    dest.symlink_to(source.resolve())


def plural(count: int):
    return "s" if count > 1 else ""


def label(item):
    """
    colorize item given its type
    """
    if isinstance(item, Path):
        if item.is_dir():
            return f"{Fore.BLUE}{Style.BRIGHT}{item}/{Style.RESET_ALL}"
        return f"{Style.BRIGHT}{Fore.BLUE}{item.parent}/{Fore.MAGENTA}{item.name}{Style.RESET_ALL}"
    return str(item)


def main():
    parser = ArgumentParser()
    parser.add_argument(
        "-n",
        "--dryrun",
        action="store_true",
        help="dry-run mode, do not change anything",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=Path.cwd(),
        metavar="DIR",
        help=f"dispatch files in given folder, default is {Path.cwd()}",
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
        "files",
        metavar="FILE",
        nargs=ONE_OR_MORE,
        type=Path,
        help="files to move/copy/link",
    )

    args = parser.parse_args()

    dest_folders = [d for d in args.output.iterdir() if d.is_dir()]
    count_ok, count_nodest, count_error = 0, 0, 0
    for source in filter(Path.is_file, args.files):
        candidate = max(
            [d for d in dest_folders if source.name.startswith(d.name)],
            key=lambda x: len(x.name),
            default=None,
        )
        if candidate is None:
            count_nodest += 1
            print(
                f"{ICON_UNKNOWN}  no subfolder for {label(source)} in {label(args.output)}"
            )
        else:
            dest = candidate / source.name
            if dest.exists():
                count_error += 1
                print(f"{ICON_ERROR}  destination file {label(dest)} already exists")
            elif args.dryrun:
                count_ok += 1
                print(
                    f"{ICON_DRYRUN}  {args.operation.__name__} {label(source)} to {label(candidate)} (dryrun)"
                )
            else:
                try:
                    args.operation(source, dest)
                    count_ok += 1
                    print(
                        f"{ICON_OK}  {args.operation.__name__} {label(source)} to {label(candidate)}"
                    )
                except BaseException as e:
                    count_error += 1
                    print(
                        f"{ICON_EXC}  cannot {args.operation.__name__} {label(source)} to {label(candidate)}: {Fore.RED}{e}{Fore.RESET}"
                    )

    if count_ok:
        print(
            f"    {ICON_DRYRUN if args.dryrun else ICON_OK} {count_ok} file{plural(count_ok)} {'would be ' if args.dryrun else ''}processed",
        )
    if count_nodest:
        print(
            f"    {ICON_UNKNOWN} {count_nodest} file{plural(count_nodest)} without subfolder",
        )
    if count_error:
        print(
            f"    {ICON_ERROR} {count_error} file{plural(count_error)} with error",
        )


if __name__ == "__main__":
    sys.exit(main())
