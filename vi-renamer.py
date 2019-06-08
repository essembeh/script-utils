#!/usr/bin/python3

import argparse
import os
import subprocess
from argparse import ArgumentParser
from pathlib import Path
from tempfile import NamedTemporaryFile
from termicolor import Style, print_style, print_red

if __name__ == "__main__":
    parser = ArgumentParser(description="File renamer")
    parser.add_argument('-e', '--editor', action='store', help="Editor used to edit file list")
    parser.add_argument('-f', '--force', action='store_true', help="Overwrite if target file already exists")
    parser.add_argument('-d', '--delete', action='store_true', help="Delete file if line is empty")
    parser.add_argument('-n', '--dryrun', action='store_true', help="Dryrun mode, don't rename any file")
    parser.add_argument("files", nargs=argparse.ONE_OR_MORE, type=Path, help="files to rename")
    args = parser.parse_args()

    input_files = []
    output_lines = []
    # Filter existing files from input and avoid doublons
    for f in args.files:
        if f.exists() and f not in input_files:
            input_files.append(f)
    # Edit the files with editor
    with NamedTemporaryFile() as tmp:
        with open(tmp.name, "w") as fp:
            for f in input_files:
                fp.write(str(f) + "\n")
        subprocess.check_call([args.editor or os.getenv("EDITOR", 'vi'), tmp.name])
        with open(tmp.name, "r") as fp:
            output_lines = list(map(str.strip, fp))
    # Check that the line count is the same
    if len(input_files) != len(output_lines):
        print_red("File count has changed, cannot rename any file")
        exit(1)
    # Iterate the two lists
    action_styles = [Style.FG_PURPLE if args.dryrun else Style.FG_GREEN]
    for source, dest in zip(input_files, output_lines):
        if len(dest) == 0:
            if args.delete:
                # delete mode
                print_style("Delete '{source}'".format(source=source), styles=action_styles)
                if not args.dryrun:
                    source.unlink()
            else:
                print_red("'{source}' won't be deleted, use --delete to enable file deletion'".format(source=source))
        else:
            dest = Path(dest)
            if source != dest:
                if dest.exists() and not args.force:
                    print_red("'{dest}' already exists, skip renaming '{source}'".format(source=source, dest=dest))
                else:
                    print_style("Rename '{source}' --> '{dest}'".format(source=source, dest=dest), styles=action_styles)
                    if not args.dryrun:
                        source.rename(dest)
