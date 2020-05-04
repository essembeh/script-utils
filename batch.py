#!/usr/bin/python3

import shlex
import subprocess
from argparse import ArgumentParser
from pathlib import Path
from time import sleep

from pytput import Style


def my_filter(iterable):
    return filter(
        lambda line: isinstance(line, str)
        and len(line.strip()) > 0
        and not line.strip().startswith("#"),
        map(str.strip, iterable),
    )


def execute(command: list, label: str, retry: int, delay: int, verbose: bool = False):
    process = subprocess.run(command)
    if process.returncode == 0:
        print(Style.GREEN.apply("OK"), label)
        return True
    if retry > 0:
        print(
            Style.YELLOW.apply(
                "RETRY {retry}/{total}".format(
                    retry=args.retry - retry + 1, total=args.retry
                )
            ),
            label,
        )
        sleep(delay)
        return execute(command, label, retry - 1, delay, verbose=verbose)
    print(Style.RED.apply("ERROR"), label)
    return False


if __name__ == "__main__":
    parser = ArgumentParser()
    parser.add_argument(
        "-y",
        "--yes",
        dest="non_interactive",
        action="store_true",
        help="do not ask confirmation before executing command",
    )
    parser.add_argument(
        "-x",
        "--execute",
        dest="command",
        metavar="COMMAND",
        default="xdg-open",
        type=shlex.split,
        help="command to execute",
    )
    parser.add_argument(
        "--done",
        dest="done_file",
        type=Path,
        metavar="FILE",
        help="file containing items already processed",
    )
    parser.add_argument(
        "--sleep",
        dest="delay",
        metavar="SECONDS",
        type=int,
        default=0,
        help="delay before commands",
    )
    parser.add_argument(
        "--skip",
        dest="skip",
        metavar="N",
        type=int,
        default=0,
        help="skip N first elements",
    )
    parser.add_argument(
        "--retry",
        dest="retry",
        metavar="N",
        type=int,
        default=3,
        help="retry N times in case of error (default is 0)",
    )
    parser.add_argument(
        "items", type=Path, metavar="FILE", help="file containing elements to open"
    )
    args = parser.parse_args()

    done_list = []

    if args.done_file is not None and args.done_file.is_file():
        with args.done_file.open() as fp:
            for line in my_filter(fp):
                if line not in done_list:
                    done_list.append(line)
        print(
            "Load {count} items from {file}".format(
                file=Style.PURPLE.apply(args.done_file), count=len(done_list)
            )
        )

    try:
        with args.items.open() as fp:
            for line in my_filter(fp):
                command = args.command + [line]
                label = Style.DIM.apply(" ".join(map(shlex.quote, command)))
                if args.skip > 0:
                    print(Style.CYAN.apply("Skip"), label)
                    args.skip -= 1
                elif line in done_list:
                    print(Style.CYAN.apply("Ignore"), label)
                else:
                    if args.non_interactive or input(
                        "Execute {label} (Y/n) ".format(label=label)
                    ).strip().lower() in ("", "y"):
                        if execute(
                            command, label, args.retry, args.delay, verbose=True
                        ):
                            done_list.append(line)
                sleep(args.delay)
    except KeyboardInterrupt:
        pass
    finally:
        if len(done_list) > 0 and args.done_file is not None:
            with args.done_file.open("w") as fp:
                fp.write("\n".join(done_list))
            print(
                "Save {count} items in {file}".format(
                    file=Style.PURPLE.apply(args.done_file), count=len(done_list)
                )
            )
