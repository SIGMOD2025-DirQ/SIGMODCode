<meta name="robots" content="noindex">

# Directional Queries
This repository contains code for testing effectiveness and efficiency of directional queries with a heap-based implementation using no index.

## Features

- Performs sequential linear and directional top-k queries given a CSV file containing the dataset.
- Reports statistics at the console.

## How to compile
The code is written in swift and was tested under XCode 15.2. If you want to execute it under XCode, you should:
- create a new project: File -> New -> Project
- choose Command Line Tool
- name it as you like, say `DirQ`, and make sure that swift is the selected language
- replace its `main.swift` file with the `main.swift` file available in this repository
- click on the project name (`DirQ`) in the top bar and do Edit Scheme, then under `Run` select `Release` instead of `Debug` for the Build Configuration and uncheck `Debug executable`.


## How to use

Experiments can be run on any CSV dataset through a call to the `experiment` function, which takes four parameters:
-  `name` : the name of the CSV dataset (without the `.csv` extension).
-  `attributes` : an array of `String`, each corresponding to an attribute of the CSV file to be used in the experiment.
-  `ks` : an array of `Int`, corresponding to the values of k to be tested in the experiment.
-  `beta` : an array of `Double`, corresponding to the values of beta to be tested in the experiment.

The experiment will consist of a series of tests on the data contained in the dataset called `name`, on the attributes listed in `attributes` and for every value of *k* in `ks` and every value of *beta* in `betas`.


The main file already includes several experiments and refers to the directory "~/cleanData", which can be changed by modifying the `datasetDir` variable directly in the code.
The above directory *must* contain the following CSV files:
- NBAstats2WithId.csv
- anti2dWithId.csv
- sensorsWithId.csv
- synt2A1000000WithId.csv
- synt3A10000000WithId.csv
- synt3A1000000WithId.csv
- synt3A100000WithId.csv
- synt3A10000WithId.csv
- synt3A5000000WithId.csv
- synt3A500000WithId.csv
- synt3A50000WithId.csv
- synt4A1000000WithId.csv
- synt5A1000000WithId.csv
- synt6A1000000WithId.csv

All of these can be downloaded from *TO BE FILLED*.

Alternatively, you can comment out all calls to `experiment` and `syntheticExperiment` in the file and run an experiment to a specific CSV dataset of your choice.

## Output
The output consists of statistical information printed at the console in a comma-separated format.
In particular, the output includes:
- `k` : output size
- `d` : number of dimensions
- `N` : dataset size
- `beta` : value of beta (i.e., the mean-distance parameter, where beta=1 means linear query)
- `avgPrec` : average precision
- `avgRec` : average recall
- `avgDist` : average distance or dispersion
- `cumulRec` : cumulative recall
- `time` : average execution time
- `cumulEvol` : cumulative exclusive volume
- `cumulGrid` : cumulative grid resistance

## Additional experiments
Besides the `experiment` function, there is another utility (`rankOfClosestSkylineTuple`) used to compute the rank of the skyline tuple closest to the preference line. The utility reports statistics about the involved points and the differences in rank between linear and directional queries.
