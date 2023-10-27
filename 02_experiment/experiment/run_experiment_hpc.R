#!/usr/bin/R
## Script Configs - CHECK OUT_DIR!

# Params
PROBLEM_TYPE <- "measure" # "measure" or "logit"
DATASET <- 'binary_conv_go_awry_pos-yes.csv' # NOTE: For measure case, input the full file name to DATASET here; For logit case, the DATASET should be "easy" or "imbalanced" (easy represent balanced case).
PROXY_TYPE <- c("all", "openai", "hf", "best", "text-davinci-003","flan-ul2") # options: "all", "best","hf", "openai","flan-t5-small", "flan-t5-base", "flan-t5-large", "flan-t5-xl","flan-t5-xxl","flan-ul2","text-ada-001","text-babbage-001","text-curie-001","text-davinci-001","text-davinci-002","text-davinci-003","chatgpt"
SIM_SIZE <- 500 # number of simulation
N_BOOTSTRAP <- 100 # number of bootstrap
OUT_FOLDER <- "run_001" # output folder

# Directories
BASE_DIR = '<PATH>/<TO>/<REPO>/replication/' # base dir, where the project code located
SCRIPT_DIR <- paste0(BASE_DIR, '02_experiment/experiment/')
DATASET_DIR <- paste0(BASE_DIR, '01_data_and_preprocessing/measurement/binarized_datasets/')
OUT_DIR <- paste0(BASE_DIR, '02_experiment/experiment/', OUT_FOLDER)

## Source
setwd(SCRIPT_DIR)
if (PROBLEM_TYPE == "measure") {
    if (!grepl(".csv", DATASET)) {
        stop("Invalid DATASET for PROBLEM_TYPE 'measure', you must input the full csv file name.")
    }
    R_VALS <- c(25, 50, 100, 150, 200) # Number of documents to read
    source("experiment_measure.R")
} else if (PROBLEM_TYPE == "logit") {
    if (!(DATASET %in% c("easy", "imbalanced"))) {
        stop("Invalid DATASET for PROBLEM_TYPE 'logit', you must choose 'easy' or 'imbalanced'")
    }
    R_VALS <- c(50, 100, 250, 500, 1000) # Number of documents to read
    source("experiment_logit.R")
} else {
    stop("Invalid PROBLEM_TYPE")
}

## Run
# Create OUT_DIR
if (!dir.exists(OUT_DIR)){
  dir.create(OUT_DIR)
} 

# Read job array info
job_idx <- as.numeric(Sys.getenv("SLURM_ARRAY_TASK_ID"))
n_jobs <- as.numeric(Sys.getenv("SLURM_ARRAY_TASK_COUNT"))

# Map from job_idx to sim_num
n_sims <- total_sim_size
n_tasks <-  floor(n_sims/n_jobs)
remainder <- n_sims%%n_jobs
jobs <- (n_tasks*(job_idx-1)+1):(n_tasks*(job_idx))
if (job_idx<=remainder) {
  jobs <- c(jobs, n_jobs*n_tasks+job_idx)
}

# Run
for (idx in jobs){
  out <- tryCatch(
    {simulation_loop(s=idx)},
    error=function(e){
      message(paste0("ERROR: ", e))
      return(NULL)},
    warning=function(w){
      message(paste0("WARNING: ", w))
      return(NULL)}
  )
}
