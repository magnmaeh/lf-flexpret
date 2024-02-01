source scripts/run_lib.sh

iterations=$1

clean_src_gen

python3 scripts/normal.py $iterations

do_benchmark "BasicControl" "Control/BasicControl" 1 $iterations
do_benchmark "NoJitterControl" "Control/NoJitterControl" 1 $iterations
do_benchmark "NoJitterBoundedControl" "Control/NoJitterBoundedControl" 1 $iterations

compile "Control/BasicControlLaptop" $iterations
echo "Executing Control/BasicControlLaptop"
./src-gen/Control/BasicControlLaptop/build/BasicControlLaptop > results/BasicControlLaptop/w1it$iterations.txt

compile "Control/NoJitterControlLaptop" $iterations
echo "Executing Control/NoJitterControlLaptop"
./src-gen/Control/NoJitterControlLaptop/build/NoJitterControlLaptop > results/NoJitterControlLaptop/w1it$iterations.txt

python3 scripts/plot_control.py $iterations
