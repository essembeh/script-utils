#!/usr/bin/env python3

import re
import shutil
from argparse import ArgumentParser
from dataclasses import dataclass
from functools import partial
from pathlib import Path
from tempfile import TemporaryDirectory
from urllib.parse import urlparse
from urllib.request import urlopen
from zipfile import ZipFile

from bs4 import BeautifulSoup
from Levenshtein import distance

import requests
from pytput import strcolor
from pytput.style import Style

VIDEO_EXTENSIONS = ("mkv", "mp4", "avi", "mpg", "mpeg", "mov")


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
            r"(?P<serie>.*)[. ]s(?P<season>[0-9]+)(e(?P<episode>[0-9]+))?(?P<keywords>.*)\.(?P<extension>\w+)",
            r"(?P<serie>.*)[. ](?P<season>[0-9]+)(x(?P<episode>[0-9]+))?(?P<keywords>.*)\.(?P<extension>\w+)",
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
    def srt_file(self):
        return self.source.parent / (self.source.stem + ".srt")

    @property
    def serie(self):
        return self.__group(
            "serie",
            fnc=lambda x: " ".join(map(str.capitalize, x.replace(".", " ").split(" "))),
        )

    @property
    def season(self):
        return self.__group("season", default=0, fnc=int)

    @property
    def episode(self):
        return self.__group("episode", default=0, fnc=int)

    @property
    def number_label(self):
        out = ""
        if self.season > 0:
            out += "S{0:02}".format(self.season)
        if self.episode > 0:
            out += "E{0:02}".format(self.episode)
        return out

    @property
    def keywords(self):
        return self.__group("keywords", fnc=str.upper)

    @property
    def keywords_list(self):
        value = self.keywords
        return tuple(re.findall(r"[\w']+", value)) if value else ()

    @property
    def keywords_txt(self):
        return ".".join(self.keywords_list)

    @property
    def extension(self):
        return self.__group("extension", fnc=str.lower)

    def is_episode(self):
        return (
            isinstance(self.serie, str)
            and self.season > 0
            and self.episode > 0
            and self.extension in VIDEO_EXTENSIONS
        )

    def __str__(self):
        fmt = "'{s.serie}' "
        if self.season > 0:
            fmt += "S{s.season:02}"
        if self.episode > 0:
            fmt += "E{s.episode:02}"
        fmt += " ({s.keywords_txt})"
        return fmt.format(s=self)

    def to_color_str(self, other):
        def withstyle(text, cond):
            s = Style.GREEN if cond else Style.RED
            return s.apply(text)

        out = ""
        out += strcolor("(d={0:2,yellow}) ").format(self.distance(other))

        out += "'{0}' {1}  ".format(
            withstyle(self.serie, self.serie == other.serie),
            withstyle(self.number_label, self.number_label == other.number_label),
        )
        out += " " + ".".join(
            map(lambda k: withstyle(k, k in other.keywords_list), self.keywords_list)
        )
        return out

    def distance(self, other):
        return (
            distance(self.serie, other.serie)
            + distance(self.number_label, other.number_label)
            + distance(
                " ".join(sorted(map(str.lower, self.keywords_list))),
                " ".join(sorted(map(str.lower, other.keywords_list))),
            )
        )


@dataclass
class SteuClient:
    tmpdir: Path

    @property
    def base_url(self):
        return "http://www.sous-titres.eu/series/"

    def get_serie_url(self, serie_name: str):
        return (self.base_url + "{0}.html").format(serie_name)

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

    def find_all_srt(self, serie: str, season: int, episode: int) -> list:
        serie_url = self.get_serie_url(serie.replace(" ", "_"))
        out = []
        for link in BeautifulSoup(requests.get(serie_url).text, "html.parser").find_all(
            "a", href=re.compile(r"download/.*\.zip")
        ):
            url_element = Element.parse(self.base_url + link["href"])
            if (
                url_element is not None
                and url_element.season == season
                and (url_element.episode == 0 or url_element.episode == episode)
            ):
                out += list(
                    filter(
                        lambda x: x is not None and x.episode == episode,
                        map(
                            Element.parse,
                            self.download_zip(url_element.source).iterdir(),
                        ),
                    )
                )
        return out


@dataclass
class SubtitleDownloader:

    steucli: SteuClient

    def handle_file(
        self, element: Element, auto_choose: bool = True, serie_name: str = None,
    ):
        print("Search subtitles for", strcolor("{0:purple,bold}").format(file.name))
        subtitle = element.srt_file
        srtlist = sorted(
            self.steucli.find_all_srt(
                serie_name or element.serie, element.season, element.episode
            ),
            key=partial(Element.distance, element),
        )
        if len(srtlist) == 0:
            raise ValueError("Cannot find any subtitle for {0}".format(element))
        for i in range(0, len(srtlist)):
            srt = srtlist[i]
            print("[{0}]".format(i), srt.to_color_str(element))
        selection = srtlist[0] if auto_choose else None
        while selection is None:
            print("Select a file [0-{0}] ? ".format(len(srtlist)), end="")
            answer = input().strip()
            try:
                selection = srtlist[int(answer)]
            except BaseException:
                pass
        print("Using:", selection.source)
        if subtitle.exists():
            print("Overwrite file", strcolor("{0:yellow,bold}").format(subtitle))
        else:
            print("Create file", strcolor("{0:yellow,bold}").format(subtitle))
        shutil.copy(str(selection.source), str(subtitle))
        print("")


if __name__ == "__main__":
    parser = ArgumentParser(description="command line client for www.sous-titres.eu")
    parser.add_argument(
        "-a",
        "--auto",
        dest="auto_choose",
        action="store_true",
        help="automatically choose the best subtitle",
    )
    parser.add_argument(
        "-r",
        "--recursive",
        action="store_true",
        help="process all files contained in folders",
    )
    parser.add_argument(
        "-f",
        "--force",
        dest="overwrite",
        action="store_true",
        help="overwrite subtitle if file already exists",
    )
    parser.add_argument(
        "-N", "--name", dest="serie_name", help="force serie name for given episodes"
    )

    parser.add_argument("files", type=Path, nargs="*", help="episodes")
    args = parser.parse_args()
    visited = []

    def myvisitor(files):
        for f in files:
            if isinstance(f, Path) and f not in visited:
                visited.append(f)
                if f.is_dir():
                    if args.recursive:
                        yield from myvisitor(sorted(f.iterdir()))
                else:
                    yield f

    with TemporaryDirectory() as tmppath:
        downloader = SubtitleDownloader(SteuClient(Path(tmppath)))
        for file in myvisitor(args.files):
            try:
                episode = Element.parse(file)
                if episode and episode.is_episode():
                    if args.overwrite or not episode.srt_file.exists():
                        downloader.handle_file(
                            episode,
                            auto_choose=args.auto_choose,
                            serie_name=args.serie_name,
                        )
            except KeyboardInterrupt:
                exit(1)
            except BaseException as e:
                print(Style.RED.apply(e))
                print()
