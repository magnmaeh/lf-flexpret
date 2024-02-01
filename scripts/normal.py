import numpy as np
import sys

with open('src/normal.txt', 'w') as f:
    file = ""
    for i in range(int(sys.argv[1])):
        file += str(round(np.random.normal(1000, 100))) + ","
    f.write(file)