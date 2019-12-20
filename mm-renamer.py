#!/usr/bin/python3

import argparse
import hashlib
import json
import os
import subprocess
import sys
from argparse import ArgumentParser
from collections import OrderedDict
from pathlib import Path
from string import Formatter

from pytput import Style, strcolor

CONFIG_FILE = Path(
    os.getenv("MM_RENAMER_CONF", os.path.expanduser("~/.mm-renamer.json"))
)
BUILTIN_FORMATS = OrderedDict(
    (
        (
            "default",
            "{year}{month:0>2}{day:0>2}-{hour:0>2}{min:0>2}{sec:0>2}_{md5:.7}{ext:lower}",
        ),
        ("md5", "{md5:.7}{ext:lower}"),
        ("sha1", "{sha1:.7}{ext:lower}"),
        ("lower", "{filename:lower}"),
        ("upper", "{filename:upper}"),
        ("noext", "{name}"),
    )
)

EXIFTOOL_BIN = "exiftool"
EXIFTOOL_ARGS = ("-exif:DateTimeOriginal", "-createDate")
EXIFTOOL_FMT = "_%Y_%m_%d_%H_%M_%S_"
EXIFTOOL_FIELDS = {"year": 1, "month": 2, "day": 3, "hour": 4, "min": 5, "sec": 6}
HASH_FUNC = {
    "md5": hashlib.md5,
    "sha1": hashlib.sha1,
    "sha224": hashlib.sha224,
    "sha256": hashlib.sha256,
    "sha384": hashlib.sha384,
    "sha512": hashlib.sha512,
}


def get_hash(file: Path, func: callable):
    algo = func()
    with file.open("rb") as fp:
        for chunk in iter(lambda: fp.read(4096), b""):
            algo.update(chunk)
    return algo.hexdigest()


def get_timestamp(file: Path):
    global EXIFTOOL_BIN
    if EXIFTOOL_BIN is not None:
        if "EXIFTOOL_BIN" in os.environ:
            EXIFTOOL_BIN = os.getenv("EXIFTOOL_BIN")
        try:
            for arg in EXIFTOOL_ARGS:
                cmd = [EXIFTOOL_BIN, arg, "-s3", "-d", EXIFTOOL_FMT, str(file)]
                p = subprocess.run(
                    cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL
                )
                if p.returncode == 0:
                    fields = p.stdout.decode().strip().split("_")
                    if len(fields) > max(EXIFTOOL_FIELDS.values()):
                        return dict(
                            [(k, int(fields[v])) for k, v in EXIFTOOL_FIELDS.items()]
                        )
        except FileNotFoundError:
            print(
                Style.RED.apply(
                    "Cannot find 'exiftool' in PATH, run 'sudo apt-get install libimage-exiftool-perl' or set EXIFTOOL_BIN"
                )
            )
            EXIFTOOL_BIN = None
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

    def format_field(self, value, format_spec):
        if format_spec == "lower":
            return str(value).lower()
        if format_spec == "upper":
            return str(value).upper()
        return super().format_field(value, format_spec)

    def get_value(self, key, args, kwargs):
        if key == "filename":
            return self.__file.name
        elif key == "name":
            return self.__file.stem
        elif key == "ext":
            return self.__file.suffix
        elif key == "suffixes":
            return "".join(self.__file.suffixes)
        elif key in HASH_FUNC:
            return get_hash(self.__file, HASH_FUNC[key])
        elif key in self.timestamp:
            return self.timestamp[key]
        raise ValueError("Unknwon key: " + key)


if __name__ == "__main__":
    parser = ArgumentParser(description="File renamer")
    group = parser.add_mutually_exclusive_group()
    group.add_argument(
        "-l",
        "--list-formats",
        dest="format_list",
        action="store_true",
        help="List format samples",
    )
    group.add_argument(
        "-f",
        "--format",
        dest="format_id",
        metavar="ID",
        default="default",
        help="use builtin format (see -l)",
    )
    group.add_argument(
        "-F",
        "--custom-format",
        dest="format_custom",
        metavar="FORMAT",
        help="use custom format (see python str.format and -l)",
    )
    parser.add_argument(
        "-n", "--dryrun", action="store_true", help="Dryrun mode, don't rename any file"
    )
    parser.add_argument(
        "-o",
        "--output-folder",
        dest="output_folder",
        type=Path,
        help="rename files and move them to a specific folder",
    )
    parser.add_argument(
        "files", nargs=argparse.ZERO_OR_MORE, type=Path, help="files to rename"
    )
    args = parser.parse_args()

    if CONFIG_FILE.is_file():
        print(
            strcolor("{0:cyan,bold} {1:cyan}").format(
                "Using custom configuration file:", CONFIG_FILE
            )
        )
        with CONFIG_FILE.open() as fp:
            user_formats = json.load(fp)
            BUILTIN_FORMATS.update(user_formats)

    if args.format_list:
        for k, v in BUILTIN_FORMATS.items():
            print(strcolor("  {k:>15,bold}: '{v:dim}'").format(k=k, v=v))
    else:
        for source in args.files:
            if not source.is_file():
                print(Style.RED.apply("Invalid file: {source}".format(source=source)))
                continue
            try:
                newname = MMFormatter(source).format(
                    args.format_custom or BUILTIN_FORMATS[args.format_id]
                )
                target = (args.output_folder or source.parent) / newname
                if source == target:
                    print(
                        Style.YELLOW.apply(
                            "'{source}' already named".format(source=source)
                        )
                    )
                elif target.exists():
                    print(
                        Style.RED.apply(
                            "'{source}' already exists".format(source=source)
                        )
                    )
                else:
                    style = Style.PURPLE if args.dryrun else Style.GREEN
                    print(
                        style.apply(
                            "'{source}' -> '{target}'".format(
                                source=source, target=target
                            )
                        )
                    )
                    if not args.dryrun:
                        if not target.parent.is_dir():
                            target.parent.mkdir(parents=True)
                        source.rename(target)
            except KeyboardInterrupt:
                print(Style.RED.apply("Process interrupted"))
                sys.exit(1)
            except BaseException as e:
                print(
                    Style.RED.apply(
                        "'{source}' cannot be renamed ({ex})".format(
                            source=source, ex=e
                        )
                    )
                )

