#!/usr/bin/python3
"""
Yet another command line gif creator using FFMpeg/ImageMagick ;)
"""
from argparse import ArgumentParser
from argparse import RawDescriptionHelpFormatter
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

GIFMESOME_DEBUG = os.environ.get("GIFMESOME_DEBUG", None)

DEFAULT_START = 0
DEFAULT_DURATION = 10
DEFAULT_WIDTH = 320
DEFAULT_COLORS = 0
DEFAULT_FPS = 10

FFMPEG_COMMAND = ["ffmpeg"]
MOGRIFY_COMMAND = ["mogrify"]
CONVERT_COMMAND = ["convert", "-coalesce", "-layers", "optimize"]
GIFSICLE_COMMAND = ["gifsicle", "-b", "-O2"]


def executeCommand(command):
    command = [str(i) for i in command]
    print(" ".join(command))
    subprocess.check_call(
        command,
        stdout=subprocess.DEVNULL if GIFMESOME_DEBUG is None else None,
        stderr=subprocess.DEVNULL if GIFMESOME_DEBUG is None else None,
    )


def getExtraArgs(envvarname):
    value = os.environ.get(envvarname, None)
    if value is not None:
        return value.split()
    return []


def extractFrames(inputFile, outputFolder, fps, start, duration):
    if fps <= 0:
        raise ValueError("fps must be > 0")
    command = FFMPEG_COMMAND + getExtraArgs("FFMPEG_ARGS")
    command += ["-i", inputFile]
    command += ["-r", fps]
    if start is not None:
        command += ["-ss", start]
    if duration is not None:
        command += ["-t", duration]
    command.append(str(outputFolder) + "/%06d.png")
    executeCommand(command)


def resizeImages(imageFolder, width):
    if width > 0:
        command = MOGRIFY_COMMAND + getExtraArgs("MOGRIFY_ARGS")
        command += ["-resize", width]
        command += [str(imageFolder) + "/*png"]
        executeCommand(command)


def generateGif(imageFolder, outputFile, fps, colors):
    command = CONVERT_COMMAND + getExtraArgs("CONVERT_ARGS")
    command += ["-delay", "1x%d" % fps]
    if colors > 0:
        command += ["-colors", colors]
    command += [str(imageFolder) + "/*png", outputFile]
    executeCommand(command)


def optimizeGif(inputFile):
    command = GIFSICLE_COMMAND + getExtraArgs("GIFSICLE_ARGS")
    command += [inputFile]
    executeCommand(command)


def main():
    parser = ArgumentParser(
        description="Gif creator", formatter_class=RawDescriptionHelpFormatter
    )
    parser.add_argument("-i", "--input", type=Path, required=True, help="input file")

    parser.add_argument(
        "-o", "--output", type=Path, help="output file or output folder"
    )

    parser.add_argument(
        "-k",
        "--keep",
        action="store_true",
        help="Keep working folder (something like $PWD/gif-12345678)",
    )

    parser.add_argument(
        "-f",
        "--force",
        action="store_true",
        help="Overwrite output file if already exists",
    )

    parser.add_argument(
        "-ss",
        "--start",
        default=DEFAULT_START,
        help="start time (ffmpeg format): 10, 1:12, 17:5.2, default: %d"
        % DEFAULT_START,
    )

    parser.add_argument(
        "-t",
        "--duration",
        default=DEFAULT_DURATION,
        help="duration time (ffmpeg format): 10, 1:12, 17:5.2, 0 means all video, default: %d"
        % DEFAULT_DURATION,
    )

    parser.add_argument(
        "-w",
        "--width",
        default=DEFAULT_WIDTH,
        type=int,
        help="video width in pixel, 0 means no resize, default: %d" % DEFAULT_WIDTH,
    )

    parser.add_argument(
        "-c",
        "--colors",
        default=DEFAULT_COLORS,
        type=int,
        help="video colors, 0 means disable color management, default: %d"
        % DEFAULT_COLORS,
    )

    parser.add_argument(
        "-r",
        "--fps",
        default=DEFAULT_FPS,
        type=int,
        help="video frame per second, default: %d" % DEFAULT_FPS,
    )

    parser.add_argument(
        "-O", "--optimize", action="store_true", help="use gifsicle to optimize gif"
    )
    args = parser.parse_args()
    currentFolder = Path(os.getcwd())
    workingFolder = currentFolder / ("gif-%d" % (time.time()))
    workingFolder.mkdir()
    try:
        outputFile = None
        if args.output is None:
            outputFile = currentFolder / (str(args.input.name) + ".gif")
        elif args.output.is_dir():
            outputFile = args.output / (str(args.input.name) + ".gif")
        else:
            outputFile = args.output
        if outputFile.exists():
            print("File already exists", outputFile, file=sys.stderr)
            if not args.force:
                return 1
        extractFrames(args.input, workingFolder, args.fps, args.start, args.duration)
        resizeImages(workingFolder, args.width)
        generateGif(workingFolder, outputFile, args.fps, args.colors)
        if args.optimize:
            optimizeGif(outputFile)
        size = outputFile.stat().st_size
        size_text = "%d KB" % (size / 1024)
        print(outputFile, "generated:", size_text)
    finally:
        if not args.keep:
            shutil.rmtree(str(workingFolder))
    return 0


if __name__ == "__main__":
    sys.exit(main())
