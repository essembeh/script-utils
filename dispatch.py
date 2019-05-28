#!/usr/bin/python3

import argparse
import shutil
import sys
from argparse import ArgumentParser
from collections import OrderedDict
from pathlib import Path
from termicolor import print_green, print_red, print_style, Color

if __name__ == "__main__":
    parser = ArgumentParser(description="File dispatcher")
    parser.add_argument('-o', '--output', type=Path, metavar="FOLDER", help="output folder where files are dispatched")
    parser.add_argument('-n', '--dryrun', action='store_true', help="Dryrun mode, don't move/copy/link any file")
    parser.add_argument('-d', '--delete', action='store_true', help="Deletes files already present in target direcory")
    parser.add_argument('-p', '--prefix', action='store', default=2, type=int, metavar="LENGTH", help="prefix length (default = 2)")
    parser.add_argument('-r', '--remove-prefix', action='store_true', help="remove the prefix from filename when moved/copied/linked")
    group = parser.add_mutually_exclusive_group()
    group.add_argument('-l', '--link', action='store_const', const="link", dest="operation", default="move", help="Do symbolic links instead of moving files")
    group.add_argument('-c', '--copy', action='store_const', const="copy", dest="operation", help="Copy files instead of moving them")
    parser.add_argument("files", nargs=argparse.ONE_OR_MORE, type=Path, help="files to move/copy/link")
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
                    if args.delete:
                        files_to_move[source_file] = None
                    else:
                        print_green("[INFO]  File already exists: {source}".format(source=source_file))
            else:
                print_red("[ERROR]  Cannot extract prefix ({len}) for file: {file}".format(file=source_file, len=args.prefix), file=sys.stderr)
        else:
            print_red("[ERROR]  Cannot find file: {file}".format(file=source_file), file=sys.stderr)

    prompt = "(dryrun) $" if args.dryrun else "$"
    for folder in sorted(folders_to_create):
        print_style(" {prompt} mkdir  '{folder}'".format(prompt=prompt, folder=folder), fg_color=Color.YELLOW)
        if not args.dryrun:
            folder.mkdir(parents=True)
    for source, dest in files_to_move.items():
        if dest is None:
            print_style(" {prompt} rm  '{source}'".format(prompt=prompt, source=source), fg_color=Color.YELLOW)
            if not args.dryrun:
                source.unlink()
        else:
            if args.operation == "copy":
                print_style(" {prompt} cp  '{source}'  '{dest}'".format(prompt=prompt, source=source, dest=dest), fg_color=Color.YELLOW)
                if not args.dryrun:
                    shutil.copy(str(source), str(dest))
            elif args.operation == "link":
                print_style(" {prompt} ln -s  '{source}'  '{dest}'".format(prompt=prompt, source=source, dest=dest), fg_color=Color.YELLOW)
                if not args.dryrun:
                    dest.symlink_to(source)
            elif args.operation == "move":
                print_style(" {prompt} mv  '{source}'  '{dest}'".format(prompt=prompt, source=source, dest=dest), fg_color=Color.YELLOW)
                if not args.dryrun:
                    source.rename(dest)
            else:
                raise ValueError("Unknown operation {0}".format(args.operation))
