#!/bin/env python3
import argparse
import os
import shlex
import subprocess
import sys
from argparse import ArgumentParser
from pathlib import Path

if __name__ == "__main__":
    parser = ArgumentParser()
    parser.add_argument(
        "-d",
        "--repodir",
        dest="borg_repo_dir",
        type=Path,
        metavar="DIR",
        help="path to borg repository",
    )
    parser.add_argument(
        "-t",
        "--tty",
        dest="tty",
        action="store_true",
        help="force pseudo-terminal allocation for ssh connection (might be required to accept ssh fingerprints)",
    )
    parser.add_argument(
        "-y",
        "--yes",
        dest="non_interactive",
        action="store_true",
        help="do not ask confirmation before executing command",
    )
    parser.add_argument(
        "--args",
        dest="args_file",
        type=Path,
        metavar="FILE",
        help="use borg arguments from file",
    )
    parser.add_argument(
        "-p",
        "--remote-port",
        dest="remote_port",
        type=int,
        default=22,
        metavar="PORT",
        help="remote server ssh port",
    )
    parser.add_argument(
        "--local-user",
        dest="local_user",
        default=os.getenv("USER"),
        metavar="USER",
        help="local ssh user who can access to the borg repository (default is current user)",
    )
    parser.add_argument(
        "--local-port",
        dest="local_port",
        type=int,
        default=22,
        metavar="PORT",
        help="local ssh port (default is 22)",
    )
    parser.add_argument(
        "--local-host",
        dest="local_host",
        default="localhost",
        metavar="HOST",
        help="local ssh host (default is localhost)",
    )
    parser.add_argument(
        "--tunnel",
        dest="ssh_tunnel",
        type=int,
        default=47022,
        metavar="PORT",
        help="port used to setup the ssh tunnel (you should change it if 47022 is already taken)",
    )

    parser.add_argument("remote_host", metavar="REMOTE_HOST", help="remote ssh host")
    parser.add_argument(
        "borg_args",
        nargs=argparse.REMAINDER,
        metavar="BORG_ARGS",
        help="borg arguments",
    )

    args = parser.parse_args()

    # Some checks
    if args.args_file and len(args.borg_args) > 0:
        print("You cannot provide borg arguments AND --args file", file=sys.stderr)
        sys.exit(1)

    # Build the remote borg repository
    borg_repo_dir = args.borg_repo_dir
    if borg_repo_dir is not None:
        borg_repo_dir = borg_repo_dir.resolve()
    elif os.getenv("BORG_REPO") is not None:
        borg_repo_dir = Path(os.getenv("BORG_REPO")).resolve()
    else:
        print(
            "No BORG_REPO set in environment not given using --repodir/-d",
            file=sys.stderr,
        )
        sys.exit(1)
    borg_repo = "ssh://{args.local_user}@{args.local_host}:{args.ssh_tunnel}{dir}".format(
        args=args, dir=borg_repo_dir
    )

    # Build the command line
    command = [
        "ssh",
        "-p",
        args.remote_port,
        "-A",  # Enables forwarding of the authentication agent connection
        "-R",  # Create the tunnel
        "{args.ssh_tunnel}:{args.local_host}:{args.local_port}".format(args=args),
        args.remote_host,
    ]
    if args.tty:
        # Force the TTY
        command.append("-t")
    command += [
        "BORG_REPO={0}".format(borg_repo),
        "borg",
    ]
    if args.args_file:
        with args.args_file.open() as fp:
            command += list(
                filter(
                    lambda x: len(x) > 0 and not x.startswith("#"),
                    map(str.strip, fp.readlines()),
                )
            )
    else:
        command += args.borg_args

    # Execute command
    command = list(map(str, command))
    print("Command:", " ".join(map(shlex.quote, command)))
    if args.non_interactive or input("Execute command? (y/N) ").strip().lower() == "y":
        print("----------------------------------------")
        out = subprocess.run(command).returncode
        sys.exit(out)
