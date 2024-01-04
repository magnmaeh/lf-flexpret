#!/bin/bash

# This script should run all benchmarks and generate all plots and latex tables.

source scripts/run_lib.sh

set -e
workers=(1 3 5 7)
iterations=20

run_all "$iterations" "${workers[@]}"
