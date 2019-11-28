#!/usr/bin/env python3

import re
import shutil
import tempfile
from argparse import ArgumentParser
from functools import partial
from pathlib import Path
from tempfile import TemporaryDirectory
from urllib.parse import urlparse
from urllib.request import urlopen
from zipfile import ZipFile

import requests
from bs4 import BeautifulSoup
from Levenshtein import distance
from pytput import print_color, tput_format, tput_print


def url2path(url: str):
    return Path(urlparse(url).path)


class Element:
    @staticmethod
    def parse(source: str):
        value = None
        if isinstance(source, Path):
            value = source.name
        elif isinstance(source, str):
            value = url2path(source).name
        for p in [
            r"(?P<serie>.*)[. ]s(?P<season>[0-9]+)(e(?P<episode>[0-9]+))?(?P<keywords>.*)(\.(?P<extension>\w+))?",
            r"(?P<serie>.*)[. ](?P<season>[0-9]+)(x(?P<episode>[0-9]+))?(?P<keywords>.*)(\.(?P<extension>\w+))?",
        ]:
            m = re.compile(p, flags=re.IGNORECASE).fullmatch(value)
            if m is not None:
                return Element(source, m)

    def __init__(self, source, matcher):
        self.__source = source
        self.__matcher = matcher

    def __group(self, name: str, default=None, fnc: callable = None):
        out = self.__matcher.group(name)
        if out is None:
            return default
        return out if fnc is None else fnc(out)

    @property
    def source(self):
        return self.__source

    @property
    def serie(self):
        return self.__group(
            "serie",
            fnc=lambda x: " ".join(map(str.capitalize, x.replace(".", " ").split(" "))),
        )

    @property
    def s(self):
        return self.__group("season", default=0, fnc=int)

    @property
    def e(self):
        return self.__group("episode", default=0, fnc=int)

    @property
    def number(self):
        out = ""
        if self.s > 0:
            out += "S{0:02}".format(self.s)
        if self.e > 0:
            out += "E{0:02}".format(self.e)
        return out

    @property
    def keywords(self):
        return self.__group("keywords", fnc=str.upper)

    @property
    def keywords_list(self):
        value = self.keywords
        return tuple(re.findall(r"[\w']+", value)) if value else tuple()

    @property
    def keywords_txt(self):
        return ".".join(self.keywords_list)

    @property
    def extension(self):
        return self.__group("extension", fnc=str.lower)

    def is_episode(self):
        return (
            isinstance(self.serie, str)
            and self.s > 0
            and self.e > 0
            and self.extension in ("mkv", "avi", "mp4", "mpg")
        )

    def __str__(self):
        fmt = "'{s.serie}' "
        if self.s > 0:
            fmt += "S{s.s:02}"
        if self.e > 0:
            fmt += "E{s.e:02}"
        fmt += " ({s.keywords_txt})"
        return fmt.format(s=self)

    def to_color_str(self, other):
        fmt = ""
        fmt += tput_format("  (-> {0:2,yellow}) ", self.distance(other))
        fmt += "'{s.serie:%s}' " % ("green" if self.serie == other.serie else "red")
        fmt += "{s.number:%s} " % ("green" if self.number == other.number else "red")
        fmt += " " + ".".join(
            [
                tput_format(
                    "{0:%s}" % ("green" if k in other.keywords_list else "red"), k
                )
                for k in self.keywords_list
            ]
        )
        return tput_format(fmt, s=self)

    def distance(self, other):
        return (
            distance(self.serie, other.serie)
            + distance(self.number, other.number)
            + distance(
                " ".join(sorted(map(str.lower, self.keywords_list))),
                " ".join(sorted(map(str.lower, other.keywords_list))),
            )
        )


class SteuClient:
    def __init__(self, tmpdir):
        self.tmpdir = tmpdir

    @property
    def base_url(self):
        return "http://www.sous-titres.eu/series/"

    def get_serie_url(self, serie: str):
        return (self.base_url + "{0}.html").format(serie)

    def download_file(self, url: str):
        out = self.tmpdir / url2path(url).name
        if out.exists():
            return out
        with out.open("wb") as fp:
            with urlopen(url) as stream:
                fp.write(stream.read())
        return out

    def download_zip(self, url: str):
        zipfile = self.download_file(url)
        zipfolder = self.tmpdir / (zipfile.name + ".d")
        if zipfolder.exists():
            return zipfolder
        with ZipFile(zipfile) as zf:
            for member in zf.namelist():
                zf.extract(member, path=zipfolder)
        return zipfolder

    def find_all_srt(self, episode: Element) -> list:
        serie_url = self.get_serie_url(episode.serie.replace(" ", "_"))
        out = []
        for link in BeautifulSoup(requests.get(serie_url).text, "html.parser").find_all(
            "a", href=re.compile(r"download/.*\.zip")
        ):
            url = Element.parse(self.base_url + link["href"])
            if (
                url is not None
                and url.s == episode.s
                and (url.e == 0 or url.e == episode.e)
            ):
                for srt in filter(
                    None, map(Element.parse, self.download_zip(url.source).iterdir())
                ):
                    if srt.e == episode.e:
                        out.append(srt)
        return out


if __name__ == "__main__":
    parser = ArgumentParser(description="command line client for www.sous-titres.eu")
    parser.add_argument(
        "-a",
        "--auto",
        action="store_true",
        help="automatically choose the best subtitle",
    )
    parser.add_argument(
        "-f",
        "--force",
        action="store_true",
        help="overwrite subtitle if file already exists",
    )
    parser.add_argument("files", type=Path, nargs="*", help="episodes")

    args = parser.parse_args()
    with TemporaryDirectory() as tmppath:
        finder = SteuClient(Path(tmppath))
        for file in args.files:
            try:
                episode = Element.parse(file)
                if episode is None:
                    raise ValueError("Not a valid episode: {0.name}".format(file))
                tput_print("Search subtitles for {0:purple,bold}", file.name)
                subtitle = episode.source.parent / (episode.source.name + ".srt")
                if episode.source.suffix.lower() in (".mkv", ".avi", ".mpg", ".mp4"):
                    subtitle = episode.source.parent / (episode.source.stem + ".srt")
                if subtitle.exists() and not args.force:
                    raise ValueError(
                        "File {0} already exists, use --force to overwrite".format(
                            subtitle
                        )
                    )
                srtlist = sorted(
                    finder.find_all_srt(episode), key=partial(Element.distance, episode)
                )
                if len(srtlist) == 0:
                    raise ValueError("Cannot find any subtitle for {0}".format(episode))
                for i in range(0, len(srtlist)):
                    srt = srtlist[i]
                    print("[{0}]".format(i), srt.to_color_str(episode))
                selection = srtlist[0] if args.auto else None
                while selection is None:
                    print("Select a file [0-{0}] ? ".format(len(srtlist)), end="")
                    answer = input().strip()
                    try:
                        selection = srtlist[int(answer)]
                    except:
                        pass
                print("Using:", selection.source)
                if subtitle.exists():
                    tput_print("Overwrite file {0:yellow,bold}", subtitle)
                else:
                    tput_print("Create file {0:yellow,bold}", subtitle)
                shutil.copy(str(selection.source), str(subtitle))
            except BaseException as e:
                print_color("red", e)
            print()
