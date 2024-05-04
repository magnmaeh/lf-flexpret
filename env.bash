#!/usr/bin/env bash

# From https://stackoverflow.com/questions/59895/how-do-i-get-the-directory-where-a-bash-script-is-located-from-within-the-script 
LF_FLEXPRET_ROOT=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source $LF_FLEXPRET_ROOT/flexpret/env.bash