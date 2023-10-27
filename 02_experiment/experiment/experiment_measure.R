# Imports
LIBS_DIR <- paste0(BASE_DIR, '02_experiment/function/')
source(paste0(LIBS_DIR, "debias_measure.R"))
source(paste0(LIBS_DIR, "impute_measure.R"))
source(paste0(LIBS_DIR, "help_debias_measure.R"))
require(survey)

### SETUP DATA
## Prepare data
data_file <- paste0(DATASET_DIR, DATASET)
data_use <- read.csv(data_file)
data_use["Y"] <- ifelse(data_use$label, 1, 0)
covariates <- c("dist_embeds")
proportional <- c(0.7, 0.3)

# Proxy choice function
choose_proxies <- function(proxy_name){
  proxy_list_all <- c(
    'q_flan-t5-small',
    'q_flan-t5-base',
    'q_flan-t5-large',
    'q_flan-t5-xl',
    'q_flan-t5-xxl',
    'q_flan-ul2',
    'q_text-ada-001',
    'q_text-babbage-001',
    'q_text-curie-001',
    'q_text-davinci-001',
    'q_text-davinci-002',
    'q_text-davinci-003',
    'q_chatgpt')
  proxy_list_hf <- proxy_list_all[grep("q_flan-", proxy_list_all)]
  proxy_list_openai <- c(proxy_list_all[grep("q_text-", proxy_list_all)], 'q_chatgpt')

  # Validate
  valid_choices <- c('all', 'hf', 'openai', 'best',  unlist(lapply(proxy_list_all, function(x) substring(x, 3))))
  stopifnot(all(proxy_name %in% valid_choices)) # Check if subset

  # Best model function
  get_best_model <- function(df){
    targets <- df['label']
    cands <- df[,grep("q_", colnames(df))]
    acc <- apply(X=cands, MARGIN=2, FUN=function(col){mean(col==targets)})
    best_col <- names(which(acc==max(acc)))
    return(best_col)
  }
  # initial out
  out <- ""
  # Parse choice
  if (proxy_name=="all") {
    out <- proxy_list_all
  } else if (proxy_name=="hf") {
    out <- proxy_list_hf
  } else if (proxy_name=="openai") {
    out <- proxy_list_openai
  } else if (proxy_name=="best") {
    out <- get_best_model(data_use)
  }else {
    out <- paste0('q_', proxy_name)
  }
  # Clean label
  out <- make.names(out)
  # Get subset of cols that are actually in data_use
  available_models <- colnames(data_use)[grep("q_", colnames(data_use))]
  out <- intersect(out, available_models)
  if (length(out) == 0) {
    warning("Invalid choice. Please choose another proxy.")
  }
  return(out)
}

design <- expand.grid(
    "ss" = nrow(data_use[1]),
    "read" = R_VALS,
    "prob_prox" = PROXY_TYPE
  )

sim_size <- SIM_SIZE
total_sim_size <- sim_size * nrow(design)

# Timing
start_time <- Sys.time()
run_ts <- strftime(start_time, "%y%m%d_%H%S")

##########
# Define simulation loop
simulation_loop <- function(s = 1,
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
  prob_prox <- as.character(choose_proxies(design[design_num, 3]))

  ps_use <- read / ss

  ## Bootstrap data (to make sure that surrogate-based estimator will also have randomness)
  boot_id  <- sample(
    x = seq(1:nrow(data_use)),
    size = nrow(data_use),
    replace = TRUE)
  data_use_base <- data_use[boot_id,]

  # Conduct Hand-coding
  data_use_base$ps_use <- ps_use # This is the known probability of sampling
  true_rate <- mean(data_use_base$Y)
  which_sample <- rbinom(n = nrow(data_use_base), size = 1, prob = ps_use)
  data_use_base$labeled <- which_sample
  data_use_base$Y[data_use_base$labeled == 0] <- NA

  # assign this data_use back
  data_use <- data_use_base

  # #######################
  # DSL Estimators
  # #######################
  # DSL, Debiased Estimation where we estimate g(Q,X) from hand-coded data
  out_dm <-
    debias_measure(
      outcome = "Y",
      proxy = prob_prox,
      labeled = "labeled",
      covariates = covariates,
      ps = "ps_use",
      data = data_use,
      method = "grf",
      cross_fit = 2,
      sample_split = 5,
      seed = 1234 + s)

  res_dm <- c(out_dm$dm_point, out_dm$dm_se)

  # DSL, Debiased Estimation where we use g(Q,X) = Q, so there is no additional estimation.
  out_direct <-
    debias_measure_direct(
      outcome = "Y",
      proxy = prob_prox, #"pro",
      labeled = "labeled",
      covariates = covariates,
      ps = "ps_use",
      data = data_use)

  res_dm_dir <- c(out_direct$dm_point, out_direct$dm_se)

  # ##################################
  # SSL, Typical Semi-supervised Learning
  # ##################################
  out_PI <-
    impute_measure(
      outcome = "Y",
      proxy = prob_prox, #"pro",
      labeled = "labeled",
      covariates = covariates,
      ps = "ps_use",
      boot = n_bootstrap,
      data = data_use)

  res_PI <- c(out_PI$PI_point, out_PI$PI_se)

  # #################################
  # SO, Surrogate Only Estimator
  # #################################
  data_use$proxy_avg <- apply(data_use[, prob_prox, drop = FALSE], 1, mean)
  Pro_point <- mean(data_use$proxy_avg)
  Pro_se    <- sd(data_use$proxy_avg)/sqrt(nrow(data_use))
  res_Pro <- c(Pro_point, Pro_se)

  # #################################
  # GSO (only using the labeled dataset), also known as supervised learning estimator
  # #################################
  Y_R <- as.numeric(data_use$Y[data_use$labeled == 1])
  IPW_point <- mean(Y_R)
  IPW_se    <- sd(Y_R)/sqrt(length(Y_R))
  res_IPW <- c(IPW_point, IPW_se)

  out_all <- list(
    list(
      "design_num" = design_num,
      "res_Pro_lo" = res_Pro,
      "res_IPW_lo" = res_IPW,
      "res_PI_lo" = res_PI,
      "res_dm_lo" = res_dm,
      "res_dm_dir_lo" = res_dm_dir,
      "true_lo" = true_rate
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
