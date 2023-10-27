# IMPORTS
LIBS_DIR <- paste0(BASE_DIR, '02_experiment/function/')
setwd(SCRIPT_DIR)
source(paste0(LIBS_DIR, "debias_logit.R"))
source(paste0(LIBS_DIR, "impute_logit.R"))
source(paste0(LIBS_DIR, "help_debias_measure.R"))
require(doSNOW)
require(survey)

# Create OUT_DIR for simulation if doesn't exist
if (!dir.exists(OUT_DIR)){
  dir.create(OUT_DIR, recursive=TRUE)
} 

set.seed(100)

##########
### SETUP DATA
## function: create dummy columns
create_dummy_vars <- function(df, col_names) {
  new_colnames_list <- c()
  
  for (col_name in col_names) {
    df[[col_name]] <- factor(df[[col_name]])
    dummy_vars <- model.matrix( ~ 0 + df[[col_name]])
    
    # generate unique names for the new columns
    num_levels <- nlevels(df[[col_name]])
    col_suffixes <- seq_len(num_levels)
    col_prefix <- paste0("X", "_", col_name)
    new_colnames <- paste0(col_prefix, col_suffixes)
    print(new_colnames)
    colnames(dummy_vars) <- new_colnames
    
    # add the dummy variables to the dataframe
    df <- cbind(df, dummy_vars)
    new_colnames_list <- c(new_colnames_list, new_colnames)
  }
  return(list(df, new_colnames_list))
}

## Prepare data
data_file <- ifelse(DATASET=='easy',
                    "../../01_data_and_preprocessing/logit/cbp_data/cbp_easy_with_proxies.csv",
                    "../../01_data_and_preprocessing/logit/cbp_data/cbp_imbalanced_with_proxies.csv" )
data_use <- read.csv(data_file)
data_use["Y"] <- ifelse(data_use$label, 1, 0)

# change category column into mutiple dummy columns and store all available variables into "covariates".
new_data <- create_dummy_vars(data_use, c("Postal"))
data_use <- new_data[[1]]
covariates_X_list <- new_data[[2]]
covariates <-
  c(
    covariates_X_list,
    "female",
    "senate",
    "democrat",
    "dw1",
    "year",
    "pass_h",
    "pass_s",
    "dist_macro"
  )

# remove some columns to avoid collinerity
names_to_remove <- c("X_Postal1")
covariates <- covariates[!covariates %in% names_to_remove]

## zero shot and five-shot versions
data_use["pro"] <- ifelse(data_use$q_gpt3_0shot, 1, 0)
data_use_original <- data_use # store the data  - zeroshot
data_use["pro"] <- ifelse(data_use$q_gpt3_5shot, 1, 0)
data_use_original_few_shot <- data_use # store the data

subgroups <- expand.grid("pro" = c(0, 1))
data_sub  <- list()
for (i in 1:nrow(subgroups)) {
  data_sub[[i]] <- subset(data_use, subset = (pro == subgroups[i, 1]))
}
unlist(lapply(data_sub, nrow))
proportional <- c(0.7, 0.3)

### Simulation Design
design <-
  expand.grid(
    "ss" = nrow(data_use[1]),
    # total number of documents.
    "read" = R_VALS,
    "prob_prox" = c("0shot", "5shot")
  ) # quality of proxies

sim_size <- SIM_SIZE
total_sim_size <- sim_size * nrow(design)

# Timing
start_time <- Sys.time()
run_ts <- strftime(start_time, "%y%m%d_%H%S")

##########
# Define simulation loop
simulation_loop <- function(s = 1,
                            # simulation number, scalar/int
                            for_use = as.formula(Y ~ senate + democrat + dw1),
                            # formula
                            n_bootstrap = N_BOOTSTRAP) {
  loop_start_time <- Sys.time()
  ## Init params for loop
  message(paste("Beginning sim = ", s, "/", total_sim_size, "\n", sep = ""))
  set.seed((1234  + s))
  design_num <- s %% nrow(design)
  if (design_num == 0)
    design_num <- nrow(design)
  
  # Read in from design
  ss <- design[design_num, 1]
  read <- design[design_num, 2]
  prob_prox <- design[design_num, 3]
  
  ps_use <-
    read / ss # Probability of sampling documents (we consider pi to be constant)
  
  ## Select dataset w/ prob_prox
  if (prob_prox == "0shot") {
    data_use0 <- data_use_original #data_use_original_zero_shot
  } else if (prob_prox == "5shot") {
    data_use0 <- data_use_original_few_shot
  }
  
  ## Bootstrap data (to make sure that surrogate-based estimator will also have randomness)
  boot_id  <-
    sample(
      x = seq(1:nrow(data_use0)),
      size = nrow(data_use0),
      replace = TRUE
    )
  data_use_base <- data_use0[boot_id,]
  
  ## Define true logistic regression
  true_lo <-
    glm(for_use, data = data_use_base, family = "binomial") # True model
  true_lo_out <-
    c(coef(true_lo), summary(true_lo)$coef[, 2]) # c(Coefs, SEs)
  
  ## Hand-coding - create `labeled`, `ps_use`, `weights_use`
  subgroups <- expand.grid("pro" = c(0, 1))
  data_sub  <- list()
  for (i in 1:nrow(subgroups)) {
    data_sub[[i]] <-
      subset(data_use_base, subset = (pro == subgroups[i, 1]))
  }
  sample_read <- round(read * proportional)
  
  for (i in 1:2) {
    data_sub[[i]] <-
      subset(data_use_base, subset = (pro == subgroups[i, 1]))
    ps_use_i      <- sample_read[i] / nrow(data_sub[[i]])
    which_sample <-
      rbinom(n = nrow(data_sub[[i]]),
             size = 1,
             prob = ps_use_i) # Sample documents with the known probability
    data_sub[[i]]$labeled <- which_sample
    data_sub[[i]]$Y[data_sub[[i]]$labeled == 0] <-
      NA # For unlabeled units, we make outcomes to be NA.
    data_sub[[i]]$ps_use <- ps_use_i
  }
  data_use <-
    do.call(rbind, data_sub) # recombine sampled/unsampled units
  data_use$weights_use <-  1 / data_use$ps_use # weights
  
  # #######################
  # DSL Estimators
  # #######################
  # DSL estimator, Debiased Estimation where we estimate g(Q,X) from hand-coded data
  out_lo <-
    debias_logit(
      formula_logit = for_use,
      # This is the formula researchers want to fit.
      outcome = "Y",
      # the name of the outcome
      proxy = "pro",
      # here can include multiple proxies. In our paper, Q
      labeled = "labeled",
      # the column name for a binary variable indicating which unit is hand-coded. In our paper, R
      covariates = covariates,
      # all covariates used to predict outcomes, in our paper, X
      ps = "ps_use",
      # the column name for the known probability of sampling
      data = data_use,
      # data (should be data.frame)
      method = "grf",
      # g() in our slide: ML methods used to predict Y given Q and X.
      cross_fit = 5,
      sample_split = 5,
      # cross-fitting and sampling-splitting.
      seed = 1234 + s
    ) # seed
  
  res_dm_lo <- c(out_lo$dm_point, out_lo$dm_se)
  
  # DSL with direct Q, Debiased Estimation where we use g(Q,X) = Q, so there is no additional estimation.
  out_lo_direct <-
    debias_logit_direct(
      formula_logit = for_use,
      # This is the formula researchers want to fit.
      outcome = "Y",
      # the name of the outcome
      proxy = "pro",
      # here can include multiple proxies. In our paper, Q
      labeled = "labeled",
      # the column name for a binary variable indicating which unit is hand-coded. In our paper, R
      covariates = covariates,
      # all covariates used to predict outcomes, in our paper, X
      ps = "ps_use",
      # the column name for the known probability of sampling
      data = data_use
    ) # data (should be data.frame)
  
  res_dm_dir_lo <- c(out_lo_direct$dm_point, out_lo_direct$dm_se)
  
  # ##################################
  # SSL, Typical Semi-supervised Learning
  # ##################################
  out_lo_PI <-
    impute_logit(
      formula_logit = for_use,
      # This is the formula researchers want to fit.
      outcome = "Y",
      # the name of the outcome
      proxy = "pro",
      # here can include multiple proxies. In our paper, Q
      labeled = "labeled",
      # the column name for a binary variable indicating which unit is hand-coded. In our paper, R
      covariates = covariates,
      # all covariates used to predict outcomes, in our paper, X
      ps = "ps_use",
      # the column name for the known probability of sampling
      boot = n_bootstrap,
      # the number of bootstrap
      data = data_use
    ) # data (should be data.frame)
  
  res_PI_lo <- c(out_lo_PI$PI_point, out_lo_PI$PI_se)
  
  # #################################
  # SO estimator, Surrogate Only
  # #################################
  for_use_p <- pro ~ senate + democrat + dw1
  lo_pro   <- glm(for_use_p, data = data_use, family = "binomial")
  Pro_lo_point <- coef(lo_pro)
  Pro_lo_se    <- summary(lo_pro)$coef[, 2]
  res_Pro_lo <- c(Pro_lo_point, Pro_lo_se)
  
  # #################################
  # GSO (only using the labeled dataset), also known as supervised learning estimator
  # #################################
  data_ipw <- data_use[data_use$labeled == 1,]
  d_use  <-
    svydesign(id = ~ 1,
              weights = ~ weights_use,
              data = data_ipw)
  lo_ipw <-
    svyglm(for_use, design = d_use, family = "quasibinomial")
  IPW_lo_point <- coef(lo_ipw)
  IPW_lo_se    <- summary(lo_ipw)$coef[, 2]
  res_IPW_lo <- c(IPW_lo_point, IPW_lo_se)
  
  out_all <- list(
    list(
      "design_num" = design_num,
      "res_Pro_lo" = res_Pro_lo,
      "res_IPW_lo" = res_IPW_lo,
      "res_PI_lo" = res_PI_lo,
      "res_dm_lo" = res_dm_lo,
      "res_dm_dir_lo" = res_dm_dir_lo,
      "true_lo" = true_lo_out
    )
  )
  # Save to file
  sim_num_str <-
    stringr::str_pad(s, 1 + floor(log10(total_sim_size)), pad = "0")
  saveRDS(
    out_all,
    paste0(
      OUT_DIR,
      "/",
      run_ts,
      "_",
      tolower(DATASET),
      "_HPC_sim",
      SIM_SIZE,
      "_boot",
      N_BOOTSTRAP,
      "_sim",
      sim_num_str,
      ".rds"
    )
  )
  # End timing
  loop_end_time <- Sys.time()
  message(paste0("Time (loop) = ", loop_end_time - loop_start_time))
  return(out_all)
}

