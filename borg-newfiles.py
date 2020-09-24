#!/bin/env python3

import re
import json
import subprocess
from argparse import ArgumentParser
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from subprocess import DEVNULL

from cached_property import cached_property


def sizeof_fmt(num, units=("", "K", "M", "G", "T"), suffix="B"):
    fmt = "{num:.1f}{unit}{suffix}"
    num2 = float(num)
    for unit in units:
        if abs(num2) < 1024.0:
            return fmt.format(num=num2, unit=unit, suffix=suffix)
        num2 /= 1024.0
    return fmt.format(num=num, unit="", suffix=suffix)


def borg_cmd_to_json(*cmd, multiple: bool = False):
    command = ("borg",) + tuple(map(str, cmd))
    p = subprocess.run(command, stdin=DEVNULL, check=True, capture_output=True,)
    return (
        [json.loads(line) for line in p.stdout.decode().splitlines()]
        if multiple
        else json.loads(p.stdout)
    )


@dataclass
class BorgRepository:
    folder: Path

    @cached_property
    def borg_info(self):
        return borg_cmd_to_json("info", self.folder, "--json")

    @cached_property
    def borg_list(self):
        return borg_cmd_to_json("list", self.folder, "--json")

    @cached_property
    def archives(self):
        return tuple(
            sorted(
                (BorgArchive(self, a) for a in self.borg_list["archives"]),
                key=lambda a: a.date,
            )
        )

    @cached_property
    def latest_archive(self):
        return self.archives[-1]

    def __getitem__(self, name):
        for a in self.archives:
            if a.name == name:
                return a
        raise ValueError("Cannot find archive {0}".format(name))


@dataclass
class BorgArchive:
    repo: BorgRepository
    description: dict

    @cached_property
    def borg_list(self):
        return borg_cmd_to_json("list", self, "--json-lines", multiple=True,)

    @cached_property
    def name(self):
        return self.description["name"]

    @cached_property
    def date(self):
        return datetime.fromisoformat(self.description["time"])

    @cached_property
    def files(self):
        return tuple(BorgFile(self, f) for f in self.borg_list)

    def __str__(self):
        return "{folder}::{s.name}".format(s=self, folder=self.repo.folder.resolve())


@dataclass
class BorgFile:
    archive: BorgArchive
    description: dict

    @cached_property
    def path(self):
        return self.description["path"]

    @cached_property
    def size(self):
        return int(self.description["size"])

    def is_dir(self):
        return self.description["type"] == "d"


@dataclass
class FileFilter:
    archives: list
    patterns: list

    @cached_property
    def known_files(self):
        out = set()
        for a in self.archives:
            for f in a.files:
                out.add(f.path)
        return out

    def match_pattern(self, filepath: str):
        return (
            self.patterns is None
            or len(self.patterns) == 0
            or next(filter(lambda p: p.match(filepath), self.patterns), None)
            is not None
        )

    def accept(self, bfile: BorgFile):
        return (
            not bfile.is_dir()
            and self.match_pattern(bfile.path)
            and bfile.path not in self.known_files
        )


if __name__ == "__main__":
    parser = ArgumentParser(
        prog="borg-newfiles", description="find new files from a borg archive"
    )
    parser.add_argument(
        "--version", action="version", version="version {0}".format("0.1.0")
    )
    parser.add_argument(
        "-a", "--archive", metavar="NAME", help="use this archive instead of the latest"
    )
    parser.add_argument(
        "-t", "--test", action="store_true", help="try an interactive borg info first"
    )
    parser.add_argument(
        "-i",
        "--include",
        metavar="PATTERN",
        dest="include_patterns",
        type=re.compile,
        action="append",
        help="regex pattern",
    )
    parser.add_argument(
        "-I",
        "--Include",
        metavar="PATTERN",
        dest="include_patterns",
        type=lambda x: re.compile(x, re.IGNORECASE),
        action="append",
        help="like -i but ignore case",
    )
    parser.add_argument(
        "-o",
        "--output-dir",
        metavar="FOLDER",
        type=Path,
        help="extract new files to this folder",
    )
    parser.add_argument("repo", type=Path)
    args = parser.parse_args()

    if args.test:
        subprocess.run(["borg", "info", str(args.repo)], check=True)

    repo = BorgRepository(args.repo)
    archive = repo.latest_archive if args.archive is None else repo[args.archive]

    print(
        "Searching new files in", archive, "containging", len(archive.files), "file(s)"
    )
    filefilter = FileFilter(
        [a for a in repo.archives if a.date < archive.date], args.include_patterns
    )
    newfiles = tuple(filter(filefilter.accept, archive.files))

    if len(newfiles) == 0:
        print("No new files in", archive)
    else:
        print("Found", len(newfiles), "new file(s) in", archive)
        for f in newfiles:
            print("    {path} ({size})".format(path=f.path, size=sizeof_fmt(f.size)))

        if args.output_dir:
            if not args.output_dir.exists():
                args.output_dir.mkdir(parents=True)
            if not args.output_dir.is_dir():
                raise ValueError("Invalid folder {0}".format(args.output_dir))

            print(
                "Extract",
                len(newfiles),
                " new file(s) from",
                archive,
                "to",
                args.output_dir,
            )

            subprocess.run(
                ["borg", "extract", "--list", str(archive)]
                + [f.path for f in newfiles],
                cwd=args.output_dir,
                check=True,
            )
