#!/usr/bin/python3
'''
Pluzz client
'''
from argparse import ArgumentParser
from argparse import RawDescriptionHelpFormatter
import argparse
from collections import OrderedDict
from datetime import timedelta, datetime
import json
import os
from pathlib import Path
import pprint
import re
import requests
from string import Formatter
import subprocess
import sys


CACHE_FILE = Path(os.path.expanduser("~")) / '.cache' / 'plooze' / 'cache.json'
CONTENT_URL_PREFIX = "http://pluzz.webservices.francetelevisions.fr/pluzz/liste/type/replay/nb/10000/chaine/"
DETAILS_URL = "http://webservices.francetelevisions.fr/tools/getInfosOeuvre/v2/?idDiffusion={id_diffusion}&catalogue=Pluzz"
DEFAULT_OUTPUT_FORMAT = "{titre}/{soustitre|id_diffusion}.mp4"
CHANNELS = ["france2",
            "france3",
            "france4",
            "france5",
            "franceo"]
Q_DICT = {"best":    (1024, 576),
          "average": (512, 288),
          "low":     (320, 180),
          "lowest":  (256, 144)}


def ffmpegDownload(url, output):
    try:
        subprocess.check_call(["ffmpeg", "-version"],
                              stdout=subprocess.DEVNULL,
                              stderr=subprocess.DEVNULL)
    except Exception as e:
        print("Cannot use ffmpeg, you need to install it:", file=sys.stderr)
        print("$ sudo apt-get install ffmpeg", file=sys.stderr)
        sys.exit(1)

    if not output.parent.is_dir():
        output.parent.mkdir(parents=True)
    tmpFile = output.parent / (output.name + ".part")
    command = ["ffmpeg"]
    command += ["-i", url]
    command += ["-c", "copy"]
    command += ["-f", "mp4"]
    command += ["-loglevel", "warning"]
    command += ["-y", "file:%s" % tmpFile]
    command = [str(i) for i in command]
    try:
        subprocess.check_call(command)
        tmpFile.rename(output)
        print("File downloaded", output)
    except Exception as e:
        print("Clean temp file", tmpFile)
        os.remove(str(tmpFile))
        raise e


class JsonObject():
    def __init__(self, json):
        self.json = json

    def jsonpath(self, *path, default=None):
        currentNode = self.json
        for p in path:
            if isinstance(currentNode, dict) and p in currentNode:
                currentNode = currentNode.get(p, default)
            else:
                return default
        return currentNode

    def format(self, fmt, failOnEmpty=False):
        class MyFormatter(Formatter):
            def get_value(self, key, args, kwargs):
                if '|' in key:
                    for kk in key.split('|'):
                        out = Formatter.get_value(self, kk, args, kwargs)
                        if out is not None and len(out) > 0:
                            return out
                out = Formatter.get_value(self, key, args, kwargs)
                if failOnEmpty and (out is None or len(out) == 0):
                    raise ValueError("Cannot resolve %s" % key)
                return out
        return MyFormatter().format(fmt, **self.json)


class Episode(JsonObject):

    def __init__(self, json):
        JsonObject.__init__(self, json)

    def matches(self, epFilters):
        for f in epFilters:
            if not f.matches(self):
                return False
        return True

    def getId(self):
        return self.json["id_diffusion"]

    def getDuration(self):
        if 'duree' in self.json:
            return int(self.json['duree'])

    def getFilename(self, fmt):
        return self.format(fmt, failOnEmpty=True)

    def getDetails(self):
        detailsUrl = self.format(DETAILS_URL, failOnEmpty=True)
        return EpisodeDetails(requests.get(detailsUrl).json())

    def display(self, verbose):
        if verbose is None or verbose == 0:
            print(self.format(
                "[{id_diffusion}] {titre}: {soustitre} ({duree} min)"))
        elif verbose == 1:
            print(self.format("Title       : {titre}, {soustitre}"))
            print(self.format("Genre       : {genre_simplifie}, {genre}"))
            print(self.format("Duration    : {duree} min"))
            print(self.format("Channel     : {chaine_label}"))
            print(self.format("Date        : {date_diffusion}"))
            print(self.format("ID          : {id_diffusion}"))
            print(self.format("Description : {accroche|accroche_programme}"))
        else:
            pprint.pprint(self.json, indent=4)


class EpisodeFilter():

    @staticmethod
    def byId(epid):
        return EpisodeFilter(motif=epid,
                             exact=True,
                             fields=["id_diffusion"])

    @staticmethod
    def byText(motif):
        return EpisodeFilter(motif=motif,
                             fields=["id_diffusion",
                                     "titre",
                                     "soustitre",
                                     "accroche",
                                     "accroche_programme"])

    @staticmethod
    def byGenre(motif):
        return EpisodeFilter(motif=motif,
                             fields=["genre",
                                     "format",
                                     "genre_simplifie",
                                     "genre_filtre"])

    @staticmethod
    def byDuration(dmin, dmax):
        return EpisodeFilter(dmin=dmin,
                             dmax=dmax)

    def __init__(self, motif=None, exact=False, fields=None, dmin=None, dmax=None):
        self.motif = motif
        self.exact = exact
        self.fields = fields
        self.dmin = dmin
        self.dmax = dmax

    def matches(self, jo):
        return self.matchesDuration(jo) and self.matchesKwords(jo)

    def matchesDuration(self, ep):
        if self.dmin is not None or self.dmax is not None:
            duration = ep.getDuration()
            if duration is not None:
                if self.dmin is not None and duration < self.dmin:
                    return False
                if self.dmax is not None and duration > self.dmax:
                    return False
        return True

    def matchesKwords(self, ep):
        if self.motif is None or self.fields is None:
            return True
        for f in self.fields:
            if self.exact:
                if self.motif == ep.json.get(f):
                    return True
            else:
                if self.motif.lower() in ep.jsonpath(f, default="").lower():
                    return True
        return False


class EpisodeDetails(JsonObject):

    def __init__(self, json):
        JsonObject.__init__(self, json)

    def getPlaylist(self):
        for pl in self.jsonpath('videos', default=[]):
            if pl['format'] == 'hls_v5_os':
                return Playlist(pl)
        raise ValueError("Cannot find hls_v5_os playlist")


class Playlist(JsonObject):

    COMMENT_PATTERN = re.compile(
        '#EXT-X-STREAM.*RESOLUTION=([0-9]+)x([0-9]+).*')

    def __init__(self, json):
        JsonObject.__init__(self, json)

    def getUrls(self, https=False):
        plUrl = self.json["url"]
        if https and 'url_secure' in self.json:
            plUrl = self.json['url_secure']
        i = requests.get(plUrl).iter_lines()
        out = OrderedDict()
        for line in i:
            m = Playlist.COMMENT_PATTERN.match(line.decode())
            if m is not None:
                out[(int(m.group(1)), int(m.group(2)))] = next(i).decode()
        return out

    def getUrl(self, https=False, quality=None):
        urls = self.getUrls(https)
        if quality is not None and quality not in urls:
            print("Cannot find quality", quality)
            quality = None
        if quality is None:
            for q in urls.keys():
                if quality is None or q > quality:
                    quality = q
        print("Selected quality", "x".join(map(str, quality)))
        return urls.get(quality)

    def download(self, output, quality=None, https=False):
        print("Downloading", output)
        ffmpegDownload(self.getUrl(https, quality), output)


class PloozeApp():

    def __init__(self):
        pass

    def fetchContent(self, forceRefresh=False):
        if not CACHE_FILE.parent.is_dir():
            CACHE_FILE.parent.mkdir(parents=True)
        if CACHE_FILE.exists():
            if forceRefresh:
                print("Force refresh")
                os.remove(str(CACHE_FILE))
            elif datetime.fromtimestamp(CACHE_FILE.stat().st_mtime) < datetime.now() - timedelta(days=1):
                print("Cache is outdated")
                os.remove(str(CACHE_FILE))
        if not CACHE_FILE.exists():
            data = {}
            for chanId in CHANNELS:
                url = CONTENT_URL_PREFIX + chanId
                print("Fetch content", url)
                data[chanId] = requests.get(url).json()
            with open(str(CACHE_FILE), 'w') as fp:
                json.dump(data, fp)

    def getAllEpisodes(self):
        out = []
        with open(str(CACHE_FILE), 'r') as fp:
            cache = json.load(fp)
            for content in cache.values():
                for ep in JsonObject(content).jsonpath("reponse",
                                                       "emissions",
                                                       default=[]):
                    out.append(Episode(ep))
        print("%d episodes available" % len(out))
        return out

    def findEpisodes(self, epfilters):
        out = []
        epList = self.getAllEpisodes()
        for ep in epList:
            if ep.matches(epfilters):
                out.append(ep)
        return out


def main():
    parser = ArgumentParser(description="Pluzz client",
                            formatter_class=RawDescriptionHelpFormatter)

    parser.add_argument('-u', '--update',
                        dest="forceUpdate",
                        action='store_true',
                        help="force cache refresh")

    parser.add_argument('-v', '--verbose',
                        dest="verbose",
                        action='count',
                        help="more verbose")

    parser.add_argument('--force',
                        dest="force",
                        action='store_true',
                        help="force download if file already exists")

    parser.add_argument('-d', '--download',
                        dest="outputFolder",
                        type=Path,
                        help="download files in given folder")

    parser.add_argument('--format',
                        dest="outputFormat",
                        default=DEFAULT_OUTPUT_FORMAT,
                        help="output format, default: " + DEFAULT_OUTPUT_FORMAT)

    parser.add_argument('-g', '--genre',
                        dest="genre",
                        help="search by genre")

    parser.add_argument('-q', '--quality',
                        dest="quality",
                        choices=Q_DICT.keys(),
                        help="quality")

    parser.add_argument('-dmin', '--duration-min',
                        type=int,
                        dest="dmin",
                        default=None,
                        help="duration min in minutes")

    parser.add_argument('-dmax', '--duration-max',
                        type=int,
                        dest="dmax",
                        default=None,
                        help="duration max in minutes")

    parser.add_argument('motifList',
                        nargs=argparse.REMAINDER)

    args = parser.parse_args()

    app = PloozeApp()
    app.fetchContent(args.forceUpdate)

    epFilters = []
    epFilters.append(EpisodeFilter.byDuration(args.dmin, args.dmax))
    if args.genre is not None:
        epFilters.append(EpisodeFilter.byGenre(args.genre))
    if args.motifList is not None:
        epFilters += map(EpisodeFilter.byText, args.motifList)

    epList = app.findEpisodes(epFilters)
    print("%d episode(s) matching" % len(epList))
    print("")
    for ep in sorted(epList, key=Episode.getId):
        if args.outputFolder is None:
            ep.display(args.verbose)
            if args.verbose:
                print("")
        else:
            epd = ep.getDetails()
            outputFile = args.outputFolder / ep.getFilename(args.outputFormat)
            if outputFile.exists():
                print("File already exists", outputFile)
            if args.force or not outputFile.exists():
                epd.getPlaylist().download(outputFile,
                                           quality=Q_DICT.get(args.quality, None))
            print("")
    return 0


if __name__ == "__main__":
    sys.exit(main())
