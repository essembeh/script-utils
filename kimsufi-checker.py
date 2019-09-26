#!/usr/bin/python3

import shlex
import subprocess
import requests
from argparse import ArgumentParser
from datetime import datetime
from time import sleep

URL_API = (
    "https://www.kimsufi.com/fr/js/dedicatedAvailability/availability-data-ca.json"
)


def get_availability(plan: str):
    data = requests.get(URL_API).json()
    for item in data["availability"]:
        if item["reference"] == plan:
            return [
                z["zone"] for z in item["zones"] if z["availability"] != "unavailable"
            ] or None


if __name__ == "__main__":
    parser = ArgumentParser("kimsufi-checker")
    parser.add_argument(
        "-s",
        "--sleep",
        metavar="SECONDS",
        type=int,
        default=60,
        help="Duration (in seconds) between checks, default: 60",
    )
    parser.add_argument(
        "-x",
        "--execute",
        metavar="COMMAND",
        help="Command to execute when plan becomes available",
    )
    parser.add_argument(
        "plan", nargs="?", help="Plan to check, example 1801sk13 or 1801sk14"
    )
    args = parser.parse_args()

    if args.plan is None:

        data = requests.get(URL_API).json()
        print("List of plans:")
        for p in sorted({item["reference"] for item in data["availability"]}):
            print(p)
    else:
        previous_zones = None
        while True:
            current_zones = get_availability(args.plan)
            if current_zones is not None and previous_zones is None:
                # Available
                print(
                    "\n[{date}] Plan {plan} is available".format(
                        date=datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S"),
                        plan=args.plan,
                    )
                )
                if args.execute is not None:
                    command = shlex.split(args.execute)
                    p = subprocess.run(
                        command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
                    )
                    print(
                        "    Command {c} exited with {rc}".format(
                            c=command, rc=p.returncode
                        )
                    )
            elif current_zones is None and previous_zones is not None:
                # Not available anymore
                print(
                    "\n[{date}] Plan {plan} is not available anymore".format(
                        date=datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S"),
                        plan=args.plan,
                    )
                )
            else:
                print(".", end="", flush=True)
            previous_zones = current_zones
            sleep(args.sleep)
