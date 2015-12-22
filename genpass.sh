#!/bin/bash

date +%N%s | sha256sum | base64 | head -c 32 ; echo
