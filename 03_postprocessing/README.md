# `03_postprocessing`

This section contains the code used to further processing the simulation result data, and prepare data for generating figures and tables.

## Structure

The code structure is as the following:

- [logit_post_simulation_collect_rds_and_csv.R](#logit_post_simulation_collect_rds_and_csv.R)
- [measure_post_simulation_collect_rds.R](#measure_post_simulation_collect_rds.R)
- [measure_post_simulation_collect_csv.R](#measure_post_simulation_collect_csv.R)
- [logit_result_data/](#logit_result_data/)
- [measure_result_data/](#measure_result_data/)

### logit_post_simulation_collect_rds_and_csv.R
- Input: All experiment raw small rds files. (Note: we didn't put the small rds files in the replication code, because it contains 10,000 small rds files in total, and this step is only doing the rejoining procedure, so the content in the merged files are same with the raw small rds files)
- Output: A merged rds file and a merged csv file for each dataset.
- This code is the script for rejoining logit results, merging all single simulation rds files into a merged rds file and a merged csv.

### measure_post_simulation_collect_rds.R
- Input: All experiment raw small rds files. (Note: we didn't put the small rds files in the replication code, because it contains about 1110,000 small rds files in total, and this step is only doing the rejoining procedure, so the content in the merged files are same with the raw small rds files)
- Output: A merged rds file for each class of each dataset (that is, each binarized dataset).
- This code is the script for rejoining measure results, merging all single simulation rds files into a merged rds file.

### measure_post_simulation_collect_csv.R
- Input: All experiment raw small rds files. (Note: we didn't put the small rds files in the replication code, because it contains about 1110,000 small rds files in total, and this step is only doing the rejoining procedure, so the content in the merged files are same with the raw small rds files)
- Output: A merged csv file for all classes of each dataset.
- This code is the script for rejoining measure results, merging all single simulation rds files into a merged csv file. Each csv file contains all classes within the dataset.


### logit_result_data/
- contains the merged result data in rds and csv format for both balanced and imbalanced datasets.

### measure_result_data/
- contains all merged result data in rds format. Each merged rds file is for one class in one dataset (corresponding to the binarized data). For example, if we use the script in `02_experiment/run_experiment_HPC.slurm` (set `PROBLEM_TYPE <- "measure"` in the code) to run on a file `multi_discourse_pos-a.csv` in folder `01_data_and_preprocessing/measurement/binarized_datasets/` as input data, we will get the corresponding rds file such as `multi_discourse_pos-a_HPCversion_sim500_boot100.rds`.

## Running

We generally do not expect users to execute these scripts, as they are used to merge the millions of small outputs generated by our HPC simulations. We provide them primarily for continuity and transparency reasons. If the reviewer requires access to the millions of small data files outputted by the simulations, we can happily oblige.