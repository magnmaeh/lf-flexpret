#!/bin/bash

# This script should run a single benchmark on a single version of FP and
# generate results.

source scripts/run_lib.sh

set -e
workers=3
iterations=10
benchmark="pipeline"
program="Pipeline3"

run_single "$benchmark" "$program" "$workers" "$iterations"
