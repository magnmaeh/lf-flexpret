#!/bin/bash

set -e
# List of benchmarks
benchmarks=("scatter-gather")
programs=("ScatterGather")
workers=(2 4 6 8)
iterations=1000

compile() {
    # Add compilation commands for your benchmarks here
    echo "Compiling $2..."
    lingua-franca/bin/lfc "src/$2.lf" 
}

execute() {
    echo "Executing $2..."
    make -C "src-gen/$2" run > "results/$1/w${3}it${iterations}.txt"
}

analyze() {
  python3 scripts/analyze.py all
}

compile_lfc() {
  echo "#### Compiling lfc"
  pushd lingua-franca
  ./gradlew assemble
  popd
}

clean_src_gen() {
  rm -rf src-gen/
}

compile_fp() {
  local threads=$1
  echo "#### Compiling flexpret with $threads threads"
  pushd flexpret
  make clean
  make "THREADS=$threads"
  popd
}


# compile_lfc
clean_src_gen

# Main loop
for worker in "${workers[@]}"; do
  # compile_fp "$worker"
  for ((i = 0; i < ${#benchmarks[@]}; i++)); do
    benchmark="${benchmarks[i]}"
    program="${programs[i]}"
    echo "Benchmark: $benchmark, Program: $program"
    # Compile source files
    compile "$benchmark" "$program"

    # Execute program
    execute "$benchmark" "$program" "$worker"

  done
done

# Analyze results
analyze
