#!/usr/bin/env python3

import re
import shlex
import subprocess
from argparse import ArgumentParser
from dataclasses import dataclass
from functools import total_ordering

from colorama import Fore, Style


@dataclass
@total_ordering
class YtdlFormat:
    code: int
    extension: str
    resolution: str
    note: str

    @staticmethod
    def parse(line: str):
        match = re.fullmatch(
            r"^(?P<code>\d+)\s+(?P<extension>\w+)\s+(?P<resolution>(audio only)|(\d+x\d+))\s+(?P<note>.+)$",
            line,
        )
        if match:
            return YtdlFormat(
                int(match.group("code")),
                match.group("extension"),
                match.group("resolution"),
                match.group("note"),
            )

    def is_audio(self):
        return self.resolution == "audio only"

    def is_video(self):
        return not self.is_audio()

    def __lt__(self, other):
        if not isinstance(other, YtdlFormat):
            return NotImplemented
        if self.resolution_tuple == other.resolution_tuple:
            if self.fps == other.fps:
                if self.bitrate == other.bitrate:
                    return self.code < other.code
                return self.bitrate < other.bitrate
            return self.fps < other.fps
        return self.resolution_tuple < other.resolution_tuple

    def __str__(self):
        out = f"{Fore.YELLOW}{self.code:<3}{Fore.RESET}  "
        if self.is_audio():
            out += f"{Fore.MAGENTA}{self.extension:<6}{Fore.RESET}"
        else:
            out += f"{Fore.MAGENTA}{self.extension:>4}{Fore.RESET}/{Fore.GREEN}{self.resolution:<12}{Fore.RESET}"
        out += f"{Style.DIM}{self.note}{Style.RESET_ALL}"
        return out

    @property
    def resolution_tuple(self):
        m = re.fullmatch(r"(\d+)x(\d+)", self.resolution)
        return (int(m.group(1)), int(m.group(2))) if m else (0, 0)

    @property
    def fps(self):
        m = re.search(r"(\d+)fps", self.note)
        return int(m.group(1)) if m else 0

    @property
    def bitrate(self):
        m = re.search(r"(\d+)k", self.note)
        return int(m.group(1)) if m else 0


def user_selection(question, formats):
    if len(formats) > 0:
        while True:
            print(question)
            for f in formats:
                print(f)
            code = input()
            if len(code) == 0:
                # Select nothing
                return
            for f in formats:
                if str(f.code) == code:
                    return f


if __name__ == "__main__":
    parser = ArgumentParser("youtube-dl-interactive")
    parser.add_argument("url", nargs=1, help="URL to download")
    args, uargs = parser.parse_known_args()

    url = args.url[0]
    listformats_cmd = ["youtube-dl", "--list-formats", url]
    listformats_process = subprocess.run(
        listformats_cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL
    )
    if listformats_process.returncode == 0:
        formats = list(
            filter(
                None,
                map(
                    YtdlFormat.parse,
                    map(bytes.decode, listformats_process.stdout.splitlines()),
                ),
            )
        )
        selected_formats = [
            i.code
            for i in filter(
                None,
                (
                    user_selection(
                        "Select video format?",
                        sorted(filter(YtdlFormat.is_video, formats)),
                    ),
                    user_selection(
                        "Select audio format?",
                        sorted(filter(YtdlFormat.is_audio, formats)),
                    ),
                ),
            )
        ]

        if len(selected_formats) == 0:
            print(f"{Fore.RED}No format selected{Fore.RESET}")
            exit(3)
        download_cmd = (
            ["youtube-dl", "-f", "+".join(map(str, selected_formats))] + uargs + [url]
        )
        print(f"{Style.BRIGHT}Download video using custom formats:{Style.RESET_ALL}")
        print(f"  $ {' '.join(map(shlex.quote, download_cmd))}")
        subprocess.run(download_cmd, check=True)
    else:
        print(f"{Fore.RED}Cannot retrieve formats using command:{Fore.RESET}")
        print(f"  $ {' '.join(map(shlex.quote, listformats_cmd))}")
        exit(3)
