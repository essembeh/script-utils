#!/usr/bin/python3

from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import shutil
import sys
from argparse import ONE_OR_MORE, ArgumentParser, ArgumentTypeError
from pathlib import Path
from typing import Callable, Iterable

from colorama import Fore, Style

ICON_OK = "✅"
ICON_EXISTS = "🚩"
ICON_ERROR = "💥"
ICON_HINT = "💡"
ICON_UNKNOWN = "🚨"
ICON_DRYRUN = "🙈"


def plural(count: int):
    return "s" if count > 1 else ""


def noslash(text: str):
    if "/" in text:
        print(f"{Fore.RED}Path delimiter '/' cannot be used in '{text}'{Fore.RESET}")
        raise ArgumentTypeError()
    return text


def label(item):
    """
    colorize item given its type
    """
    if isinstance(item, Path):
        if item.is_dir():
            return f"{Fore.BLUE}{Style.BRIGHT}{item}{Style.RESET_ALL}"
        return f"{Style.BRIGHT}{Fore.BLUE}{item.parent}/{Fore.MAGENTA}{item.name}{Style.RESET_ALL}"
    return str(item)


def visit(files: Iterable[Path], recursive: bool = False, verbose: bool = False):
    for file in sorted(filter(lambda x: isinstance(x, Path), files)):
        if file.is_file():
            yield file
        elif file.is_dir():
            if recursive:
                yield from visit(file.iterdir(), recursive=recursive)
            else:
                if verbose:
                    print(
                        f"{ICON_HINT} {label(file)} is ignored, use {Fore.YELLOW}--recursive{Fore.RESET} to process directory"
                    )
        else:
            print(
                f"{ICON_UNKNOWN} {label(file)} is ignored, not a file nor a directory"
            )


def compute_hash(hfunc: Callable, file: Path):
    algo = hfunc()
    with file.resolve().open("rb") as fp:
        for chunk in iter(lambda: fp.read(4096), b""):
            algo.update(chunk)
    return algo.hexdigest()


def compute_filename(
    fingerprint: str,
    length: int = 0,
    prefix: str = None,
    suffix: str = None,
    extension: str = None,
):
    return (
        (prefix or "")
        + (fingerprint[0:length] if length > 0 else fingerprint)
        + (suffix or "")
        + (extension or "")
    )


def main():
    parser = ArgumentParser()
    parser.add_argument(
        "-v",
        "--verbose",
        action="store_true",
        help="print more information",
    )
    parser.add_argument(
        "-n",
        "--dryrun",
        action="store_true",
        help="dry-run mode, do not change anything",
    )
    parser.add_argument(
        "-j",
        "--jobs",
        type=int,
        metavar="THREADS",
        help="parallel jobs",
    )
    group = parser.add_mutually_exclusive_group()
    for hlabel, hfunc in (
        ("md5", hashlib.md5),
        ("sha1", hashlib.sha1),
        ("sha224", hashlib.sha224),
        ("sha256", hashlib.sha256),
        ("sha384", hashlib.sha384),
        ("sha512", hashlib.sha512),
    ):
        group.add_argument(
            f"--{hlabel}",
            dest="hfunc",
            action="store_const",
            const=hfunc,
            default=hashlib.md5,
            help=f"use {hlabel} to compute file fingerprint",
        )

    parser.add_argument(
        "-r",
        "--recursive",
        action="store_true",
        help="visit folder content",
    )
    parser.add_argument(
        "-l",
        "--len",
        dest="length",
        type=int,
        metavar="N",
        default=0,
        help="truncate fingerprint to N chars",
    )
    parser.add_argument(
        "-p",
        "--prefix",
        type=noslash,
        metavar="PREFIX",
        help="prefix filename with PREFIX",
    )
    parser.add_argument(
        "-s",
        "--suffix",
        type=noslash,
        metavar="SUFFIX",
        help="prefix filename with SUFFIX",
    )
    parser.add_argument(
        "-e",
        "--ext",
        action="store_true",
        help="append current file extension to target filename",
    )
    parser.add_argument(
        "-o",
        "--output",
        dest="folder",
        type=Path,
        help="rename files in specific folder",
    )
    parser.add_argument(
        "files",
        nargs=ONE_OR_MORE,
        type=Path,
        help="files to rename",
    )
    args = parser.parse_args()

    count_already_named, count_error, count_renamed = 0, 0, 0

    with ThreadPoolExecutor(max_workers=args.jobs) as executor:
        jobs = {
            executor.submit(compute_hash, args.hfunc, f): f
            for f in visit(args.files, recursive=args.recursive, verbose=args.verbose)
        }
        for job in as_completed(jobs):
            source = jobs[job]
            fingerprint = job.result()
            newfilename = compute_filename(
                fingerprint,
                length=args.length,
                prefix=args.prefix,
                suffix=args.suffix,
                extension=source.suffix if args.ext else None,
            )

            assert len(newfilename) > 0
            target = (args.folder or source.parent) / newfilename

            if source == target:
                count_already_named += 1
                if args.verbose:
                    print(f"{ICON_OK} {label(source)} is already renamed")
            elif target.exists():
                count_error += 1
                print(
                    f"{ICON_EXISTS} {label(source)} cannot be renamed {label(target)}: {Fore.RED}destination already exists{Fore.RESET}"
                )
            elif args.dryrun:
                count_renamed += 1
                print(
                    f"{ICON_DRYRUN} {label(source)} would be renamed {label(target)} {Fore.CYAN}(dryrun){Style.RESET_ALL}"
                )
            else:
                try:
                    if not target.parent.exists():
                        target.parent.mkdir(parents=True)
                    shutil.move(source, target)
                    count_renamed += 1
                    print(f"{ICON_OK} {label(source)} was renamed {label(target)}")
                except BaseException as e:
                    count_error += 1
                    print(
                        f"{ICON_ERROR} {label(source)} cannot be renamed {label(target)}: {Fore.RED}{e}{Fore.RESET}"
                    )

    if count_renamed:
        print(
            f"  {ICON_OK} {count_renamed} file{plural(count_renamed)} {'would be ' if args.dryrun else ''}renamed",
        )
    if count_already_named:
        print(
            f"  {ICON_OK} {count_already_named} file{plural(count_already_named)} already named",
        )
    if count_error:
        print(
            f"  {ICON_ERROR} {count_error} error{plural(count_error)}",
        )


if __name__ == "__main__":
    sys.exit(main())
