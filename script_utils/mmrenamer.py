#!/usr/bin/python3

import re
import shutil
from argparse import ONE_OR_MORE, ArgumentParser
from collections.abc import Iterable
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
from json import loads
from pathlib import Path
from subprocess import check_output

from colorama import Fore, Style

ICON_OK = "✅"
ICON_EXISTS = "🚩"
ICON_ERROR = "💥"
ICON_HINT = "💡"
ICON_UNKNOWN = "🚨"
ICON_DRYRUN = "🙈"

EXIF_KEYS_BY_PREFIX = {
    "image/": [
        "Composite:SubSecDateTimeOriginal",
        "Composite:SubSecCreateDate",
        "EXIF:DateTimeOriginal",
        "EXIF:CreateDate",
    ],
    "video/": [
        "QuickTime:CreationDate",
        "QuickTime:CreateDate",
        "QuickTime:MediaCreateDate",
        "QuickTime:CreationDate",
    ],
}


def label(item):
    """
    colorize item given its type
    """
    if isinstance(item, Path):
        if item.is_dir():
            return f"{Fore.BLUE}{Style.BRIGHT}{item}{Style.RESET_ALL}"
        return f"{Style.BRIGHT}{Fore.BLUE}{item.parent}/{Fore.MAGENTA}{item.name}{Style.RESET_ALL}"
    return str(item)


def visit(files: Iterable[Path], recursive: bool = False):
    """
    yield files recursively
    """
    for file in sorted(filter(lambda x: isinstance(x, Path), files)):
        if file.is_file():
            yield file
        elif file.is_dir():
            if recursive:
                yield from visit(file.iterdir(), recursive=True)
            else:
                print(
                    f"{ICON_HINT} {label(file)} is ignored, use {Fore.YELLOW}--recursive{Fore.RESET} to process directory"
                )
        else:
            print(
                f"{ICON_UNKNOWN} {label(file)} is ignored, not a file nor a directory"
            )


def parse_date(text: str) -> datetime:
    """
    exiftool date are not datetime compatible
    """
    assert len(text) >= 19, f"Invalid date {text}"
    return datetime.fromisoformat(text.replace(":", "-", 2)[0:19])


def get_create_date(file: Path):
    """
    get date prefix
    """
    if not file.exists():
        raise IOError(f"Cannot find {file}")
    payload = check_output(["exiftool", "-G", "-j", str(file)])
    payload = loads(payload)
    assert isinstance(payload, list)
    assert len(payload) == 1
    exif = payload[0]

    filetype = exif["File:MIMEType"]
    for prefix, keys in EXIF_KEYS_BY_PREFIX.items():
        if filetype.startswith(prefix):
            for key in keys:
                if key in exif:
                    return parse_date(exif[key])
            raise ValueError(f"Cannot find date for {file}")
    raise ValueError(f"Unsupported file type {filetype} for {file}")


def get_next_name(folder: Path, prefix: str, suffix: str) -> Path:
    """
    find filename which wouldn't overwrite anything in the given folder
    """
    for index in range(1, 999):
        dest = folder / f"{prefix}{index:03}{suffix.lower()}"
        if not dest.exists():
            return dest
    raise ValueError(f"Cannot find a suitable filename in {folder}")


def main():
    """
    entrypoint
    """
    parser = ArgumentParser()
    parser.add_argument(
        "-n",
        "--dryrun",
        action="store_true",
        help="dry-run mode, do not change anything",
    )
    parser.add_argument(
        "-r",
        "--recursive",
        action="store_true",
        help="visit folder content",
    )
    parser.add_argument(
        "files",
        nargs=ONE_OR_MORE,
        type=Path,
        help="files to rename",
    )
    args = parser.parse_args()
    count_already_named, count_error, count_renamed = 0, 0, 0
    with ThreadPoolExecutor() as executor:
        jobs = {
            executor.submit(lambda f: get_create_date(f), f): f
            for f in visit(args.files, recursive=args.recursive)
        }
        for job in as_completed(jobs):
            source = jobs[job]
            try:
                create_date = job.result()
                prefix = create_date.strftime("%Y-%m-%d_%Hh%Mm%Ss_")
                if source.name.startswith(prefix):
                    count_already_named += 1
                    print(f"{ICON_EXISTS} {label(source)} is already renamed")
                else:
                    target = get_next_name(source.parent, prefix, source.suffix)
                    if args.dryrun:
                        count_renamed += 1
                        print(
                            f"{ICON_DRYRUN} {label(source)} would be renamed {label(target)} {Fore.CYAN}(dryrun){Style.RESET_ALL}"
                        )
                    else:
                        shutil.move(source, target)
                        count_renamed += 1
                        print(f"{ICON_OK} {label(source)} was renamed {label(target)}")
            except KeyboardInterrupt:
                exit(1)
            except BaseException as error:  # pylint: disable=broad-except
                count_error += 1
                print(
                    f"{ICON_ERROR} cannot be renamed {label(source)}: {Fore.RED}{error}{Fore.RESET}"
                )

    if count_renamed:
        print(
            f"    {ICON_DRYRUN if args.dryrun else ICON_OK} {count_renamed} file(s) {'would be ' if args.dryrun else ''}renamed",
        )
    if count_already_named:
        print(
            f"    {ICON_EXISTS} {count_already_named} file(s) already named",
        )
    if count_error:
        print(
            f"    {ICON_ERROR} {count_error} error(s)",
        )


if __name__ == "__main__":
    exit(main())
