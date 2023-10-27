# Set working directory to current source file location first.

#setwd(dirname(rstudioapi::getActiveDocumentContext()$path)) # if you are using RStudio
setwd("/<PATH>/<TO>/<SOURCE>/<FILE>/")

file_path <- "../03_postprocessing/logit_result_data/" # here is the directory for the merged simulation rds file
raw_file_path <- "../01_data_and_preprocessing/logit/cbp_data/"


generate_logit_se_table <- function(final_out, graph_head_str, raw_data) {
  sim_out <- final_out[[1]]
  design_table <- final_out[[2]]
  total_sim_size <- length(final_out[[1]])
  
  length(final_out[[1]])/nrow(design_table)
  design_table
  
  {
    ind <- unlist(sapply(seq(1:total_sim_size), function(x) sim_out[[x]][[1]]))
    
    res_Pro <- do.call("rbind", lapply(seq(1:total_sim_size),
                                       FUN = function(x) sim_out[[x]][[2]]))
    
    res_IPW <- do.call("rbind", lapply(seq(1:total_sim_size),
                                       FUN = function(x) sim_out[[x]][[3]]))
    
    res_PI <- do.call("rbind", lapply(seq(1:total_sim_size),
                                      FUN = function(x) sim_out[[x]][[4]]))
    
    res_dm <- do.call("rbind", lapply(seq(1:total_sim_size),
                                      FUN = function(x) sim_out[[x]][[5]]))
    
    res_dm_dir <- do.call("rbind", lapply(seq(1:total_sim_size),
                                          FUN = function(x) sim_out[[x]][[6]]))
    
    # TRUE
    true <- do.call("rbind", lapply(seq(1:total_sim_size),
                                    FUN = function(x) sim_out[[x]][[7]]))
  }
  
  # get the oracle true coef first.
  raw_data["y"] <- ifelse(raw_data$label, 1, 0)
  for_use_formula <- y ~ senate + democrat + dw1
  lo_oracle   <- glm(for_use_formula, data = raw_data, family = "binomial")
  lo_oracle_point <- coef(lo_oracle)
  lo_oracle_se    <- summary(lo_oracle)$coef[, 2]
  res_lo_oracle <- c(lo_oracle_point, lo_oracle_se)
  
  true_coef <- lo_oracle_point
  true_coef_base_i <- apply(as.data.frame(true_coef), 2, function(x) sqrt(mean(x^2)))
  
  
  ## RMSE Winners (Bootstrap)
  # RMSE Bootstrap 
  set.seed(123) 
  
  RMSE_winner <- matrix(NA, nrow = 4, ncol = nrow(design_table))
  RMSE_boot <- list()
  bias_boot <- list()
  coverage_boot <- list()
  
  ncol_X <- dim(res_dm)[2]/2
  for(i in 1:nrow(design_table)){
    # true_coef <- apply(true[ind == i, 1:ncol_X], 2, mean)
    # true_coef_base_i <- apply(as.data.frame(true_coef), 2, function(x) sqrt(mean(x^2)))
    
    #true_i    <- mean(true[ind == i])
    sim_size  <- sum(ind == i) 
    
    RMSE_boot[[i]] <- matrix(NA, nrow = 1000, ncol = 4)
    bias_boot[[i]] <- matrix(NA, nrow = 1000, ncol = 4)
    coverage_boot[[i]] <- matrix(NA, nrow = 1000, ncol = 4)
    
    RMSE_boot_Pro <- RMSE_boot_IPW <- RMSE_boot_PI <- RMSE_boot_dm <- c()
    bias_boot_Pro <- bias_boot_IPW <- bias_boot_PI <- bias_boot_dm <- c()
    coverage_boot_Pro <- coverage_boot_IPW <- coverage_boot_PI <- coverage_boot_dm <- c()
    RMSE_winner_base <- matrix(0, nrow = 4, ncol = 1000)
    for(bo in 1:1000){
      boot_id   <- sample(x = seq(1:sim_size), size = sim_size, replace = TRUE)
      
      # RMSE
      compare_lm_Pro_i <- apply(res_Pro[ind == i, 1:ncol_X][boot_id,], 2, mean) - true_coef
      compare_lm_Pro_sd_i <- apply(res_Pro[ind == i, 1:ncol_X][boot_id,], 2, sd)
      compare_lm_IPW_i <- apply(res_IPW[ind == i, 1:ncol_X][boot_id,], 2, mean) - true_coef
      compare_lm_IPW_sd_i <- apply(res_IPW[ind == i, 1:ncol_X][boot_id,], 2, sd)
      compare_lm_PI_i <- apply(res_PI[ind == i, 1:ncol_X][boot_id,], 2, mean) - true_coef
      compare_lm_PI_sd_i <- apply(res_PI[ind == i, 1:ncol_X][boot_id,], 2, sd)
      compare_lm_dm_i <- apply(res_dm[ind == i, 1:ncol_X][boot_id,], 2, mean) - true_coef
      compare_lm_dm_sd_i <- apply(res_dm[ind == i, 1:ncol_X][boot_id,], 2, sd)
      
      # RMSE for each coefficient separately 
      RMSE_Pro0 <- sqrt(compare_lm_Pro_sd_i^2 + compare_lm_Pro_i^2)
      RMSE_IPW0 <- sqrt(compare_lm_IPW_sd_i^2 + compare_lm_IPW_i^2)
      RMSE_PI0 <- sqrt(compare_lm_PI_sd_i^2 + compare_lm_PI_i^2)
      RMSE_dm0 <- sqrt(compare_lm_dm_sd_i^2 + compare_lm_dm_i^2)
      
      # Average Across Coefficients
      RMSE_Pro <- mean(RMSE_Pro0)
      RMSE_IPW <- mean(RMSE_IPW0)
      RMSE_PI  <- mean(RMSE_PI0)
      RMSE_dm  <- mean(RMSE_dm0)
      
      # # separate coefficients
      # RMSE_Pro_coef1 <- RMSE_Pro0[,1] 
      # RMSE_IPW_coef1 <- RMSE_IPW0[,1]
      
      RMSE_boot_Pro[bo] <- RMSE_Pro
      RMSE_boot_IPW[bo] <- RMSE_IPW
      RMSE_boot_PI[bo] <- RMSE_PI
      RMSE_boot_dm[bo] <- RMSE_dm
      
      who_won <- which.min(c(RMSE_boot_Pro[bo], RMSE_boot_IPW[bo], RMSE_boot_PI[bo], RMSE_boot_dm[bo]))
      RMSE_winner_base[who_won, bo] <- 1
      
      # bias
      bias_boot_Pro[bo] <- sqrt(mean(compare_lm_Pro_i^2))/true_coef_base_i
      bias_boot_IPW[bo] <- sqrt(mean(compare_lm_IPW_i^2))/true_coef_base_i 
      bias_boot_PI[bo]  <- sqrt(mean(compare_lm_PI_i^2))/true_coef_base_i 
      bias_boot_dm[bo]  <- sqrt(mean(compare_lm_dm_i^2))/true_coef_base_i 
      
      # coverage
      # Pro
      ci_low <- apply(res_Pro[ind == i, 1:ncol_X][boot_id,] - 1.96*res_Pro[ind == i, ncol_X + (1:ncol_X)][boot_id,], 1, function(x) x <= true_coef)
      ci_high <- apply(res_Pro[ind == i, 1:ncol_X][boot_id,] + 1.96*res_Pro[ind == i, ncol_X + (1:ncol_X)][boot_id,], 1, function(x) x >= true_coef)
      compare_lm_Pro_ci_i <- apply(ci_low*ci_high, 1, mean)
      
      # IPW
      ci_low <- apply(res_IPW[ind == i, 1:ncol_X][boot_id,] - 1.96*res_IPW[ind == i, ncol_X + (1:ncol_X)][boot_id,], 1, function(x) x <= true_coef)
      ci_high <- apply(res_IPW[ind == i, 1:ncol_X][boot_id,] + 1.96*res_IPW[ind == i, ncol_X + (1:ncol_X)][boot_id,], 1, function(x) x >= true_coef)
      compare_lm_IPW_ci_i <- apply(ci_low*ci_high, 1, mean)
      
      # PI
      ci_low <- apply(res_PI[ind == i, 1:ncol_X][boot_id,] - 1.96*res_PI[ind == i, ncol_X + (1:ncol_X)][boot_id,], 1, function(x) x <= true_coef)
      ci_high <- apply(res_PI[ind == i, 1:ncol_X][boot_id,] + 1.96*res_PI[ind == i, ncol_X + (1:ncol_X)][boot_id,], 1, function(x) x >= true_coef)
      compare_lm_PI_ci_i <- apply(ci_low*ci_high, 1, mean)
      
      # DM
      ci_low <- apply(res_dm[ind == i, 1:ncol_X][boot_id,] - 1.96*res_dm[ind == i, ncol_X + (1:ncol_X)][boot_id,], 1, function(x) x <= true_coef)
      ci_high <- apply(res_dm[ind == i, 1:ncol_X][boot_id,] + 1.96*res_dm[ind == i, ncol_X + (1:ncol_X)][boot_id,], 1, function(x) x >= true_coef)
      compare_lm_dm_ci_i <- apply(ci_low*ci_high, 1, mean)
      
      coverage_boot_Pro[bo] <- mean(compare_lm_Pro_ci_i)
      coverage_boot_IPW[bo] <- mean(compare_lm_IPW_ci_i)
      coverage_boot_PI[bo]  <- mean(compare_lm_PI_ci_i)
      coverage_boot_dm[bo]  <- mean(compare_lm_dm_ci_i)
      
      RMSE_boot[[i]][bo, 1:4] <- 
        c(RMSE_boot_Pro[bo], RMSE_boot_IPW[bo], RMSE_boot_PI[bo], RMSE_boot_dm[bo])
      bias_boot[[i]][bo, 1:4] <- 
        c(bias_boot_Pro[bo], bias_boot_IPW[bo], bias_boot_PI[bo], bias_boot_dm[bo])
      coverage_boot[[i]][bo, 1:4] <- 
        c(coverage_boot_Pro[bo], coverage_boot_IPW[bo], coverage_boot_PI[bo], coverage_boot_dm[bo])
    }
    RMSE_winner[1:4, i] <- apply(RMSE_winner_base, 1, mean)
  }
  rownames(RMSE_winner) <- c("Proxy", "IPW", "Semi-supervised", "DSL")
  
  RMSE_point <- matrix(NA, nrow = nrow(design_table), ncol = 4)
  RMSE_se    <- matrix(NA, nrow = nrow(design_table), ncol = 4)
  bias_point <- matrix(NA, nrow = nrow(design_table), ncol = 4)
  bias_se    <- matrix(NA, nrow = nrow(design_table), ncol = 4)
  coverage_point <- matrix(NA, nrow = nrow(design_table), ncol = 4)
  coverage_se    <- matrix(NA, nrow = nrow(design_table), ncol = 4)
  for(i in 1:nrow(design_table)){
    RMSE_point[i, 1:4] <- apply(RMSE_boot[[i]][, 1:4], 2, mean)
    RMSE_se[i, 1:4]    <- apply(RMSE_boot[[i]][, 1:4], 2, sd)
    bias_point[i, 1:4] <- apply(bias_boot[[i]][, 1:4], 2, mean)
    bias_se[i, 1:4]    <- apply(bias_boot[[i]][, 1:4], 2, sd)
    coverage_point[i, 1:4] <- apply(coverage_boot[[i]][, 1:4], 2, mean)
    coverage_se[i, 1:4]    <- apply(coverage_boot[[i]][, 1:4], 2, sd)
  }
  colnames(RMSE_point) <- c("RMSE_point_SO", "RMSE_point_GSO", "RMSE_point_SSL", "RMSE_point_DSL")
  colnames(RMSE_se) <- c("RMSE_se_SO", "RMSE_se_GSO", "RMSE_se_SSL", "RMSE_se_DSL")
  colnames(bias_point) <- c("bias_point_SO", "bias_point_GSO", "bias_point_SSL", "bias_point_DSL")
  colnames(bias_se) <- c("bias_se_SO", "bias_se_GSO", "bias_se_SSL", "bias_se_DSL")
  colnames(coverage_point) <- c("coverage_point_SO", "coverage_point_GSO", "coverage_point_SSL", "coverage_point_DSL")
  colnames(coverage_se) <- c("coverage_se_SO", "coverage_se_GSO", "coverage_se_SSL", "coverage_se_DSL")
  
  result_table <- cbind(design_table, bias_point, bias_se, coverage_point, coverage_se, RMSE_point, RMSE_se)
  
  if (!dir.exists("table")) {
    dir.create("table")
  } 
  
  if (!dir.exists("table/logit")) {
    dir.create("table/logit")
  } 
  
  # store the standard error table
  se_result <- result_table[result_table$read %in% c(50, 100, 250, 500, 1000) & result_table$prob_prox %in% c("0shot", "5shot"), ]
  write.csv(se_result, paste0("table/logit/",graph_head_str,"_logit_table.csv"))
}


# Generate logit se table

# balanced
final_out <- readRDS(file = paste0(file_path, "logit_balanced_sim500_boot100.rds")) # read the merged balanced rds file, file name may be different and need to update
graph_head_str <-  "logit_balanced"
raw_data <- read.csv(paste0(raw_file_path, "cbp_easy_with_proxies.csv"))

generate_logit_se_table(final_out, graph_head_str, raw_data)

# imbalanced
final_out <- readRDS(file = paste0(file_path, "logit_imbalanced_sim500_boot100.rds")) # read the merged imbalanced rds file, file name may be different and need to update 
graph_head_str <-  "logit_imbalanced"
raw_data <- read.csv(paste0(raw_file_path, "cbp_imbalanced_with_proxies.csv"))

generate_logit_se_table(final_out, graph_head_str, raw_data)



