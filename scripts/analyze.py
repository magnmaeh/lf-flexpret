import matplotlib.pyplot as plt
from typing import List, Dict
from collections import Counter
import numpy as np
import matplotlib.patches as mpatches
import matplotlib.ticker as ticker


import argparse
parser = argparse.ArgumentParser()
parser.add_argument("-i", "--iterations", type=int)
parser.add_argument("-w", "--workers", type=int, nargs="+")
parser.add_argument("models",
    help="A list of models, possible values are: scatter-gather/interrupt/interrupt-nlf/pipeline/all",
    type=str,
    nargs="*",
    default="all"
)
args = parser.parse_args()

if not args.iterations:
    args.iterations=1000

if not args.workers:
    args.workers = [1,3,5,7]

print("### Analyze parameters ###")
print(f"models={args.models}")
print(f"iterations={args.iterations}")
print(f"workers={args.workers}")


DEFAULT_FONTSIZE = 34
ALL_MODELS_STRS = ['scatter-gather', 'interrupt', 'interrupt-nlf', 'pipeline']
ALL_NWORKERS = [1, 3, 5, 7]

def format_modelstr(modelstr: str) -> str:
    return 'Scatter-Gather' if modelstr == 'scatter-gather' else modelstr.capitalize()




class ItStruct:
    base: int
    stages: List[int]

    def __init__(self, base) -> None:
        self.base = base
        self.stages = list()
    
    def push(self, time) -> None:
        self.stages.append(time)

def extract_itstrings(path: str) -> List[str]:
    iterations = list()
    idx_offset = 0
    with open(path, 'r') as f:
        text = f.read()
        for line in text.split('\n'):
            # Remove the '[x]: ' part of each line
            #line = line[5:]
            if line.startswith('Iteration'):
                if 'NA' in line:
                    idx_offset += 1
                else:
                    iterations.append(line)
    
    return iterations, idx_offset

def itstrings_to_itstruct(itstrings: List[str], idx_offset: int) -> List[ItStruct]:
    structured = list()
    for (itstr, idx) in zip(itstrings, range(len(itstrings))):
        parts = itstr.split(',')
        iteration_and_base = parts[0]
        datapoints = parts[1:]

        # This part is structured like this:
        # Iteration <N>: Base: <time>
        iteration_and_base = iteration_and_base.split(':')
        iteration = iteration_and_base[0]
        
        # We now have the string
        # Iteration <N>
        # But we want N
        iteration = int(iteration[10:])
        
        # We only really want the iteration to do an assertion on the index
        #assert(iteration == (idx + idx_offset))

        # Now extract the base time
        base = int(iteration_and_base[2])
        
        iteration_struct = ItStruct(base)

        # Now extract all other time recordings, structured like this:
        # {0}: <time>, {1}: <time>, {2}: <time>, ...
        # The last element in the datapoints list does not contain data
        for (dp, dpidx) in zip(datapoints, range(len(datapoints)-1)):
            dpiteration, time = dp.split(':')

            # We only do this for assertion as well
            dpiteration = int(dpiteration.replace('{', '').replace('}', ''))
            assert(dpiteration == dpidx)

            time = 0 if time == ' NA' else int(time)

            iteration_struct.push(time)
        
        structured.append(iteration_struct)
    
    return structured

def produce_diff_from_base(itstructs: List[ItStruct]) -> List[int]:
    result = list()
    for itstruct in itstructs:
        base = itstruct.base
        for time in itstruct.stages:
            if time > 0:
                result.append(time - base)
    return result

def count_in_partitions(list, npoints) -> (List[int], List[int]):
    list_min = min(list)
    list_max = max(list)
    diff_max_min = list_max - list_min

    npartitions = npoints - 1

    print(f"(min, max) = ({list_min}, {list_max})")
    print("Percentage difference: " + str(float(diff_max_min / list_max) * 100))

    limits = [int(list_min + (1/2 + n)*diff_max_min/npartitions) for n in range(npartitions)] + [list_max]
    print(limits[:len(limits)-1])

    counts = [0] * npoints
    list.sort()

    idx = 0
    for elem in list:
        if elem == list_max:
            counts[-1] += 1
            continue
        elif elem > limits[idx]:
            idx += 1
        counts[idx] += 1

    print(counts)
    return counts

def flatten(list):
    return [item for row in list for item in row]

def make_title(model, nworkers, niterations):
    return 'Distribution of overhead in LF ' + model + ' using ' \
            + str(nworkers) + ' worker' + ('s' if nworkers > 1 else '') + ' over ' \
            + str(niterations) + ' iterations'

def plot_diff_from_base(model, diffs: List[int], niterations: int):
    NPOINTS_MAX = 5

    print('\n### Plotting ' + model + ' ###\n')

    WORKERS = [1, 3, 5, 7]
    xtick_strs = list()
    npoints_accumulated = 0
    counts_accumulated = list()

    if model in ['pipeline', 'scatter-gather', 'interrupt-nlf']:
        # The first plot only has two points so plot it seperately
        diff_flat = flatten(diffs[0])
        npoints = 2
        npoints_accumulated += npoints
        counts = count_in_partitions(diff_flat, npoints)
        counts_accumulated += counts

        print(counts)
        assert(sum(counts) == 1 * niterations)

        lower_bound = int(min(diff_flat) / 1000)
        upper_bound = int(max(diff_flat) / 1000)
        xtick_strs += [str(lower_bound), str(upper_bound)]

        diffs = diffs[1:]
        workers = WORKERS[1:]

    elif model == 'interrupt':

        # A bug makes it so this data cannot be gathered
        diffs = diffs[1:]
        workers = WORKERS[1:]

        def remove(lst):
            idx = lst.index(max(lst))
            print("[" + str(idx) + "]: Removed:", lst.pop(idx))


        for idx in range(len(diffs)):
            print("Diff: " + str(idx))
            diff = diffs[idx]
            remove(diff)

            if idx == 1:
                remove(diff)
                remove(diff)
                remove(diff)
    
    for (diff, nworkers) in zip(diffs, workers):
        diffs_flat = flatten(diff)
        nunique_points = len(Counter(diffs_flat).values())
        npoints = min(NPOINTS_MAX, nunique_points)
        npoints_accumulated += npoints
        
        counts = count_in_partitions(diffs_flat, npoints)
        counts_accumulated += counts
        
        if model == 'pipeline':
            pipeline_start_loss = nworkers * (nworkers - 1)
            assert(sum(counts) == (nworkers * niterations - pipeline_start_loss))
        elif model == 'scatter-gather':
            assert(sum(counts) == (nworkers * niterations))
        elif model == 'interrupt':
            #assert(sum(counts) == niterations - 1)
            pass

        lower_bound = int(min(diffs_flat) / 1000)
        upper_bound = int(max(diffs_flat) / 1000)
        midpoint    = int((lower_bound + upper_bound) / 2)

        xtick_strs += [
            str(lower_bound),
            '',
            str(midpoint),
            '', 
            str(upper_bound),
        ]
        if model == 'interrupt':
            print(upper_bound)
            print(lower_bound)

    # From a palette finder website
    palette = ['#313715', '#6E7DAB', '#F79AD3', '#DE9E36']
    colors = [palette[0]] * 2 + [palette[1]] * 5 + [palette[2]] * 5 + [palette[3]] * 5
    workers = WORKERS
    nplots = 4
    
    if model == 'interrupt':
        palette = palette[1:]
        colors = colors[2:]
        workers = workers[1:]
        nplots -= 1

    title = model + ' model for ' + str(workers) + '\nworkers over 1000 iterations'
    plt.title(title, fontsize=DEFAULT_FONTSIZE)
    plt.xlabel('Time (us)', fontsize=DEFAULT_FONTSIZE)

    patches = [mpatches.Patch(color=palette[n], label=str(y) + ' workers') for (n, y) in zip(range(nplots), workers)]
    plt.legend(handles=patches, fontsize=DEFAULT_FONTSIZE)

    plt.xticks([])
    #plt.xticks(np.linspace(0, 1, len(xtick_strs)), xtick_strs, fontsize=18)
    plt.yticks(fontsize=DEFAULT_FONTSIZE)
    plt.bar(np.linspace(0, 1, len(xtick_strs)), counts_accumulated, width=0.02, color=colors)    
    plt.show()

def get_means_stddevs(data: [[[float]]]) -> (list, list):
    means = dict()
    stddevs = dict()

    for model in data:
        means[model] = dict()
        stddevs[model] = dict()
        for workers in data[model]:
            workset = data[model][workers]
            means[model][workers] = np.mean(workset)
            stddevs[model][workers] = np.std(workset)

    return means, stddevs

def plot_models(data: Dict[str, list]):
    for model in data:
        nworkers = [*data[model].keys()]
        points = [*data[model].values()]
        plt.plot(nworkers, points, '-o', label=format_modelstr(model) + ' pattern', linewidth=3)

def divide_yaxis_by_1000():
    def div_1000(x, *args):
        x = float(x)/1000
        return "{}".format(int(x)) 

    ax = plt.gca()
    ax.yaxis.set_major_formatter(ticker.FuncFormatter(div_1000))

def configure_plot(workers, yaxis_str: str):
    divide_yaxis_by_1000()
    
    plt.xticks(workers, fontsize=DEFAULT_FONTSIZE)
    plt.xlabel('Number of workers', fontsize=DEFAULT_FONTSIZE)
    
    plt.yticks(fontsize=DEFAULT_FONTSIZE)
    plt.ylabel(yaxis_str + ' (us)', fontsize=DEFAULT_FONTSIZE)
    
    plt.title(yaxis_str + ' vs. number of workers', fontsize=DEFAULT_FONTSIZE)
    plt.legend(fontsize=DEFAULT_FONTSIZE)

def plot_means_stddevs(data: Dict[str, Dict[str, list]], workers):
    means, stddevs = get_means_stddevs(data)

    plot_models(means)
    configure_plot(workers, 'Timing overhead')
    plt.show()

    plot_models(stddevs)
    configure_plot(workers, 'Standard deviation')
    plt.show()

def get_diffs(model, nworkers, niterations):
    path = 'results/' + model + '/w' + str(nworkers) + 'it' + str(niterations) + '.txt'
    itstrs, idx_offset = extract_itstrings(path)
    itstructs = itstrings_to_itstruct(itstrs, idx_offset)
    return produce_diff_from_base(itstructs)

def get_alldiffs(model, workers, iterations):
    return {n: get_diffs(model, n, iterations) for n in workers}

#all_modeldata = dict()
#
#if "scatter-gather" in args.models or "all" in  args.models:
#    alldiff = get_alldiffs('scatter-gather', args.workers, args.iterations)
#    #plot_diff_from_base('scatter-gather', alldiff, args.iterations)
#    all_modeldata['scatter-gather'] = alldiff
#
#if "interrupt" in args.models or "all" in args.models:
#    alldiff = get_alldiffs('interrupts', args.workers, args.iterations)
#    #plot_diff_from_base('interrupt', alldiff, args.iterations)
#    all_modeldata['interrupt'] = alldiff
#
#if "interrupt-nlf" in args.models or "all" in args.models:
#    alldiff = get_alldiffs('interrupt-nlf', args.workers, args.iterations)
#    #plot_diff_from_base('interrupt-nlf', alldiff, args.iterations)
#    all_modeldata['interrupt-nlf'] = alldiff
#
#if "pipeline" in args.models or "all" in args.models:
#    alldiff = get_alldiffs('pipeline', args.workers, args.iterations)
#    #plot_diff_from_base('pipeline', alldiff, args.iterations)
#    all_modeldata['pipeline'] = alldiff

#plot_means_stddevs(all_modeldata, args.workers)

path = 'jitter.txt'
itstrs, idx_offset = extract_itstrings(path)
itstructs = itstrings_to_itstruct(itstrs, idx_offset)

