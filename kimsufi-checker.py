#!/usr/bin/python3

import shlex
import subprocess
from argparse import ArgumentParser, RawDescriptionHelpFormatter, RawTextHelpFormatter
from collections import OrderedDict
from datetime import datetime
from time import sleep

import pytput
import requests
from pytput import print_color

URL_API = (
    "https://www.kimsufi.com/fr/js/dedicatedAvailability/availability-data-ca.json"
)


def now():
    return datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")


def execute(command: str, plan: str):
    if command:
        try:
            command = command.format(plan=plan)
            cmd = shlex.split(command)
            p = subprocess.run(
                cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
            )
            print_color(
                "yellow",
                "[{date}] Command {cmd} exited with {p.returncode}".format(
                    date=now(), cmd=command, p=p
                ),
            )
            return p.returncode
        except BaseException as e:
            print_color(
                "red",
                "[{date}] Disabling command {cmd} because of error: {txt}".format(
                    date=now(), cmd=command, txt=str(e)
                ),
            )


def get_data() -> dict:
    return requests.get(URL_API).json()


def get_available_zones(data: dict, plan: str, filter_zones: list) -> list:
    for item in data["availability"]:
        if item["reference"] == plan:
            return sorted(
                filter(
                    lambda z: len(filter_zones) == 0
                    or z.lower() in map(str.lower, filter_zones),
                    [
                        z["zone"]
                        for z in item["zones"]
                        if z["availability"] != "unavailable"
                    ],
                )
            )
    raise ValueError("Cannot find plan: " + plan)


if __name__ == "__main__":
    parser = ArgumentParser(
        "kimsufi-checker",
        formatter_class=RawDescriptionHelpFormatter,
        description="tool to perform actions when Kimsufi availabilty changes",
        epilog="""
example:
    Checks every 10 minutes for 1801sk13 abd 1801sk14 plans in France or Canada and send a SMS using Free Mobile API when availabilty changes:
    $ kimsufi-checker \\
        --sleep 600 \\
        --zone rbx \\
        --zone gra \\
        -x 'curl "https://smsapi.free-mobile.fr/sendmsg?user=123456789&pass=MYPASSWORD&msg=Kimsufi%20{plan}%20available"' \\
        -X 'curl "https://smsapi.free-mobile.fr/sendmsg?user=123456789&pass=MYPASSWORD&msg=Kimsufi%20{plan}%20not%20available"' \\
        1801sk13 1801sk14
        """,
    )
    parser.add_argument(
        "-s",
        "--sleep",
        metavar="SECONDS",
        type=int,
        default=60,
        help="Duration (in seconds) between checks, default: 60",
    )
    parser.add_argument(
        "-z",
        "--zone",
        dest="zones",
        action="append",
        metavar="ZONE",
        help="check availability in specific zones (example: rbx or gra)",
    )
    parser.add_argument(
        "-x",
        "--available",
        metavar="COMMAND",
        help="command to execute when plan becomes available",
    )
    parser.add_argument(
        "-X",
        "--not-available",
        metavar="COMMAND",
        help="command to execute when plan is not available anymore",
    )
    parser.add_argument(
        "plans", nargs="*", help="plans to check, example 1801sk13 or 1801sk14"
    )
    args = parser.parse_args()
    if len(args.plans) == 0:
        data = get_data()
        plans = set()
        zones = set()
        for pref in data["availability"]:
            plans.add(pref["reference"])
            for zref in pref["zones"]:
                zones.add(zref["zone"])
        print("List of plans:")
        for p in sorted(plans):
            print(" ", p)
        print("List of zones:")
        for z in sorted(zones):
            print(" ", z)
    else:
        availability = None
        while True:
            try:
                if availability is None:
                    availability = OrderedDict([(p, None) for p in args.plans])
                else:
                    sleep(args.sleep)

                data = get_data()
                for plan, previous_zones in availability.items():
                    current_zones = get_available_zones(data, plan, args.zones or [])
                    availability[plan] = current_zones
                    if previous_zones is None:
                        # No previous data
                        pass
                    elif previous_zones == current_zones:
                        # No change
                        pass
                    elif len(current_zones) == 0:
                        # Not available anymore
                        print_color(
                            "purple",
                            "[{date}] Plan {plan} is not available anymore".format(
                                date=now(), plan=plan
                            ),
                        )
                        if execute(args.not_available, plan) is None:
                            args.not_available = None
                    else:
                        # Becomes available
                        print_color(
                            "green",
                            "[{date}] Plan {plan} is available".format(
                                date=now(), plan=plan
                            ),
                        )
                        if execute(args.available, plan) is None:
                            args.available = None
            except KeyboardInterrupt:
                break
            except BaseException as e:
                print_color(
                    "red", "[{date}] Error: {txt}".format(date=now(), txt=str(e))
                )
