library(grf)

impute_logit <- function(outcome, proxy,
                         labeled, covariates, ps, data, 
                         formula_logit,
                         method = "grf", family = "gaussian",
                         boot = 10, seed = 1234){ 
  
  covariates_use <- unique(c(proxy, covariates))
  
  # Create a simple cluster
  data$cluster <- seq(1:nrow(data))
  uniq_cluster_labeled <- data$cluster[data[,labeled] == 1]
  uniq_cluster <- sort(unique(data$cluster))
  uniq_cluster_labeled <- sort(unique(uniq_cluster_labeled))
  
  uniq_cluster_no_labeled <- data$cluster[data[,labeled] == 0]
  uniq_cluster_no_labeled <- sort(unique(uniq_cluster_no_labeled))
  
  # Formula
  formula_lo_use <- as.formula(paste0("Y_int ~ ", as.character(formula_logit)[c(3)]))
  
  # prepare no-label data 
  no_label_which  <- unlist(sapply(uniq_cluster_no_labeled, function(x) which(data$cluster == x)))
  data_no_label  <- data[no_label_which, ]
  
  # Split them 
  ncol_X <- ncol(model.matrix(formula_logit, data = data))
  PI_point_l <- matrix(NA, ncol = ncol_X, nrow = boot)
  
  all_eq <- all(table(data$cluster) == table(data$cluster)[1])
  
  # ######################
  # Bootstrap
  # ######################
  for(x in 1:boot){
    
    seed.b <- 1000*x + seed
    
    set.seed(seed.b)
    ## Bootstrap for labeled
    boot_id <- sample(uniq_cluster_labeled, size = length(uniq_cluster_labeled), replace=TRUE)
    boot_which <- sapply(boot_id, function(x) which(data$cluster == x))
    
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
                             data = data_test, seed = seed)
    
    # 1. SSL Estimator
    PI <- c(out_train, out_no_label)
    data_lo <- rbind(data_train, data_test)
    data_lo$Y_int <- PI
    X_lo <- model.matrix(formula_lo_use, data = data_lo)
    lo_PI <- glogit(Y = PI, X = X_lo)
    
    PI_point_l[x, 1:ncol_X] <- lo_PI$coef
  }
  
  # 1. SSL Estimator
  PI_point <- apply(PI_point_l, 2, mean)
  PI_se    <- apply(PI_point_l, 2, sd)
  
  out <- list("PI_point" = PI_point, 
              "PI_se" = PI_se)
  
  return(out)
}
