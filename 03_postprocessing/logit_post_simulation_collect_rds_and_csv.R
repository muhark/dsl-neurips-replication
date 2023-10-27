#!/usr/bin/R
# Rejoining simulation results
# Script for rejoining logit results, merging all single simulation rds files into a merged rds file and a merged csv.

# Set working directory to current source file location first.
#setwd(dirname(rstudioapi::getActiveDocumentContext()$path)) # if you are using RStudio
setwd("/<PATH>/<TO>/<SOURCE>/<FILE>/")

# Set the results directory as the balanced (or imbalanced) simulation result folder
results_dir <-"<PATH>/<TO>/<REPO>/<OUT_FOLDER>/" 

# Read results
out_files <- list.files(results_dir)
out_order <-  sapply(out_files, function(f){
  as.numeric(regmatches(f,  regexec("sim([0-9]{4})\\.rds", f))[[1]][2])
})
out_files <- out_files[order(out_order)]
sim_out <- sapply(out_files, function(x){readRDS(paste0(results_dir, x))})

# Add design
design <- expand.grid(
  "ss" = 5000,
  "read" = c(50, 100, 250, 500, 1000),
  "prob_prox" = c("0shot", "5shot"))


# Create final out file
final_out <- list("sim_out" = sim_out, "design" = design)
final_file <- gsub("_(sim)?[0-9]{4}", "", out_files[1]) 
saveRDS(final_out, final_file)

# Create a non-RDS version
entry <- sim_out[[1]]
# coef x4, se x4
sim_df <- lapply(sim_out, function(entry){
  
  coef_df <- dplyr::as_tibble(
    t(as.data.frame(entry)[, 2:7]))
  colnames(coef_df) <-
    c(
      "beta_0",
      "beta_senate",
      "beta_democrat",
      "beta_dw1",
      "se_0",
      "se_senate",
      "se_democrat",
      "se_dw1"
    )
  coef_df <- cbind(
    tibble::tibble(
      design_num = as.numeric(rep(entry$design_num, nrow(coef_df))),
      estimator = names(entry)[2:7]
    ),
    coef_df
  )
 coef_df 
  
  coef_df$design_num <- as.numeric(rep(entry$design_num, nrow(coef_df)))
  coef_df$estimator <- names(entry)[2:7]

  return(coef_df)
  })

sim_df <- dplyr::bind_rows(sim_df, .id="source_file")
# dplyr::select(sim_df, -source_file)
sim_df$sim_num <- sapply(sim_df$source_file, function(f){
  as.numeric(regmatches(f,  regexec("sim([0-9]{4})\\.rds", f))[[1]][2])
})

readr::write_csv(sim_df, gsub("rds$", "csv", final_file))