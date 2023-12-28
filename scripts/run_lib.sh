# Library of bash functions for automating the compiling, execution and analysis
# of benchmarks. This file should only be sourced by other run scripts.

# List of benchmarks and LF program names (without .lf extensions)
benchmarks=("scatter-gather")
programs=("ScatterGather")

# compile $program
compile() {
    # Add compilation commands for your benchmarks here
    echo "Compiling $1..."
    lingua-franca/bin/lfc "src/$1.lf" 
}

# execute $benchmark $program $workers $iterations
execute() {
    echo "Executing $2..."
    make -C "src-gen/$2" run > "results/$1/w${3}it$4.txt"
}

# analyze $model $iterations
analyze() {
  python3 scripts/analyze.py $1 $2
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

# compile_fp $workers
compile_fp() {
  ((threads= $1 + 1))
  echo "#### Compiling flexpret with $threads threads"
  pushd flexpret
  make clean
  make "THREADS=$threads"
  popd
}

# Used run_single $benchmark $program $worker $iterations
run_single() {
  local benchmark=$1
  local program=$2
  local worker=$3
  local it=$4

  compile_lfc
  clean_src_gen
  compile_fp $worker

  echo "Benchmark: $benchmark, Program: $program"
      
  # Compile source files
  compile "$program"

  # Execute program
  execute "$benchmark" "$program" "$worker" "$iterations"

  # Analyze results
  python3 scripts/analyze.py $benchmark -i$iterations -w$worker

}

# run_all $iterations $workers
run_all() {
  local iterations=$1
  shift
  local workers=("$@")
  compile_lfc
  clean_src_gen

  # Main loop
  for worker in "${workers[@]}"; do
    compile_fp "$worker"

    # Do pipeline benchmark
    benchmark="pipeline"
    program="Pipeline$worker"
    echo "Benchmark: $benchmark, Program: $program"

    # Compile source files
    compile "$program"

    # Execute program
    execute "$benchmark" "$program" "$worker" "$iterations"

    # Do other benchmarks
    for ((i = 0; i < ${#benchmarks[@]}; i++)); do
      benchmark="${benchmarks[i]}"
      program="${programs[i]}"
      echo "Benchmark: $benchmark, Program: $program"
      # Compile source files
      compile "$program"

      # Execute program
      execute "$benchmark" "$program" "$worker" "$iterations"
    done

  done

  # Analyze results
  python3 scripts/analyze.py all -i$iterations
}
