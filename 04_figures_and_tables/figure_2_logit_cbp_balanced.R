# Set working directory to current source file location first.

#setwd(dirname(rstudioapi::getActiveDocumentContext()$path)) # if you are using RStudio
setwd("/<PATH>/<TO>/<SOURCE>/<FILE>/")

easy_data <- read.csv(file = "../03_postprocessing/logit_result_data/logit_balanced_sim500_boot100.csv")

design_table <- expand.grid("ss" = 10000, # total number of documents.
    "read" = c(50, 100, 250, 500, 1000),
    "prob_prox" = c("0shot", "5shot")
     )

## lm 
ncol_X <- 4

compare_lm_Pro <- matrix(NA, nrow = nrow(design_table), ncol = ncol_X)
compare_lm_IPW <- matrix(NA, nrow = nrow(design_table), ncol = ncol_X)
compare_lm_PI <- matrix(NA, nrow = nrow(design_table), ncol = ncol_X)
compare_lm_dm <- matrix(NA, nrow = nrow(design_table), ncol = ncol_X)

compare_lm_Pro_ci <- matrix(NA, nrow = nrow(design_table), ncol = ncol_X)
compare_lm_IPW_ci <- matrix(NA, nrow = nrow(design_table), ncol = ncol_X)
compare_lm_PI_ci <- matrix(NA, nrow = nrow(design_table), ncol = ncol_X)
compare_lm_dm_ci <- matrix(NA, nrow = nrow(design_table), ncol = ncol_X)

compare_lm_Pro_sd <- matrix(NA, nrow = nrow(design_table), ncol = ncol_X)
compare_lm_IPW_sd <- matrix(NA, nrow = nrow(design_table), ncol = ncol_X)
compare_lm_PI_sd <- matrix(NA, nrow = nrow(design_table), ncol = ncol_X)
compare_lm_dm_sd <- matrix(NA, nrow = nrow(design_table), ncol = ncol_X)

true_coef_mat <- matrix(NA, nrow = nrow(design_table), ncol = ncol_X)

ind <- easy_data$design_num
coef_name <- c("beta_0", "beta_senate", "beta_democrat", "beta_dw1")
se_name <- c("se_0", "se_senate", "se_democrat", "se_dw1")

for(i in 1:nrow(design_table)){
  
  # TRUE_coef
  true_d <- easy_data[easy_data$design_num == i & easy_data$estimator == "true_lo", ] 
  true_coef_mat[i, 1:4] <- true_coef <- apply(true_d[, coef_name], 2, mean)
  
  # SO
  res_Pro <- easy_data[easy_data$design_num == i & easy_data$estimator == "res_Pro_lo", ] 
  
  compare_lm_Pro[i, 1:4] <- apply(res_Pro[, coef_name], 2, mean) - true_coef
  ci_low <- apply(res_Pro[, coef_name] - 1.96*res_Pro[, se_name], 1, function(x) x <= true_coef)
  ci_high <- apply(res_Pro[, coef_name] + 1.96*res_Pro[, se_name], 1, function(x) x >= true_coef)
  compare_lm_Pro_ci[i, 1:4] <- apply(ci_low*ci_high, 1, mean)
  compare_lm_Pro_sd[i, 1:4] <- apply(res_Pro[, coef_name], 2, sd)
  
  # GSO
  res_IPW <- easy_data[easy_data$design_num == i & easy_data$estimator == "res_IPW_lo", ] 
  
  compare_lm_IPW[i, 1:4] <- apply(res_IPW[, coef_name], 2, mean) - true_coef
  ci_low <- apply(res_IPW[, coef_name] - 1.96*res_IPW[, se_name], 1, 
                  function(x) x <= true_coef)
  ci_high <- apply(res_IPW[, coef_name] + 1.96*res_IPW[, se_name], 1, 
                   function(x) x >= true_coef)
  compare_lm_IPW_ci[i, 1:4] <- apply(ci_low*ci_high, 1, mean)
  compare_lm_IPW_sd[i, 1:4] <- apply(res_IPW[, coef_name], 2, sd)
  
  # SSL
  res_PI <- easy_data[easy_data$design_num == i & easy_data$estimator == "res_PI_lo", ] 
  
  compare_lm_PI[i, 1:4] <- apply(res_PI[, coef_name], 2, mean) - true_coef
  ci_low <- apply(res_PI[, coef_name] - 1.96*res_PI[, se_name], 1, 
                  function(x) x <= true_coef)
  ci_high <- apply(res_PI[, coef_name] + 1.96*res_PI[, se_name], 1, 
                   function(x) x >= true_coef)
  compare_lm_PI_ci[i, 1:4] <- apply(ci_low*ci_high, 1, mean)
  compare_lm_PI_sd[i, 1:4] <- apply(res_PI[, coef_name], 2, sd)
  
  # DSL
  res_dm <- easy_data[easy_data$design_num == i & easy_data$estimator == "res_dm_lo", ] 
  
  compare_lm_dm[i, 1:4] <- apply(res_dm[, coef_name], 2, mean) - true_coef
  ci_low <- apply(res_dm[, coef_name] - 1.96*res_dm[, se_name], 1, 
                  function(x) x <= true_coef)
  ci_high <- apply(res_dm[, coef_name] + 1.96*res_dm[, se_name], 1, 
                   function(x) x >= true_coef)
  compare_lm_dm_ci[i, 1:4] <- apply(ci_low*ci_high, 1, mean)
  compare_lm_dm_sd[i, 1:4] <- apply(res_dm[, coef_name], 2, sd)
}

# standardize
true_coef_base <- apply(true_coef_mat, 1, function(x) sqrt(mean(x^2)))

# RMSE
RMSE_Pro <- apply(sqrt(compare_lm_Pro_sd^2 + compare_lm_Pro^2), 1, mean)
RMSE_IPW <- apply(sqrt(compare_lm_IPW_sd^2 + compare_lm_IPW^2), 1, mean)
RMSE_PI <- apply(sqrt(compare_lm_PI_sd^2 + compare_lm_PI^2), 1, mean)
RMSE_dm <- apply(sqrt(compare_lm_dm_sd^2 + compare_lm_dm^2), 1, mean)

# Bias Figure 
PO_b  <- apply(compare_lm_Pro, 1, function(x) sqrt(mean(x^2)))/true_coef_base
GSO_b <- apply(compare_lm_IPW, 1, function(x) sqrt(mean(x^2)))/true_coef_base
ssl_b <- apply(compare_lm_PI, 1, function(x) sqrt(mean(x^2)))/true_coef_base
dsl_b <- apply(compare_lm_dm, 1, function(x) sqrt(mean(x^2)))/true_coef_base
# Coverage 
PO_ci  <- apply(compare_lm_Pro_ci, 1, mean)
GSO_ci  <- apply(compare_lm_IPW_ci, 1, mean)
ssl_ci  <- apply(compare_lm_PI_ci, 1, mean)
dsl_ci <- apply(compare_lm_dm_ci, 1, mean)
# RMSE
PO_RMSE   <- RMSE_Pro
GSO_RMSE  <- RMSE_IPW
ssl_RMSE  <- RMSE_PI
dsl_RMSE  <- RMSE_dm

balanced_result <- list("bias"  = list(PO_b, GSO_b, ssl_b, dsl_b),
                        "cover" = list(PO_ci, GSO_ci, ssl_ci, dsl_ci),
                        "RMSE" = list(PO_RMSE, GSO_RMSE, ssl_RMSE, dsl_RMSE))

# Balanced Zero-Shot 
use_index <- c(2:5)
x_use <- design_table$read[use_index]
use_x <- c(1:4)

if (!dir.exists("figure")) {
  dir.create("figure")
} 

pdf("figure/Figure2_CBP_balanced_zero_shot.pdf", height = 3, width = 9)
par(mfrow = c(1,3))
plot(use_x, PO_b[use_index], ylim = c(0, 6),
     ylab = "Standardized Bias", xlab = "Size of Gold-Standard Data", 
     xaxt='n', main = "Bias", pch = 19, col = "red", type = "b", lwd = 2)
Axis(side = 1, at = use_x, labels = x_use)
points(use_x, GSO_b[use_index], pch = 17, col = "green", type = "b", lwd = 2)
points(use_x, ssl_b[use_index], pch = 23, col = "orange", bg = "orange", type = "b", lwd = 2)
points(use_x, dsl_b[use_index], pch = 15, col = "blue", type = "b", lwd = 2)
abline(h = 0, lty = 2, lwd = 2)
legend("topleft", legend = c("SO", "GSO", "SSL", "DSL"),
       pch = c(19, 17, 23, 15), col = c("red", "green", "orange", "blue"), lwd = 2)

plot(use_x, PO_ci[use_index], ylim = c(0, 1),
     ylab = "Coverage Percentage", xlab = "Size of Gold-Standard Data", 
     xaxt='n', main = "Coverage", pch = 19, col = "red", type = "b", lwd = 2)
Axis(side = 1, at = use_x, labels = x_use)
points(use_x, dsl_ci[use_index], pch = 15, col = "blue", type = "b", lwd = 2)
points(use_x, GSO_ci[use_index], pch = 17, col = "green", type = "b", lwd = 2)
points(use_x, ssl_ci[use_index], pch = 23, col = "orange", bg = "orange", type = "b", lwd = 2)
points(use_x, dsl_ci[use_index], pch = 15, col = "blue", type = "b", lwd = 2)
abline(h = 0.95, lty = 2, lwd = 2)

plot(use_x, log(PO_RMSE[use_index]), ylim = c(-2.0, 0.1),
     ylab = "RMSE", xlab = "Size of Gold-Standard Data", 
     xaxt='n', main = "RMSE", pch = 19, col = "red", type = "b", lwd = 2, yaxt='n')
Axis(side = 1, at = use_x, labels = x_use)
points(use_x, log(GSO_RMSE[use_index]), pch = 17, col = "green", type = "b", lwd = 2)
points(use_x, log(ssl_RMSE[use_index]), pch = 23, col = "orange", bg = "orange", type = "b", lwd = 2)
points(use_x, log(dsl_RMSE[use_index]), pch = 15, col = "blue", type = "b", lwd = 2)
Axis(side = 2, at = c(-2, -1.5, -1.0, -0.5, 0), labels = round(exp(c(-2, -1.5, -1.0, -0.5, 0)), 2))
abline(h = 0.95, lty = 2, lwd = 2)
dev.off()

# Balanced Five-Shot 
use_index <- c(7:10)
x_use <- design_table$read[use_index]
use_x <- c(1:4)

pdf("figure/Figure2_CBP_balanced_five_shot.pdf", height = 3, width = 9)
par(mfrow = c(1,3))
plot(use_x, PO_b[use_index], ylim = c(0, 1),
     ylab = "Standardized Bias", xlab = "Size of Gold-Standard Data", 
     xaxt='n', main = "Bias", pch = 19, col = "red", type = "b", lwd = 2)
Axis(side = 1, at = use_x, labels = x_use)
points(use_x, GSO_b[use_index], pch = 17, col = "green", type = "b", lwd = 2)
points(use_x, ssl_b[use_index], pch = 23, col = "orange", bg = "orange", type = "b", lwd = 2)
points(use_x, dsl_b[use_index], pch = 15, col = "blue", type = "b", lwd = 2)
abline(h = 0, lty = 2, lwd = 2)
legend("topright", legend = c("SO", "GSO", "SSL", "DSL"),
       pch = c(19, 17, 23, 15), col = c("red", "green", "orange", "blue"), lwd = 2)

plot(use_x, PO_ci[use_index], ylim = c(0, 1),
     ylab = "Coverage Percentage", xlab = "Size of Gold-Standard Data", 
     xaxt='n', main = "Coverage", pch = 19, col = "red", type = "b", lwd = 2)
Axis(side = 1, at = use_x, labels = x_use)
points(use_x, dsl_ci[use_index], pch = 15, col = "blue", type = "b", lwd = 2)
points(use_x, GSO_ci[use_index], pch = 17, col = "green", type = "b", lwd = 2)
points(use_x, ssl_ci[use_index], pch = 23, col = "orange", bg = "orange", type = "b", lwd = 2)
points(use_x, dsl_ci[use_index], pch = 15, col = "blue", type = "b", lwd = 2)
abline(h = 0.95, lty = 2, lwd = 2)

plot(use_x, log(PO_RMSE[use_index]), ylim = c(-2.5, 0.3),
     ylab = "RMSE", xlab = "Size of Gold-Standard Data", 
     xaxt='n', main = "RMSE", pch = 19, col = "red", type = "b", lwd = 2, yaxt='n')
Axis(side = 1, at = use_x, labels = x_use)
points(use_x, log(GSO_RMSE[use_index]), pch = 17, col = "green", type = "b", lwd = 2)
points(use_x, log(ssl_RMSE[use_index]), pch = 23, col = "orange", bg = "orange", type = "b", lwd = 2)
points(use_x, log(dsl_RMSE[use_index]), pch = 15, col = "blue", type = "b", lwd = 2)
Axis(side = 2, at = c(-2.5, -2, -1.5, -1.0, -0.5, 0), 
     labels = round(exp(c(-2.5, -2, -1.5, -1.0, -0.5, 0)), 2))
abline(h = 0.95, lty = 2, lwd = 2)
dev.off()
