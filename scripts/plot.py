# A very simple script for parsing and plotting the ScatterGather and
# Pipline results
import sys
import matplotlib
import matplotlib.pyplot as plt
from matplotlib.cm import get_cmap
import numpy as np

RESULT_DELIM="Result="
WORKERS=(1,3,5,7)
WORKER_TICKS=[f"{x} worker(s)" for x in WORKERS]
ITERATIONS=10
HATCH=["*", "//", "...", "---", "OO"]
CMAP = get_cmap("tab10").colors
plt.rcParams.update({'font.size': 16})


def parse_result_file(filePath, nWorkers):
  samples = list()
  with open(filePath, "r") as fp:
    for line in fp:
      if RESULT_DELIM in line:
        samples.append(int(line.split(RESULT_DELIM)[-1]))
  
  # Scale by nWorkers and account for 10ns clock cycles to get the thread cycles
  samples = [x/(nWorkers*10) for x in samples]

  return np.mean(samples)

pipeRes = list()
sgRes = list()

for w in WORKERS:
    pipeRes.append(parse_result_file(f"results/pipeline/w{w}it{ITERATIONS}.txt", w))
    sgRes.append(parse_result_file(f"results/scatter-gather/w{w}it{ITERATIONS}.txt", w))

print(pipeRes)
print(sgRes)

# Set the width of the bars
bar_width = 0.35

# Create index for the processors
index = np.arange(len(pipeRes))
print(index)
fig, ax = plt.subplots(figsize=(10, 6))

# Create grouped bar chart
ax.bar(index - bar_width/2, sgRes, bar_width, label='Scatter-Gather', color=CMAP[0], hatch=HATCH[0], alpha=0.8)
ax.bar(index + bar_width/2, pipeRes, bar_width, label='Pipelined', color=CMAP[1], hatch=HATCH[1], alpha=0.8)

# Add labels and title
ax.set_ylabel('Runtime overhead [cyces]')
ax.set_title('Runtime overhead for different programming patterns')
ax.set_xticks(index)
ax.set_xticklabels(WORKER_TICKS)
ax.legend()

# Show the bar chart
plt.tight_layout()
plt.savefig("pipe_sg_overhead.pdf")

    
    # ax.set_xticks(barPosX)
    # ax.set_xticklabels(labelsTm + labelsS)
    # ax.set_ylabel("Performance")
    # plt.legend(bbox_to_anchor=(0, 1, 1, 0), loc="lower left", ncol=4)
    # plt.xticks(rotation=12)
    # plt.tight_layout()
    # plt.savefig(savePath)
    # fig.show()