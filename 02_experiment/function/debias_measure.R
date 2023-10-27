library(grf)

debias_measure <- function(outcome, proxy, labeled, covariates, ps, data, 
                           method = "grf", family = "gaussian",
                           cross_fit = 5, sample_split = 10, seed = 1234,
                           misspecified = FALSE){ 
  
  covariates_use <- unique(c(proxy, covariates))
  
  # Create a simple cluster for now
  data$cluster <- seq(1:nrow(data))
  uniq_cluster_labeled <- data$cluster[data[,labeled] == 1]
  uniq_cluster <- sort(unique(data$cluster))
  uniq_cluster_labeled <- sort(unique(uniq_cluster_labeled))
  
  uniq_cluster_no_labeled <- data$cluster[data[,labeled] == 0]
  uniq_cluster_no_labeled <- sort(unique(uniq_cluster_no_labeled))
  
  # prepare no-label data 
  no_label_which  <- unlist(sapply(uniq_cluster_no_labeled, function(x) which(data$cluster == x)))
  data_no_label  <- data[no_label_which, ]
  
  # Split them 
  PI_point_l <- PI_se_l <- dm_point_l <- dm_se_l <- c()
  set.seed(seed)
  
  # ######################
  # Sample Splitting for Cross-Fitting Iterations
  # ######################
  for(ss_use in 1:sample_split){
    id_base <- sample(1:cross_fit, size = length(uniq_cluster_labeled), replace = TRUE)
    
    dm_label <- PI_label <- c()
    
    PI_no_label_sum <- rep(0, nrow(data_no_label))
    dm_no_label_sum <- rep(0, nrow(data_no_label))
    
    # ############
    # Cross-Fit
    # ############
    for(i_use in 1:cross_fit){
      train_id <- uniq_cluster_labeled[id_base != i_use]
      test_id  <- setdiff(uniq_cluster_labeled, train_id)
      
      train_which <- unlist(sapply(train_id, function(x) which(data$cluster == x)))
      test_which  <- unlist(sapply(test_id, function(x) which(data$cluster == x)))
      
      data_train     <- data[train_which, ]
      data_test      <- data[test_which, ]
      
      # Fit the model E(Y | X, R = 1) in the training sample 
      fit_train <- fit_model(outcome = outcome, labeled = labeled, 
                             covariates = covariates_use, data = data_train, 
                             seed = seed, method = method, family = family)
      
      # Predict E(Y | X, R = 1) in the test data 
      out_test <- fit_test(fit_out = fit_train, 
                           outcome = outcome, labeled = labeled, covariates = covariates_use, 
                           method = method, family = family,
                           data = data_test, seed = seed)
      
      # Predict E(Y | X, R = 1) in the no label data 
      out_no_label <- fit_test(fit_out = fit_train, 
                               outcome = outcome, labeled = labeled, covariates = covariates_use, 
                               method = method, family = family,
                               data = data_no_label, seed = seed)
      
      if(misspecified == TRUE){
        out_test <- out_test + rnorm(n = length(out_test), mean = 0.3, sd = 0.05)
        out_no_label <- out_no_label + rnorm(n = length(out_no_label), mean = 0.3, sd = 0.05)
      }
      
      # #################
      # Store results
      # #################
      # 1. SSL Estimator (legacy)
      PI_label <- c(out_test, PI_label)
      PI_no_label_sum <- out_no_label + PI_no_label_sum
      
      # 2. Design-based Semi-Supervised Learning (DSL) Estimator
      dm_label_base <- out_test + (data_test[, outcome] - out_test)/data_test[, ps]
      
      dm_label <- c(dm_label_base, dm_label)
      dm_no_label_sum <- out_no_label + dm_no_label_sum
    }
    
    # 1. SSL Estimator (legacy)
    PI <- c(PI_label, PI_no_label_sum/cross_fit)
    PI_point_l[ss_use] <- mean(PI)
    PI_se_l[ss_use]    <- sd(PI)/sqrt(nrow(data))
    
    # 2. Design-based Semi-Supervised Learning (DSL) Estimator
    dm <- c(dm_label, dm_no_label_sum/cross_fit)
    dm_point_l[ss_use] <- mean(dm)
    dm_se_l[ss_use]    <- sd(dm)/sqrt(nrow(data))
  }
  
  # 1. SSL Estimator (legacy)
  PI_point <- median(PI_point_l)
  PI_se  <- sqrt(median(PI_se_l^2 + (PI_point_l - PI_point)^2))
  
  # 2. Design-based Semi-Supervised Learning (DSL) Estimator
  dm_point <- median(dm_point_l)
  dm_se  <- sqrt(median(dm_se_l^2 + (dm_point_l - dm_point)^2))
  
  out <- list("PI_point" = PI_point, 
              "PI_se" = PI_se, 
              "dm_point" = dm_point,
              "dm_se" = dm_se)
  
  return(out)
}

debias_measure_direct <- function(outcome, proxy = NULL,
                                  covariates,
                                  labeled,
                                  ps, data){

  # Create Data
  data_label    <- data[data[,labeled] == 1, , drop = FALSE]
  data_no_label <- data[data[,labeled] == 0, , drop = FALSE]

  if(is.null(proxy)){
    stop("This method is useful only when you have at least one proxy.")
  }else if(length(proxy) > 0){
    data_label$proxy_avg <- apply(data_label[, proxy, drop = FALSE], 1, mean)
    data_no_label$proxy_avg <- apply(data_no_label[, proxy, drop = FALSE], 1, mean)
  }

  # Pseudo-outcome
  data_no_label$p_Y <- data_no_label$proxy_avg
  data_label$p_Y <- (data_label[, outcome] - data_label$proxy_avg)/data_label[, ps] + data_label$proxy_avg
  data_use <- rbind(data_no_label, data_label)

  dm_point <- mean(data_use$p_Y)
  dm_se    <- sd(data_use$p_Y)/sqrt(nrow(data_use))

  out <- list("dm_point" = dm_point, "dm_se" = dm_se)

  return(out)
}
