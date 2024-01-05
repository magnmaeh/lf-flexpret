# Library of bash functions for automating the compiling, execution and analysis
# of benchmarks. This file should only be sourced by other run scripts.

# List of benchmarks and LF program names (without .lf extensions)
benchmarks=("pipeline" "scatter-gather")
programs=("Pipe" "SG" "Jitter")

# compile $program $iterations
compile() {
  # Add compilation commands for your benchmarks here
  echo "Compiling $1..."

  # Generate configuration for benchmarks
  echo "#define CONFIG_ITERATIONS ($2)" > src/config.h

  lingua-franca/bin/lfc "src/$1.lf" 
}

# execute $benchmark $program $workers $iterations
execute() {
  echo "Executing $2..."
  mkdir -p results/$1
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
  ((threads= $1))
  echo "#### Compiling flexpret with $threads threads"
  pushd flexpret
  make clean
  make "THREADS=$threads"
  popd
}

# Used do_benchmark $benchmark $program $worker $iterations
do_benchmark() {
  local benchmark=$1
  local program=$2
  local worker=$3
  local it=$4

  echo "Benchmark: $benchmark, Program: $program"

  # Compile source files
  compile "$program" "$it"

  # Execute program
  execute "$benchmark" "$program" "$worker" "$it"
}

# Used do_interrupt_benchmark $benchmark $program $worker $iterations $memfile
do_interrupt_benchmark() {
  local benchmark=$1
  local program=$2
  local worker=$3
  local it=$4

  echo "Benchmark: $benchmark, Program: $program"

  # Compile source files
  compile "$program" "$it"

  # Execute program
  echo "Executing $program..."
  
  flexpret/emulator/clients/build/interrupter.elf -a -n $iterations -d 1000 &
  fp-emu +ispm=src-gen/$program/$program.mem --client > results/$benchmark/w${worker}it$iterations.txt
  wait
}

do_interrupt_nlf_benchmark() {
  local benchmark=$1
  local program=$2
  local worker=$3
  local it=$4

  echo "Benchmark: $benchmark, Program: $program"
  echo "Compiling $program..."

  # Generate configuration for benchmarks
  echo "#define CONFIG_ITERATIONS ($it)" > flexpret/programs/tests/c-tests/interrupt-delay/config.h

  # Compile the test bench
  make -C flexpret/programs/tests/c-tests/interrupt-delay

  # Execute program
  echo "Executing $program..."

  # Run the interrupt client
  flexpret/emulator/clients/build/interrupter.elf -a -n $iterations -d 1000 &
  fp-emu +ispm=flexpret/programs/tests/c-tests/interrupt-delay/interrupt-delay.mem --client > results/$benchmark/w${worker}it$iterations.txt
  wait
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

  do_benchmark "$benchmark" "$program" "$worker" "$it"

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

    # Run all benchmarks
    for ((i = 0; i < ${#benchmarks[@]}; i++)); do
      benchmark="${benchmarks[i]}"
      program="${programs[i]}"

      if [[ $benchmark == "pipeline" ]]; then
        program="${programs[i]}""${worker}"
      fi

      if [[ $benchmark == "scatter-gather" ]]; then
        program="${programs[i]}""${worker}"
      fi

      if [[ $benchmark == "interrupt" ]]; then
        if [[ $worker == 1 ]]; then
          # This case is skipped due to a bug in the implementation
          echo "Skipping benchmark Interrupt with 1 worker"
        else
          do_interrupt_benchmark "$benchmark" "$program" "$worker" "$iterations"
        fi
      elif [[ $benchmark == "interrupt-nlf" ]]; then
        do_interrupt_nlf_benchmark "$benchmark" "$program" "$worker" "$iterations"
      else
        do_benchmark "$benchmark" "$program" "$worker" "$iterations"
      fi
    done

  done

  # Analyze results
  # python3 scripts/analyze.py scatter-gather pipeline -i$iterations -w "${workers[@]}"
  python3 scripts/plot.py
}
