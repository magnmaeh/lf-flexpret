#!/bin/bash

# This script should run all benchmarks and generate all plots and latex tables.

source scripts/run_lib.sh

set -e
workers=(1 3 5 7)
iterations=10 # FIXME: Todo can we use this variable to control 

run_all "$iterations" "${workers[@]}"
