# Simulation with Logistic Regression 

# Set working directory to source file location first.
source("../function/debias_logit.R")
source("../function/help_debias_measure.R")
require(doSNOW)

# The number of covariates 
K <- 10
# The true coefficient we set 
set.seed(100)
beta_X <- c(2, 2, rnorm(n = 8, sd = 1))

# Simulation Design 
design <- expand.grid("ss" = c(5000), # total number of documents. 
                      "read" = c(500),  # the number of hand-coded documents. 
                      "prob_prox" = c(0.5, 0.6, 0.7, 0.8, 0.9, 0.95)) # quality of proxies

sim_size <- 500 # number of simulation for each scenario
total_sim_size <- sim_size * nrow(design)

# Using Parallel Computing for simulations
start_time <- Sys.time()
cores <- parallel::detectCores() - 1
{
  cl <- makeSOCKcluster(cores, outfile = "")
  registerDoSNOW(cl)
  
  sim_out <- foreach(s = 1:total_sim_size, .combine='c', .multicombine=TRUE,
                     .packages= c("grf")) %dopar%
    ({
      message(paste("sim = ", s, "\n", sep = ""))
      
      set.seed((1234  + s))
      
      design_num <- s %% nrow(design)
      if(design_num == 0 ) design_num <- nrow(design)
      
      ss <- design[design_num, 1]
      read <- design[design_num, 2]
      prob_prox <- design[design_num, 3]
      
      # Probability of sampling documents (for now, we consider pi to be constant)
      ps_use <- read/ss
      
      # Create Data 
      X  <- MASS::mvrnorm(n = ss, mu = rep(0, K), Sigma = diag(K)) # features
      base_X <- 0.1/(1+exp(0.5*X[,3] - 0.5*X[,2])) + 1.3*X[,4]/(1+exp(-0.1*X[,2])) + 1.5*X[,4]*X[,6] + 0.5*X[,1]*X[,2] + 0.3*X[,1] + 0.2*X[,2]
      true_prob <- boot::inv.logit(-1 + base_X) 
      Y   <- rbinom(n = ss, size = 1, prob = true_prob) # the true GDP
      
      # Proxy (mimic LLM-based proxy)
      Pro_q <- rbinom(n=ss, size = 1, prob = prob_prox) # prob_prox controls the quality 
      Pro1 <- Pro_q*Y + (1-Pro_q)*(1-Y)
      
      # Combine data 
      data_use <- data.frame(cbind(Y, Pro1, X))
      colnames(data_use) <- c("Y", "pro", paste0("X", seq(1:K)))
      covariates <- "X8"
      
      # What is the logistic regression researchers want to run if they observe Y for every document 
      data_use$X1_2 <- data_use$X1^2
      for_use <- Y ~ X1 + X1_2 + X2 + X4
      true_lo <- glm(for_use, data = data_use, family = "binomial") # True Logistic Regression they want to run 
      true_lo_out <- c(coef(true_lo), summary(true_lo)$coef[,2])
      
      # Conduct Hand-coding
      data_use$ps_use <- ps_use # This is the known probability of sampling
      which_sample <- rbinom(n = nrow(data_use), size = 1, prob = ps_use) # Sample documents with the known probability 
      data_use$labeled <- which_sample 
      data_use$Y[data_use$labeled == 0] <- NA # For unlabeled units, we make outcomes to be NA.
      
      # #######################
      # Design-based Semi-Supervised Learning (DSL), the Debiased Estimators
      # #######################
      # Debiased Estimation where we estimate g(Q,X) from hand-coded data 
      out_lo <- debias_logit(formula_logit = for_use, # This is the formula researchers want to fit. 
                             outcome = "Y", # the name of the outcome 
                             proxy = "pro", # here can include multiple proxies. In our paper, surrogate Q
                             labeled = "labeled", # the column name for a binary variable indicating which unit is hand-coded. In our paper, R
                             covariates = covariates, # all covariates used to predict outcomes, in our paper, X
                             ps = "ps_use", # the column name for the known probability of sampling 
                             data = data_use, # data (should be data.frame)
                             method = "grf",  # g() in our slide: ML methods used to predict Y given Q and X.
                             cross_fit = 2, sample_split = 1, # cross-fitting and sampling-splitting, for now, keep them 2 and 1. 
                             seed = 1234 + s) # seed 
      
      res_dm_lo <- c(out_lo$dm_point, out_lo$dm_se)
      
      # #################################
      # Surrogate-Only Estimator (SO)
      # #################################
      # Note: Equation(1) in our slide
      for_use_p <- pro ~ X1 + X1_2 + X2 + X4
      lo_pro   <- glm(for_use_p, data = data_use, family = "binomial")
      Pro_lo_point <- coef(lo_pro)
      Pro_lo_se    <- summary(lo_pro)$coef[,2]
      res_Pro_lo <- c(Pro_lo_point, Pro_lo_se)
      
      out_all <- list(list("design_num" = design_num,
                           "res_Pro_lo" = res_Pro_lo,
                           "res_dm_lo" = res_dm_lo,
                           "true_lo" = true_lo_out))
    })
  stopCluster(cl)
}
end_time <- Sys.time()
cat(paste0("Time (logit) = ", end_time - start_time))
time <- gsub(" ", "-", end_time)
time <- gsub(":", "-", time)

suppressWarnings(final_out <- list("sim_out" = sim_out,
                                   "design" = design))

# Create output dir
if (!dir.exists("sim_res")){
  dir.create("sim_res")
}
saveRDS(final_out, paste0("sim_res/DGP_sim_logit_result.rds")) # save wherever you want
