#!/usr/bin/python3

import requests
from argparse import ArgumentParser
from pytput import print_color

URL_API="https://www.kimsufi.com/fr/js/dedicatedAvailability/availability-data-ca.json"

if __name__ == "__main__":
    parser = ArgumentParser("kimsufi-checker")
    parser.add_argument('ref', nargs=1, help="Plan to search, example 1801sk13 or 1801sk14")
    args = parser.parse_args()

    plan = args.ref[0]
    data = requests.get(URL_API).json()
    for item in data["availability"]:
        if item["reference"] == plan:
            zones = [z["zone"] for z in item["zones"] if z["availability"] != "unavailable"]
            if len(zones)>0:
                print_color("green", plan + " is available in: " + ", ".join(zones))
            else:
                print_color("red", plan + " is not available")
                exit(1)
            exit(0)
    print_color("red", "Cannot find " + plan)
    exit(2)