#!/usr/bin/env python3

import shlex
import signal
import subprocess
from argparse import ArgumentParser
from pathlib import Path
from time import sleep

from colorama import Fore


def on_signal(*args, **kwargs):
    raise TimeoutError()


signal.signal(signal.SIGALRM, on_signal)


def my_filter(iterable):
    return filter(
        lambda line: isinstance(line, str)
        and len(line) > 0
        and not line.startswith("#"),
        map(str.strip, iterable),
    )


def transition(prefix: str, label: str, interactive: bool, timeout: int):
    if timeout and timeout > 0:
        signal.alarm(timeout)
        try:
            input(
                f"{prefix} Press ENTER or wait {timeout} seconds to execute: {label} "
            )
        except TimeoutError:
            print("")
        finally:
            signal.alarm(0)
    else:
        if interactive:
            input(f"{prefix} Press ENTER to execute: {label} ")
        else:
            print(f"{prefix} Execute:  {label}")


def execute(
    command: list, label: str, retry: int, retry_delay: int = 1, verbose: bool = False
):
    process = subprocess.run(command)
    if process.returncode == 0:
        print(f"{Fore.GREEN}OK{Fore.RESET} {label}")
        return True
    print(f"{Fore.RED}ERROR{Fore.RESET} {label}")
    if retry > 0:
        sleep(retry_delay)
        return execute(command, label, retry - 1, verbose=verbose)
    return False


if __name__ == "__main__":
    parser = ArgumentParser()
    parser.add_argument(
        "-y",
        "--yes",
        dest="interactive",
        action="store_false",
        help="do not ask confirmation before executing command",
    )
    parser.add_argument(
        "-f",
        "--follow",
        dest="follow",
        action="store_true",
        help="read file line per line (useful when using a fifo as input file)",
    )
    parser.add_argument(
        "-x",
        "--execute",
        dest="command",
        metavar="COMMAND",
        default="xdg-open",
        type=shlex.split,
        help="command to execute (default is xdg-open)",
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
        help="delay between commands",
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
            f"Load {len(done_list)} items from {Fore.MAGENTA}{args.done_file}{Fore.RESET}"
        )

    try:
        count = 1
        with args.items.open() as fp:
            content = my_filter(fp) if args.follow else list(my_filter(fp.readlines()))
            for line in content:
                prefix = (
                    f"[{count}/{len(content)}]"
                    if isinstance(content, list)
                    else f"[{count}]"
                )
                command = args.command + [line]
                label = Fore.YELLOW + " ".join(map(shlex.quote, command)) + Fore.RESET
                if args.skip > 0:
                    print(f"{prefix} {Fore.CYAN}SKIP{Fore.RESET} {label}")
                    args.skip -= 1
                elif line in done_list:
                    print(f"{prefix} {Fore.CYAN}IGNORE{Fore.RESET} {label}")
                else:
                    transition(
                        prefix, label, args.interactive, args.delay if count > 1 else 0
                    )
                    if execute(command, label, args.retry, verbose=True):
                        done_list.append(line)
                count += 1
    except KeyboardInterrupt:
        pass
    finally:
        if len(done_list) > 0 and args.done_file is not None:
            with args.done_file.open("w") as fp:
                fp.write("\n".join(done_list))
            print(
                f"Save {len(done_list)} items in {Fore.MAGENTA}{args.done_file}{Fore.RESET}"
            )
