library(grf)

impute_measure <- function(outcome, proxy, labeled, covariates, ps, data, 
                           method = "grf", family = "gaussian",
                           boot = 10, seed = 1234,
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
  PI_point_l <- c()
  
  all_eq <- all(table(data$cluster) == table(data$cluster)[1])
  
  # ######################
  # Bootstrap
  # ######################
  for(x in 1:boot){
    
    seed.b <- 1000*x + seed
    
    set.seed(seed.b)
    boot_id <- sample(uniq_cluster_labeled, size = length(uniq_cluster_labeled), replace=TRUE)
    # create bootstap sample with sapply
    boot_which <- sapply(boot_id, function(x) which(data$cluster == x))
    if(all_eq == TRUE){new_boot_id <- rep(seq(1:length(boot_id)), each = table(data$cluster)[1])
    }else{new_boot_id <- rep(seq(1:length(boot_id)), times = unlist(lapply(boot_which, length)))}
    
    data_train <- data[unlist(boot_which),]
    
    ## Bootstrap for no_label
    boot_id_no <- sample(uniq_cluster_no_labeled, size = length(uniq_cluster_no_labeled), replace=TRUE)
    boot_which_no <- sapply(boot_id_no, function(x) which(data$cluster == x))
    
    data_test <- data[unlist(boot_which_no),]
    
    if(any(is.na(data_train[, outcome]))){
      stop("NA in outcomes of labeled data")
    }
    
    # Fit the model E(Y | X, R = 1) in the training sample 
    fit_train <- fit_model(outcome = outcome, labeled = labeled, 
                           covariates = covariates_use, data = data_train, 
                           seed = seed, method = method, family = family)
    
    # Predict E(Y | X, R = 1) in the training data 
    out_train <- fit_test(fit_out = fit_train, 
                          outcome = outcome, labeled = labeled, covariates = covariates_use, 
                          method = method, family = family,
                          data = data_train, seed = seed)
    
    # Predict E(Y | X, R = 1) in the no label data 
    out_no_label <- fit_test(fit_out = fit_train, 
                             outcome = outcome, labeled = labeled, covariates = covariates_use, 
                             method = method, family = family,
                             data = data_no_label, seed = seed)
    
    # 1. SSL Estimator
    PI <- c(out_train, out_no_label)
    PI_point_l[x] <- mean(PI)
  }
  
  # 1. SSL Estimator
  PI_point <- mean(PI_point_l)
  PI_se  <- sd(PI_point_l)
  
  out <- list("PI_point" = PI_point, 
              "PI_se" = PI_se)
  
  return(out)
}


