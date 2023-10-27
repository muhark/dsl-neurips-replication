# Set working directory to current source file location first.

#setwd(dirname(rstudioapi::getActiveDocumentContext()$path)) # if you are using RStudio
setwd("/<PATH>/<TO>/<SOURCE>/<FILE>/")

#library(stringr)
# function
get_compare <- function(final_out, type_str){
  # # fix index
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
  
  # Table Format
  compare <- matrix(NA, nrow = nrow(design_table), ncol = 20)
  for(i in 1:nrow(design_table)){
    
    true_i <- mean(true[ind == i])
    
    base <- 0
    
    # IPW
    compare[i, base+1] <- round(mean(res_IPW[ind == i, 1], na.rm = TRUE), 3)
    compare[i, base+2] <- round(sd(res_IPW[ind == i, 1], na.rm = TRUE), 3)
    compare[i, base+3] <- round(mean(res_IPW[ind == i, 2], na.rm = TRUE), 3)
    compare[i, base+4] <- mean(as.numeric(res_IPW[ind == i, 1] - 1.96*res_IPW[ind == i, 2] < true_i)*
                                 as.numeric(true_i < res_IPW[ind == i,1] + 1.96*res_IPW[ind == i,2]), na.rm = TRUE)
    
    # PI 
    compare[i, base+5] <- round(mean(res_PI[ind == i, 1]), 3)
    compare[i, base+6] <- round(sd(res_PI[ind == i, 1]), 3)
    compare[i, base+7] <- round(mean(res_PI[ind == i, 2]), 3)
    compare[i, base+8] <- mean(as.numeric(res_PI[ind == i, 1] - 1.96*res_PI[ind == i, 2] < true_i)*
                                 as.numeric(true_i < res_PI[ind == i,1] + 1.96*res_PI[ind == i,2]))
    
    #DM
    compare[i, base+9] <- round(mean(res_dm[ind == i, 1]), 3)
    compare[i, base+10] <- round(sd(res_dm[ind == i, 1]), 3)
    compare[i, base+11] <- round(mean(res_dm[ind == i, 2]), 3)
    compare[i, base+12] <- mean(as.numeric(res_dm[ind == i, 1] - 1.96*res_dm[ind == i, 2] < true_i)*
                                  as.numeric(true_i < res_dm[ind == i,1] + 1.96*res_dm[ind == i,2]))
    
    # DM_Direct
    compare[i, base+13] <- round(mean(res_dm_dir[ind == i, 1]), 3)
    compare[i, base+14] <- round(sd(res_dm_dir[ind == i, 1]), 3)
    compare[i, base+15] <- round(mean(res_dm_dir[ind == i, 2]), 3)
    compare[i, base+16] <- mean(as.numeric(res_dm_dir[ind == i, 1] - 1.96*res_dm_dir[ind == i, 2] < true_i)*
                                  as.numeric(true_i < res_dm_dir[ind == i,1] + 1.96*res_dm_dir[ind == i,2]))
    
    # Pro
    compare[i, base+17] <- round(mean(res_Pro[ind == i, 1]), 3)
    compare[i, base+18] <- round(sd(res_Pro[ind == i, 1]), 3)
    compare[i, base+19] <- round(mean(res_Pro[ind == i, 2]), 3)
    compare[i, base+20] <- mean(as.numeric(res_Pro[ind == i, 1] - 1.96*res_Pro[ind == i, 2] < true_i)*
                                  as.numeric(true_i < res_Pro[ind == i,1] + 1.96*res_Pro[ind == i,2]))
    
  }
  
  colnames(compare) <- c(
    "IPW", "IPW_true_sd", "IPW_se", "IPW_ci",
    "PI", "PI_true_sd", "PI_se", "PI_ci",
    "dm", "dm_true_sd", "dm_se", "dm_ci",
    "dm_dir", "dm_dir_true_sd", "dm_dir_se", "dm_dir_ci",
    "Pro", "Pro_true_sd", "Pro_se", "Pro_ci")
  compare_tab <- cbind(design_table[, c("ss", "read", "prob_prox"), drop = FALSE], compare)
  
  true_i <- tapply(true, INDEX = ind, FUN = mean)
  result <- list(compare = compare, true_i = true_i, true = true, ind = ind, res_Pro = res_Pro, res_IPW = res_IPW, res_PI = res_PI, res_dm = res_dm)
  return(result)
}


set.seed(666)


# modify file name list here
{ 
stance_file_list <- c("230512_multi_semeval_stance_pos-a.csv_HPCversion_sim500_boot100.rds", "230512_multi_semeval_stance_pos-b.csv_HPCversion_sim500_boot100.rds", "230512_multi_semeval_stance_pos-c.csv_HPCversion_sim500_boot100.rds")
hate_file_list <- c("230511_multi_hate_pos-a.csv_HPCversion_sim500_boot100.rds","230511_multi_hate_pos-b.csv_HPCversion_sim500_boot100.rds","230511_multi_hate_pos-c.csv_HPCversion_sim500_boot100.rds","230511_multi_hate_pos-d.csv_HPCversion_sim500_boot100.rds","230511_multi_hate_pos-e.csv_HPCversion_sim500_boot100.rds","230511_multi_hate_pos-f.csv_HPCversion_sim500_boot100.rds")
ibc_file_list <- c("230511_multi_ibc_pos-a.csv_HPCversion_sim500_boot100.rds","230511_multi_ibc_pos-b.csv_HPCversion_sim500_boot100.rds","230511_multi_ibc_pos-c.csv_HPCversion_sim500_boot100.rds")
discourse_file_list <- c("230512_multi_discourse_pos-a.csv_HPCversion_sim500_boot100.rds",
                         "230512_multi_discourse_pos-b.csv_HPCversion_sim500_boot100.rds",
                         "230512_multi_discourse_pos-c.csv_HPCversion_sim500_boot100.rds",
                         "230512_multi_discourse_pos-d.csv_HPCversion_sim500_boot100.rds",
                         "230512_multi_discourse_pos-e.csv_HPCversion_sim500_boot100.rds",
                         "230512_multi_discourse_pos-f.csv_HPCversion_sim500_boot100.rds",
                         "230512_multi_discourse_pos-g.csv_HPCversion_sim500_boot100.rds")
emotion_file_list <- c("230512_multi_emotion_pos-a.csv_HPCversion_sim500_boot100.rds",
               "230512_multi_emotion_pos-b.csv_HPCversion_sim500_boot100.rds",
               "230512_multi_emotion_pos-c.csv_HPCversion_sim500_boot100.rds",
               "230512_multi_emotion_pos-d.csv_HPCversion_sim500_boot100.rds",
               "230512_multi_emotion_pos-e.csv_HPCversion_sim500_boot100.rds",
               "230512_multi_emotion_pos-f.csv_HPCversion_sim500_boot100.rds")

flute_file_list <- c("230512_multi_flute-classification_pos-a.csv_HPCversion_sim500_boot100.rds",
               "230512_multi_flute-classification_pos-b.csv_HPCversion_sim500_boot100.rds",
               "230512_multi_flute-classification_pos-c.csv_HPCversion_sim500_boot100.rds",
               "230512_multi_flute-classification_pos-d.csv_HPCversion_sim500_boot100.rds")

ideology_file_list <- c("230512_multi_media_ideology_pos-a.csv_HPCversion_sim500_boot100.rds",
               "230512_multi_media_ideology_pos-b.csv_HPCversion_sim500_boot100.rds",
               "230512_multi_media_ideology_pos-c.csv_HPCversion_sim500_boot100.rds")

politeness_file_list <- c("230512_multi_politeness_pos-a.csv_HPCversion_sim500_boot100.rds",
               "230512_multi_politeness_pos-b.csv_HPCversion_sim500_boot100.rds",
               "230512_multi_politeness_pos-c.csv_HPCversion_sim500_boot100.rds")

raop_file_list <- c("230512_multi_raop_pos-a.csv_HPCversion_sim500_boot100.rds",
               "230512_multi_raop_pos-b.csv_HPCversion_sim500_boot100.rds",
               "230512_multi_raop_pos-c.csv_HPCversion_sim500_boot100.rds",
               "230512_multi_raop_pos-d.csv_HPCversion_sim500_boot100.rds",
               "230512_multi_raop_pos-e.csv_HPCversion_sim500_boot100.rds",
               "230512_multi_raop_pos-f.csv_HPCversion_sim500_boot100.rds",
               "230512_multi_raop_pos-g.csv_HPCversion_sim500_boot100.rds")

semeval_file_list <- c("230512_multi_semeval_stance_pos-a.csv_HPCversion_sim500_boot100.rds",
               "230512_multi_semeval_stance_pos-b.csv_HPCversion_sim500_boot100.rds",
               "230512_multi_semeval_stance_pos-c.csv_HPCversion_sim500_boot100.rds")

talklife_file_list <- c("230512_multi_talklife_pos-a.csv_HPCversion_sim500_boot100.rds",
               "230512_multi_talklife_pos-b.csv_HPCversion_sim500_boot100.rds",
               "230512_multi_talklife_pos-c.csv_HPCversion_sim500_boot100.rds")

dialect_file_list <- c("230511_multi_indian_english_dialect_pos-a.csv_HPCversion_sim500_boot100.rds",
               "230511_multi_indian_english_dialect_pos-b.csv_HPCversion_sim500_boot100.rds",
               "230511_multi_indian_english_dialect_pos-c.csv_HPCversion_sim500_boot100.rds",
               "230511_multi_indian_english_dialect_pos-d.csv_HPCversion_sim500_boot100.rds",
               "230511_multi_indian_english_dialect_pos-e.csv_HPCversion_sim500_boot100.rds",
               "230511_multi_indian_english_dialect_pos-f.csv_HPCversion_sim500_boot100.rds",
               "230511_multi_indian_english_dialect_pos-g.csv_HPCversion_sim500_boot100.rds",
               "230511_multi_indian_english_dialect_pos-h.csv_HPCversion_sim500_boot100.rds",
               "230511_multi_indian_english_dialect_pos-i.csv_HPCversion_sim500_boot100.rds",
               "230511_multi_indian_english_dialect_pos-j.csv_HPCversion_sim500_boot100.rds",
               "230511_multi_indian_english_dialect_pos-k.csv_HPCversion_sim500_boot100.rds",
               "230511_multi_indian_english_dialect_pos-l.csv_HPCversion_sim500_boot100.rds",
               "230511_multi_indian_english_dialect_pos-m.csv_HPCversion_sim500_boot100.rds",
               "230511_multi_indian_english_dialect_pos-n.csv_HPCversion_sim500_boot100.rds",
               "230511_multi_indian_english_dialect_pos-o.csv_HPCversion_sim500_boot100.rds",
               "230512_multi_indian_english_dialect_pos-p.csv_HPCversion_sim500_boot100.rds",
               "230512_multi_indian_english_dialect_pos-q.csv_HPCversion_sim500_boot100.rds",
               "230512_multi_indian_english_dialect_pos-r.csv_HPCversion_sim500_boot100.rds",
               "230512_multi_indian_english_dialect_pos-s.csv_HPCversion_sim500_boot100.rds",
               "230512_multi_indian_english_dialect_pos-t.csv_HPCversion_sim500_boot100.rds",
               "230512_multi_indian_english_dialect_pos-u.csv_HPCversion_sim500_boot100.rds",
               "230512_multi_indian_english_dialect_pos-v.csv_HPCversion_sim500_boot100.rds",
               "230512_multi_indian_english_dialect_pos-w.csv_HPCversion_sim500_boot100.rds")

conv_go_awry_file_list <- c("230512_binary_conv_go_awry_pos-yes.csv_HPCversion_sim500_boot100.rds")

humor_file_list <- c("230512_binary_humor_pos-true.csv_HPCversion_sim500_boot100.rds")

persuasion_file_list <- c("230512_binary_persuasion_pos-true.csv_HPCversion_sim500_boot100.rds" )

power_file_list <- c("230512_binary_power_pos-yes.csv_HPCversion_sim500_boot100.rds")

mrf_file_list <- c("230512_binary_mrf-classification_pos-a.csv_HPCversion_sim500_boot100.rds")

tempowic_file_list <- c("230512_binary_tempowic_pos-a.csv_HPCversion_sim500_boot100.rds")

}


generate_measure_se_table <- function(data_name) {
  file_list <- c()
  if (data_name == "stance"){
    file_list <- stance_file_list
  }else if (data_name == "hate"){
    file_list <- hate_file_list
  }else if (data_name == "ibc"){
    file_list <- ibc_file_list
  }else if (data_name == "discourse"){
    file_list <- discourse_file_list
  }else if (data_name == "emotion"){
    file_list <- emotion_file_list
  }else if (data_name == "flute"){
    file_list <- flute_file_list
  }else if (data_name == "ideology"){
    file_list <- ideology_file_list
  }else if (data_name == "politeness"){
    file_list <- politeness_file_list
  }else if (data_name == "raop"){
    file_list <- raop_file_list
  }else if (data_name == "semeval"){
    file_list <- semeval_file_list
  }else if (data_name == "talklife"){
    file_list <- talklife_file_list
  }else if (data_name == "dialect"){
    file_list <- dialect_file_list
  }else if (data_name == "conv_go_awry"){
    file_list <- conv_go_awry_file_list
  }else if (data_name == "humor"){
    file_list <- humor_file_list
  }else if (data_name == "persuasion"){
    file_list <- persuasion_file_list
  }else if (data_name == "power"){
    file_list <- power_file_list
  }else if (data_name == "mrf"){
    file_list <- mrf_file_list
  }else if (data_name == "tempowic"){
    file_list <- tempowic_file_list
  }
  
  number_of_type <- length(file_list)
  type_str_list <- c("pos_a", "pos_b", "pos_c", paste0("pos_", letters[4:23]))[1:number_of_type]
  
  
  design_table <- ""
  
  compare_prefix <- "compare_"
  #true_i_prefix <- "true_i_"
  true_prefix <- "true_"
  ind_prefix <- "ind_"
  res_Pro_prefix <- "res_Pro_"
  res_IPW_prefix <- "res_IPW_"
  res_PI_prefix <- "res_PI_"
  res_dm_prefix <- "res_dm_"
  for (i in 1:number_of_type) {
    file_number <- i  # Change this to match your file numbering convention
    #file_name <- paste0("file_", file_number)
    
    raw_filename <- str_extract(file_list[i], "(?<=_).*?\\.csv")
    raw_data <- read.csv(paste0(raw_file_location, raw_filename))
    
    graph_head_str <-  sub(".*?_(.*)-.*", "\\1",file_list[i])
    
    rds_file_path <- paste0(rds_file_location, file_list[i])
    final_out <- readRDS(file = rds_file_path)
    design_table <- final_out[[2]] #assign multiple times, but doesn't matter for now.
    
    # Call the get_compare function and store the result
    result <- get_compare(final_out, type_str_list[i])
    
    # Construct the compare_i variable name
    compare_variable <- paste0(compare_prefix, i)
    assign(compare_variable, result$compare)
    
    # # Construct the true_i variable name
    # true_i_variable <- paste0(true_i_prefix, i)
    # assign(true_i_variable, mean(raw_data$label)) #assign(true_i_variable, result$true_i)
    
    # Construct the true variable name
    true_variable <- paste0(true_prefix, i)
    assign(true_variable, mean(raw_data$label)) #assign(true_variable, result$true)
    
    # Construct the ind variable name
    ind_variable <- paste0(ind_prefix, i)
    assign(ind_variable, result$ind)
    
    # Construct the res_Pro variable name
    res_Pro_variable <- paste0(res_Pro_prefix, i)
    assign(res_Pro_variable, result$res_Pro)
    
    # Construct the res_IPW variable name
    res_IPW_variable <- paste0(res_IPW_prefix, i)
    assign(res_IPW_variable, result$res_IPW)
    
    # Construct the res_PI variable name
    res_PI_variable <- paste0(res_PI_prefix, i)
    assign(res_PI_variable, result$res_PI)
    
    # Construct the res_dm variable name
    res_dm_variable <- paste0(res_dm_prefix, i)
    assign(res_dm_variable, result$res_dm)
  }
  
  ############################################
  ## RMSE Winners (Bootstrap)
  # RMSE Bootstrap 
  RMSE_winner <- matrix(NA, nrow = 4, ncol = nrow(design_table))
  RMSE_boot <- list()
  bias_boot <- list()
  coverage_boot <- list()
  for(d in 1:nrow(design_table)){
    
    for (i in 1:number_of_type) {
      true_val_var <- paste0("true_val_i_", i)
      sim_size_var <- paste0("sim_size_", i)
      
      #assign(true_val_var, mean(get(paste0("true_", i))[get(paste0("ind_", i)) == d]))
      assign(true_val_var, get(paste0("true_", i))) # directly get the true value that we assign from the raw data
      assign(sim_size_var, sum(get(paste0("ind_", i)) == d))
    }
    
    RMSE_boot[[d]] <- matrix(NA, nrow = 1000, ncol = 4)
    bias_boot[[d]] <- matrix(NA, nrow = 1000, ncol = 4)
    coverage_boot[[d]] <- matrix(NA, nrow = 1000, ncol = 4)
    
    RMSE_boot_Pro <- RMSE_boot_IPW <- RMSE_boot_PI <- RMSE_boot_dm <- c()
    bias_boot_Pro <- bias_boot_IPW <- bias_boot_PI <- bias_boot_dm <- c()
    coverage_boot_Pro <- coverage_boot_IPW <- coverage_boot_PI <- coverage_boot_dm <- c()
    
    RMSE_winner_base <- matrix(0, nrow = 4, ncol = 1000)
    for(bo in 1:1000){
      set.seed(666 + bo)
      
      RMSE_boot_Pro_sum <- RMSE_boot_IPW_sum <- RMSE_boot_PI_sum <- RMSE_boot_dm_sum  <- 0
      bias_boot_Pro_sum <- bias_boot_IPW_sum <- bias_boot_PI_sum <- bias_boot_dm_sum  <- 0
      coverage_boot_Pro_sum <- coverage_boot_IPW_sum <- coverage_boot_PI_sum <- coverage_boot_dm_sum  <- 0
      
      for (i in 1:number_of_type) {
        boot_id_var <- paste0("boot_id_", i)
        
        RMSE_boot_Pro_var <- paste0("RMSE_boot_Pro_", i)
        RMSE_boot_IPW_var <- paste0("RMSE_boot_IPW_", i)
        RMSE_boot_PI_var <- paste0("RMSE_boot_PI_", i)
        RMSE_boot_dm_var <- paste0("RMSE_boot_dm_", i)
        
        bias_boot_Pro_var <- paste0("bias_boot_Pro_", i)
        bias_boot_IPW_var <- paste0("bias_boot_IPW_", i)
        bias_boot_PI_var <- paste0("bias_boot_PI_", i)
        bias_boot_dm_var <- paste0("bias_boot_dm_", i)
        
        coverage_boot_Pro_var <- paste0("coverage_boot_Pro_", i)
        coverage_boot_IPW_var <- paste0("coverage_boot_IPW_", i)
        coverage_boot_PI_var <- paste0("coverage_boot_PI_", i)
        coverage_boot_dm_var <- paste0("coverage_boot_dm_", i)
        
        
        sim_size_var <- get(paste0("sim_size_", i))
        assign(boot_id_var, sample(x = seq(1:sim_size_var), size = sim_size_var, replace = TRUE))
        
        true_val_var <- get(paste0("true_val_i_", i))
        res_Pro_var <- get(paste0("res_Pro_", i))
        res_IPW_var <- get(paste0("res_IPW_", i))
        res_PI_var <- get(paste0("res_PI_", i))
        res_dm_var <- get(paste0("res_dm_", i))
        
        ind_var <- get(paste0("ind_", i))
        
        assign(RMSE_boot_Pro_var, sqrt(mean((res_Pro_var[ind_var == d, 1][get(boot_id_var)] - true_val_var)^2)))
        assign(RMSE_boot_IPW_var, sqrt(mean((res_IPW_var[ind_var == d, 1][get(boot_id_var)] - true_val_var)^2)))
        assign(RMSE_boot_PI_var, sqrt(mean((res_PI_var[ind_var == d, 1][get(boot_id_var)] - true_val_var)^2)))
        assign(RMSE_boot_dm_var, sqrt(mean((res_dm_var[ind_var == d, 1][get(boot_id_var)] - true_val_var)^2)))
        
        assign(bias_boot_Pro_var, abs(mean(res_Pro_var[ind_var == d, 1][get(boot_id_var)], na.rm = TRUE) - true_val_var))
        assign(bias_boot_IPW_var, abs(mean(res_IPW_var[ind_var == d, 1][get(boot_id_var)], na.rm = TRUE) - true_val_var))
        assign(bias_boot_PI_var, abs(mean(res_PI_var[ind_var == d, 1][get(boot_id_var)], na.rm = TRUE) - true_val_var))
        assign(bias_boot_dm_var, abs(mean(res_dm_var[ind_var == d, 1][get(boot_id_var)], na.rm = TRUE) - true_val_var))
        
        assign(coverage_boot_Pro_var, mean(as.numeric(res_Pro_var[ind_var == d, 1][get(boot_id_var)] - 1.96*res_Pro_var[ind_var == d, 2][get(boot_id_var)] <= true_val_var)*
                                             as.numeric(true_val_var <= res_Pro_var[ind_var == d, 1][get(boot_id_var)] + 1.96*res_Pro_var[ind_var == d, 2][get(boot_id_var)]), na.rm = TRUE))
        assign(coverage_boot_IPW_var, mean(as.numeric(res_IPW_var[ind_var == d, 1][get(boot_id_var)] - 1.96*res_IPW_var[ind_var == d, 2][get(boot_id_var)] <= true_val_var)*
                                             as.numeric(true_val_var <= res_IPW_var[ind_var == d, 1][get(boot_id_var)] + 1.96*res_IPW_var[ind_var == d, 2][get(boot_id_var)]), na.rm = TRUE))
        assign(coverage_boot_PI_var, mean(as.numeric(res_PI_var[ind_var == d, 1][get(boot_id_var)] - 1.96*res_PI_var[ind_var == d, 2][get(boot_id_var)] <= true_val_var)*
                                            as.numeric(true_val_var <= res_PI_var[ind_var == d, 1][get(boot_id_var)] + 1.96*res_PI_var[ind_var == d, 2][get(boot_id_var)]), na.rm = TRUE))
        assign(coverage_boot_dm_var, mean(as.numeric(res_dm_var[ind_var == d, 1][get(boot_id_var)] - 1.96*res_dm_var[ind_var == d, 2][get(boot_id_var)] <= true_val_var)*
                                            as.numeric(true_val_var <= res_dm_var[ind_var == d, 1][get(boot_id_var)] + 1.96*res_dm_var[ind_var == d, 2][get(boot_id_var)]), na.rm = TRUE))
        
        RMSE_boot_Pro_sum <- RMSE_boot_Pro_sum + get(RMSE_boot_Pro_var)
        RMSE_boot_IPW_sum <- RMSE_boot_IPW_sum + get(RMSE_boot_IPW_var)
        RMSE_boot_PI_sum  <- RMSE_boot_PI_sum + get(RMSE_boot_PI_var)
        RMSE_boot_dm_sum  <- RMSE_boot_dm_sum + get(RMSE_boot_dm_var)
        
        bias_boot_Pro_sum <- bias_boot_Pro_sum + get(bias_boot_Pro_var)
        bias_boot_IPW_sum <- bias_boot_IPW_sum + get(bias_boot_IPW_var)
        bias_boot_PI_sum  <- bias_boot_PI_sum + get(bias_boot_PI_var)
        bias_boot_dm_sum  <- bias_boot_dm_sum + get(bias_boot_dm_var)
        
        coverage_boot_Pro_sum <- coverage_boot_Pro_sum + get(coverage_boot_Pro_var)
        coverage_boot_IPW_sum <- coverage_boot_IPW_sum + get(coverage_boot_IPW_var)
        coverage_boot_PI_sum  <- coverage_boot_PI_sum + get(coverage_boot_PI_var)
        coverage_boot_dm_sum  <- coverage_boot_dm_sum + get(coverage_boot_dm_var)
      }
      
      RMSE_boot_Pro[bo] <- RMSE_boot_Pro_sum/number_of_type
      RMSE_boot_IPW[bo] <- RMSE_boot_IPW_sum/number_of_type
      RMSE_boot_PI[bo] <-  RMSE_boot_PI_sum/number_of_type
      RMSE_boot_dm[bo] <-  RMSE_boot_dm_sum/number_of_type
      
      who_won <- which.min(c(RMSE_boot_Pro[bo], RMSE_boot_IPW[bo], RMSE_boot_PI[bo], RMSE_boot_dm[bo]))
      RMSE_winner_base[who_won, bo] <- 1
      
      bias_boot_Pro[bo] <- bias_boot_Pro_sum/number_of_type
      bias_boot_IPW[bo] <- bias_boot_IPW_sum/number_of_type
      bias_boot_PI[bo]  <- bias_boot_PI_sum/number_of_type
      bias_boot_dm[bo]  <- bias_boot_dm_sum/number_of_type
      
      coverage_boot_Pro[bo] <- coverage_boot_Pro_sum/number_of_type
      coverage_boot_IPW[bo] <- coverage_boot_IPW_sum/number_of_type
      coverage_boot_PI[bo]  <- coverage_boot_PI_sum/number_of_type
      coverage_boot_dm[bo]  <- coverage_boot_dm_sum/number_of_type
      
      RMSE_boot[[d]][bo, 1:4] <- 
        c(RMSE_boot_Pro[bo], RMSE_boot_IPW[bo], RMSE_boot_PI[bo], RMSE_boot_dm[bo])
      bias_boot[[d]][bo, 1:4] <- 
        c(bias_boot_Pro[bo], bias_boot_IPW[bo], bias_boot_PI[bo], bias_boot_dm[bo])
      coverage_boot[[d]][bo, 1:4] <- 
        c(coverage_boot_Pro[bo], coverage_boot_IPW[bo], coverage_boot_PI[bo], coverage_boot_dm[bo])
    }
    RMSE_winner[1:4, i] <- apply(RMSE_winner_base, 1, mean)
  }
  
  ############################################
  
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
  
  if (!dir.exists("table/measure")) {
    dir.create("table/measure")
  } 
    
  # store the standard error table
  se_result <- result_table[result_table$read %in% c(25, 50, 100, 200) & result_table$prob_prox %in% c("all", "flan-ul2"), ]
  write.csv(se_result, paste0("table/measure/",data_name,"_measure_table.csv")) #graph_head_str
}


# set up directory
rds_file_location <- "../03_postprocessing/measure_result_data/"
raw_file_location <- "../01_data_and_preprocessing/measurement/binarized_datasets/"

# measure dataset list
dataset_list <- c("tempowic","mrf","power","persuasion","humor","conv_go_awry","stance","hate","ibc","discourse","emotion","flute","ideology","politeness","raop","semeval","talklife","dialect")

# generate table csv file for each dataset
for (dataset in dataset_list) {
  print(paste0("start: ", dataset))
  generate_measure_se_table(dataset)
  print(paste0("finish: ", dataset))
}

# merge csvs
# after finish generating the csv files, then combine them into one csv.
file_list <- list.files(path = "table/measure", full.names = TRUE)

dfs <- data.frame()
for (file in file_list) {
  if (endsWith(file, ".csv")) {
    df <- read.csv(file)
    df$file_name <- file
    dfs <- bind_rows(dfs, df)
  }
}

if ("simulation_count" %in% colnames(dfs)) {
  dfs <- dfs[, !(colnames(dfs) == "simulation_count")]
}

write.csv(dfs, paste0("table/","Figure2_and_supplement_measure_table.csv"))










