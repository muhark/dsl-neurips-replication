library(grf)

# function for Design-based Semi-Supervised Learning (DSL) Estimator
debias_logit <- function(outcome, proxy,
                         labeled, covariates, ps = NULL, data, 
                         formula_logit,
                         method = "grf", family = "gaussian",
                         cross_fit = 5, sample_split = 10, seed = 1234){ 
  
  covariates_use <- unique(c(proxy, covariates))
  
  # Create a simple cluster for now
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
  PI_point_l <- PI_se_l <- dm_point_l <- dm_se_l <- matrix(NA, 
                                                           ncol = ncol_X,
                                                           nrow = sample_split)
  set.seed(seed)
  
  # ######################
  # Sample Splitting for Cross-Fitting Iterations
  # ######################
  for(ss_use in 1:sample_split){
    id_base <- sample(1:cross_fit, size = length(uniq_cluster_labeled), replace = TRUE)
    
    dm_label <- PI_label <- c()
    id_final <- c()
    
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
      
      if(any(is.na(data_train[, outcome]))){
        stop("NA in outcomes of labeled data")
      }
      if(any(is.na(data_test[, outcome]))){
        stop("NA in outcomes of labeled data")
      }
      
      # Fit the model E(Y | X, R = 1) in the training sample 
      fit_train <- fit_model(outcome = outcome, labeled = labeled, 
                             covariates = covariates_use, data = data_train, 
                             seed = seed, method = method, family = family,
                             ps = ps)
      
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
      
      # id
      id_final <- c(test_which, id_final)
    }
    
    
    # data_lo
    id_lo <- c(id_final, no_label_which)
    data_lo <- data[id_lo, ]
    
    # 1. SSL Estimator (legacy)
    PI <- c(PI_label, PI_no_label_sum/cross_fit)
    data_lo$Y_int <- PI
    X_lo <- model.matrix(formula_lo_use, data = data_lo)
    lo_PI <- glogit(Y = PI, X = X_lo)
    
    PI_point_l[ss_use, 1:ncol_X] <- lo_PI$coef
    PI_se_l[ss_use, 1:ncol_X]    <- lo_PI$se
    
    # 2. Design-based Semi-Supervised Learning (DSL) Estimator
    dm <- c(dm_label, dm_no_label_sum/cross_fit)
    lo_dm <- glogit(Y = dm, X = X_lo)
    
    dm_point_l[ss_use, 1:ncol_X] <- lo_dm$coef
    dm_se_l[ss_use, 1:ncol_X]    <- lo_dm$se
  }
  
  # 1. SSL Estimator (legacy)
  PI_point <- apply(PI_point_l, 2, median)
  PI_se_0  <- PI_se_l^2 + (t(t(PI_point_l) - PI_point))^2
  PI_se    <- sqrt(apply(PI_se_0, 2, median))
  
  # 2. Design-based Semi-Supervised Learning (DSL) Estimator
  dm_point <- apply(dm_point_l, 2, median)
  dm_se_0  <- dm_se_l^2 + (t(t(dm_point_l) - dm_point))^2
  dm_se    <- sqrt(apply(dm_se_0, 2, median))
  
  out <- list("PI_point" = PI_point, 
              "PI_se" = PI_se, 
              "dm_point" = dm_point,
              "dm_se" = dm_se)
  
  return(out)
}


glogit <- function(Y, X, lambda = 0.00001){
  initial <- rep(0, ncol(X))
  
  X_new <- cbind(1, scale(X[,-1]))
  
  #precompute constants
  cons <- 2/(ncol(X_new)*nrow(X_new)^2)
  X2 <- X_new^2
  #optimize using L-BFGS-B
  out_opt <- optim(par = initial, X = X_new, Y = Y, X2=X2, cons=cons, lambda=lambda,
                   fn = logit_mm1, gr=logit_grad1,
                   method="L-BFGS-B", control=list(maxit=1000))
  est_0 <- out_opt$par
  
  # standard errors
  n <- length(Y)
  res <- Y - boot:::inv.logit(X_new %*% est_0)
  phi <- X_new * as.numeric(res)
  Omega <- (t(phi) %*% phi)/n
  pi <- as.numeric(boot:::inv.logit(X_new %*% est_0))
  X_1   <- X_new *pi
  X_0   <- X_new * (1-pi)
  M <- (t(X_1) %*% X_0)/n
  M_i <- MASS::ginv(t(M)%*%M)
  V0 <- (M_i%*%t(M)%*%Omega%*%M%*%M_i)/n
  
  # recalibrate
  mean_X <- apply(X[,-1], 2, mean)
  sd_X   <- apply(X[,-1], 2, sd)
  
  D_1 <- c(1, - mean_X/sd_X)
  D_2 <- cbind(0, diag(1/sd_X))
  D   <- rbind(D_1, D_2)
  
  est <- D %*% est_0
  V   <- D %*% V0 %*% t(D)
  
  out <- list("coef" = est, "se" = sqrt(diag(V)), "vcov" = V)
  
  return(out)
}

logit_mm1 <- function(Y, X, X2, cons, beta, lambda = 0.00001){
  inv_logit <- 1/(1+exp(-X%*%beta))
  m <- crossprod(X,(Y - inv_logit)/nrow(X))
  return(mean(m^2)+ lambda*mean(beta^2))
}

logit_grad1 <- function(Y, X, X2, cons,beta, lambda = 0.00001){
  inv_logit <- 1/(1+exp(-X%*%beta))
  a <- crossprod(Y-inv_logit,X)
  b <- crossprod(-(inv_logit)*(1-inv_logit),X2)
  out <- cons*a*b + lambda*mean(2*abs(beta))
  return(out)
}

