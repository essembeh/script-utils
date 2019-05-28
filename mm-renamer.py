#!/usr/bin/python3

import argparse
import hashlib
import os
import subprocess
import sys
from argparse import ArgumentParser
from pathlib import Path
from string import Formatter

from termicolor import print_red, print_green, print_style, Color

BUILTIN_FORMATS = (
    "{year}{month:0>2}{day:0>2}-{hour:0>2}{min:0>2}{sec:0>2}_{md5:.7}.{ext}", 
    "{md5:.7}.{ext}"
)
SAMPLE_FORMATS = (
    "{year}-{month:0>2}-{day:0>2} {hour:0>2}:{min:0>2}:{sec:0>2} {name}.{ext}", 
    "{sha1}.{ext}",
    "{name} ({sha512:.3}).{ext}"
)
EXIFTOOL_ARGS = ("-exif:DateTimeOriginal", "-createDate")
EXIFTOOL_FMT = '_%Y_%m_%d_%H_%M_%S_'
EXIFTOOL_FIELDS = {
    "year": 1,
    "month": 2,
    "day": 3,
    "hour": 4,
    "min": 5,
    "sec": 6
}
HASH_FUNC = {
    "md5": hashlib.md5,
    "sha1": hashlib.sha1,
    "sha224": hashlib.sha224,
    "sha256": hashlib.sha256,
    "sha384": hashlib.sha384,
    "sha512": hashlib.sha512
}


def get_hash(file: Path, func: callable):
    algo = func()
    with file.open("rb") as fp:
        for chunk in iter(lambda: fp.read(4096), b""):
            algo.update(chunk)
    return algo.hexdigest()


def get_timestamp(file: Path):
    for arg in EXIFTOOL_ARGS:
        p = subprocess.run([os.getenv("EXIFTOOL_BIN", "exiftool"), arg, "-s3", "-d", EXIFTOOL_FMT, str(
            file)], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        if p.returncode == 0:
            fields = p.stdout.decode().strip().split("_")
            if len(fields) > max(EXIFTOOL_FIELDS.values()):
                return dict([(k, int(fields[v])) for k, v in EXIFTOOL_FIELDS.items()])
    return {}


class MMFormatter(Formatter):
    def __init__(self, file: Path, *args, **kwargs):
        Formatter.__init__(self, *args, **kwargs)
        self.__file = file
        self.__timestamp = None

    @property
    def timestamp(self):
        if self.__timestamp is None:
            self.__timestamp = get_timestamp(self.__file)
        return self.__timestamp

    def get_value(self, key, args, kwargs):
        if key == "filename":
            return self.__file.name
        elif key == "name":
            return self.__file.stem
        elif key == "ext":
            return ".".join(map(lambda e: e[1:], self.__file.suffixes))
        elif key in HASH_FUNC:
            return get_hash(self.__file, HASH_FUNC[key])
        elif key in self.timestamp:
            return self.timestamp[key]
        raise ValueError("Unknwon key: " + key)


if __name__ == "__main__":
    parser = ArgumentParser(description="File renamer")
    parser.add_argument('-F', '--list-formats', action='store_true', help="List format samples")
    parser.add_argument('-f', '--format', action='append', dest="formats", type=str, metavar="FORMAT", help="the formats to rename given files (see python str.format)")
    parser.add_argument('-n', '--dryrun', action='store_true', help="Dryrun mode, don't rename any file")
    parser.add_argument("files", nargs=argparse.ZERO_OR_MORE, type=Path, help="files to rename")
    args = parser.parse_args()

    if args.list_formats:
        print("Builtin formats:")
        for f in BUILTIN_FORMATS:
            print(" -f '" + f + "'")
        print("Sample formats:")
        for f in SAMPLE_FORMATS:
            print(" -f '" + f + "'")
    else:
        for source in args.files:
            if not source.is_file():
                print_red("Invalid file: {source}".format(source=source))
                continue
            formatter = MMFormatter(source)
            for f in args.formats or BUILTIN_FORMATS:
                try:
                    newname = formatter.format(f)
                    if newname == source.name:
                        print_style("File already named: {newname}".format(newname=newname), fg_color=Color.YELLOW)
                    else:
                        target = source.parent / newname
                        if target.exists():
                            print_red("Target already exists: {target}".format(target=target))
                        else:
                            print_green("Rename file: {source} --> {target}".format(source=source, target=target))
                            if not args.dryrun:
                                source.rename(target)
                    break
                except ValueError:
                    pass
