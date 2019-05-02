#!/usr/bin/python3

import argparse
import shutil
import sys
from argparse import ArgumentParser
from collections import OrderedDict
from pathlib import Path

if __name__ == "__main__":
    parser = ArgumentParser(description="File dispatcher")
    parser.add_argument('-o', '--output', type=Path, metavar="FOLDER", help="output folder where files are dispatched")
    parser.add_argument('-n', '--dryrun', action='store_true', help="Dryrun mode, don't move/copy/link any file")
    parser.add_argument('-p', '--prefix', action='store', default=2, type=int, metavar="LENGTH", help="prefix length (default = 2)")
    parser.add_argument('-r', '--remove-prefix', action='store_true', help="remove the prefix from filename when moved/copied/linked")
    group = parser.add_mutually_exclusive_group()
    group.add_argument('-l', '--symlinks', action='store_true', help="Do symbolic links instead of moving files")
    group.add_argument('-c', '--copy', action='store_true', help="Copy files instead of moving them")
    parser.add_argument("files",  nargs=argparse.ONE_OR_MORE, type=Path, help="files to move/copy/link")
    args = parser.parse_args()

    target = args.output or Path.cwd()
    folders_to_create = []
    files_to_move = OrderedDict()
    for source_file in args.files:
        if source_file.exists():
            if 0 < args.prefix < len(source_file.name):
                prefix = source_file.name[0:args.prefix]
                prefix_folder = target / prefix
                target_name = source_file.name[args.prefix:] if args.remove_prefix else source_file.name
                target_file = prefix_folder / target_name
                if not target_file.exists():
                    if not prefix_folder.is_dir() and not prefix_folder in folders_to_create:
                        folders_to_create.append(prefix_folder)
                    files_to_move[source_file] = target_file
                else:
                    print("[INFO]  File already exists: {target}".format(target=target_file))
            else:
                print("[ERROR]  Cannot extract prefix ({len}) for file: {file}".format(file=source_file, len=args.prefix), file=sys.stderr)
        else:
            print("[ERROR]  Cannot find file: {file}".format(file=source_file), file=sys.stderr)

    prompt = "(dryrun) $" if args.dryrun else "$"
    for folder in sorted(folders_to_create):
        print(" {prompt} mkdir  '{folder}'".format(
            prompt=prompt, folder=folder))
        if not args.dryrun:
            folder.mkdir(parents=True)
    for source, dest in files_to_move.items():
        if args.copy:
            print(" {prompt} cp  '{source}'  '{dest}'".format(prompt=prompt, source=source, dest=dest))
            if not args.dryrun:
                shutil.copy(str(source), str(dest))
        elif args.symlinks:
            print(" {prompt} ln -s  '{source}'  '{dest}'".format(prompt=prompt, source=source, dest=dest))
            if not args.dryrun:
                dest.symlink_to(source)
        else:
            print(" {prompt} mv  '{source}'  '{dest}'".format(prompt=prompt, source=source, dest=dest))
            if not args.dryrun:
                source.rename(dest)
