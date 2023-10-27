# `02_experiment`

This section contains the code used to run the experiments on the data prepared in `01_data_and_preprocessing`.

## Structure

- `simulation` contains the code used to create the simulation used in Figure 1(a). This folder also contains the run scripts used on the HPC.
- `function` contains helper functions used in all experiments.

The code structure is as the following:

- function
  - [debias_logit.R](#debias_logit.R)
  - [debias_measure.R](#debias_measure.R)
  - [help_debias_measure.R](#help_debias_measure.R)
  - [impute_logit.R](#impute_logit.R)
  - [impute_measure.R](#impute_measure.R)
- experiment
  - [dgp_logit_simulation.R](#dgp_logit_simulation.R)
  - [run_experiment_hpc.R](#run_experiment_hpc.R)
  - [run_experiment_hpc.slurm](#run_experiment_hpc.slurm)
  - [experiment_logit.R](#experiment_logit.R)
  - [experiment_measure.R](#experiment_measure.R)

### debias_logit.R
- This is the function for Design-based Semi-Supervised Learning (DSL) calculation with logit setting.
- In this function, we use the sample splitting for cross-fitting iterations. In each iteration, we first fit the model E(Y | X, R = 1) in the training sample. Then we predict E(Y | X, R = 1) in the test data and the no label data. We then employ Design-based Semi-Supervised Learning (DSL) Estimator and store the result.

### debias_measure.R
- This is the function for Design-based Semi-Supervised Learning (DSL) calculation with measure setting.
- In this function, we use the sample splitting for cross-fitting iterations. In each iteration, we first fit the model E(Y | X, R = 1) in the training sample. Then we predict E(Y | X, R = 1) in the test data and the no label data. We then employ Design-based Semi-Supervised Learning (DSL) Estimator and store the result.

### help_debias_measure.R
- This is help functions for both logit and measure. Include two functions: `fit_model`, and `fit_test`.
- `fit_model` is for fitting the model E(Y | X, R = 1) in the training sample.
- `fit_test` is for predicting E(Y | X, R = 1).

### impute_logit.R
- This is the function for Semi-Supervised Learning (SSL) calculation with logit setting.
- The estimator uses a bootstrap. In each bootstrap iteration, we sample fixed proportions of the labeled and unlabeled data. We fit a `regression_forest` model from the `grf` library to the labeled data and generate predicted labels for the entire dataset (`PI` in the code). We then fit a logistic regression model (defined in `debias_logit.R`) to the predicted labels and store the resulting coefficients. Our final SSL estimate is averaged over bootstrap iterations.

### impute_measure.R
- This is the function for Semi-Supervised Learning (SSL) calculation with measure setting.
- This is analogous to the `impute_logit.R` estimator, except instead fitting a logistic regression to the predicted labels we take their average.

### dgp_logit_simulation.R
- This is the code for generating simulation data for `Figure 1(a)` in the main paper.
- In this simulation, we set total number of documents to 5000, the number of hand-coded documents to 500, and run 500 iterations.
- For each iteration, we first generate `X`, a matrix of 10 covariates (X1, X2, ..., X10) as draws from the multivariate normal.  We then generate `Y` as draws from the binomial distribution with the success probability given by the values of `X` (see L47-50 for constants and exact combinations used to generate p).
- We generate surrogate labels at varying accuracies (0.5, 0.6, 0.7, 0.8, 0.9, 0.95).
- We set `Y ~ X1 + X1^2 + X2 + X4` as the logistic regression researchers want to run.
- We produce SO estimates from the surrogate labels, and DSL estimates using use the `debias_logit` function (details on `debias_logit` above and in `debias_logit.R`).
- After each iteration, we store the point estimates and standard errors for SO and DSL.
- The resulting data is stored in `RDS` format and used to generate Figure 1a of the paper.

### run_experiment_hpc.R
- This is a run script for use with `run_experiment_hpc.slurm`. It contains the simulation parameters.
- For the `DATASET` setting, here need to note that, for measure case, input the full file name to the dataset here, for example, `DATASET <- 'binary_conv_go_awry_pos-yes.csv' `. For the logit case, DATASET should be a string `easy` or `imbalanced` (`easy` represent balanced case).

### run_experiment_hpc.slurm
- This is a slurm job template to run `run_experiment_hpc.R`.

### experiment_logit.R
- This is the simulation file that implement the simulation loop for logit case.
- This file connect the input data with the functions in the simulation loop. For each loop, we first read and set up the design table (that is, in this simulation loop, the specified simulation size, simulation surrogates, etc). Then we set up the input data, we also process as bootstrap data to make sure that surrogate-based estimator will also have randomness. After set up the labeled data, unlabeled data, and hand-coded ratio, we call the functions to calculate the point estimate and standard error for DSL, SSL, SO and GSO and store the result in this simulation loop.

### experiment_measure.R
- This is the simulation file that implement the simulation loop for measure case.
- This file connect the input data with the functions in the simulation loop. For each loop, we first read and set up the design table (that is, in this simulation loop, the specified simulation size, simulation surrogates, etc). Then we set up the input data, we also process as bootstrap data to make sure that surrogate-based estimator will also have randomness. After set up the labeled data, unlabeled data, and hand-coded ratio, we call the functions to calculate the point estimate and standard error for DSL, SSL, SO and GSO and store the result in this simulation loop.


## Running Scripts

### Simulation for Figure

Note that the simulation for figure 1a is configured to parallelize and use all but 1 CPU core. It can be executed as follows:

```{sh}
Rscript dgp_logit_simulation.R
```
Users testing the script may also wish to reduce the number of simulation iterations, which can be configured on line 19 of the script. The output at `sim_res/DGP_sim_logit_result.rds` is produced from 500 simulations.

### Main Experiment

Modify the `PROBLEM_TYPE` and `DATASET` variables to your preferred configuration.  The script `run_experiment_hpc.R` is configured to run from a SLURM job array. To execute outside of SLURM, the relevant lines are up to 40 and then the user will want to loop through designs applying the `simulation_loop` function; e.g. `simulation_loop(s=1)`.

By default this will write to a new directory called `run_001`, but can be configured in the script `run_experiment_hpc.R`.


## Time Estimation
Here we give an estimation of the running time. We use HPC to run parallel jobs in the experiment.

### logit 
In the logit balanced and imbalanced case, there are 2 different surrogates: `("0shot", "5shot")`, 5 different sample size `("50", "100", "250", "500", "1000")`, so the design table has 2 * 5=10 different designs, with 500 simulations for each design, so we have 10 * 500=5000 simulations in total. 

#### logit balanced
In order to estimate the total running time, we pick 6 complete design time in the simulation sequence `1-10, 101-110, 201-210, 301-310, 401-410, 491-500`, then we get the average of one complete design running time: `(128.13684035846922 + 118.0203163679171 + 86.62032775655923 + 103.72613437655139 + 103.72613437655139 + 124.90584363892385)/6=110.85593281249537`. Thus, the total running time is approximately `110.85593281249537*500=55427.96640624768`, so it will cost about `15.4` hours. 

#### logit imbalanced
In order to estimate the total running time, we pick 6 complete design time in the simulation sequence `1-10, 101-110, 201-210, 301-310, 401-410, 491-500`, then we get the average of one complete design running time: `(98.29674819428199 + 95.67371792234718 + 96.05682719713862 + 90.33044988951952 + 94.42698331516448 + 100.7813372892925)/6=95.92767730129071`. Thus, the total running time is approximately `95.92767730129071*500=47963.83865064535`, so it will cost about `13.3` hours. 

### measure
In the all measure cases, there are 6 different surrogates: `("all", "openai", "hf", "best", "text-davinci-003","flan-ul2")`, 5 different sample size `(25, 50, 100, 150, 200)`, so the design table has 6 * 5=30 different designs, with 500 simulations for each design, so we have 30 * 500=15000 simulations in total. 

Most of the dataset has about 500 observations. We pick the sample from different observations to compare the total running time.

#### 498 observations, example: multi_ibc_pos-a.csv
In order to estimate the total running time, we pick the first 10 complete design time in the simulation sequence `1-300`, that is, `10*30=300`, the first 10 complete design simulations. Then we get the average of one complete design (including 30 different designs) running time: `32.689*30=980.67`. Thus, the total running time is approximately `980.67 * 500 = 490335.0`, so it will cost about `136.2` hours. 

#### 498 observations, example: multi_ibc_pos-b.csv
In a similar way, we calculate the first 300 simulations average, so a complete design time is `32.4387*30=973.161`, so total running time is `973.161*500=486580.5`, that is about `135.2` hours.

#### 498 observations, example: multi_ibc_pos-c.csv
`34.634*15000=519510.0`, is about `144.3` hours.

#### 266 observations, example: multi_indian_english_dialect_pos-a.csv
`20.0773555184996*15000=301160.33277749404`, is about `83.7` hours.

#### 266 observations, example: multi_indian_english_dialect_pos-w.csv
`27.9304366111755*15000=418956.54916763253`, is about `116.4` hours.

#### 344 observations, example: binary_tempowic_pos-a.csv
`34.92972277768527*15000 = 523945.84166527906`, is about `145.5` hours.

#### 434 observations, example: binary_persuasion_pos-true.csv
`32.8407034890621*15000=492610.5523359315`, is about `136.8` hours.
