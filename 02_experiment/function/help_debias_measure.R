# Compute the debiased measure 
fit_test <- function(fit_out, 
                     outcome, labeled, covariates, data, method, family, seed = 1234){

  formula_X <- as.formula(paste0("~", paste(c(covariates), collapse = "+")))
  X  <- model.matrix(formula_X, data = data)[,-1]
  if (dim(data)[1]==1) { # MJH
    message("WARNING: single observation in prediction dataset, coercing from vector to matrix")
    X <- t(as.matrix(X))
  }
  
  if(method == "grf"){
    new_data_use <- X
    Y_hat <- predict(fit_out, newdata = new_data_use)$predictions
  }else if(method == "glm"){
    new_data_use <- data
    Y_hat <- predict(fit_out, newdata = new_data_use, type = "response")
  }
  
  return(Y_hat)
}

# Fit model 
fit_model <- function(outcome, labeled, covariates, data, method, ps = NULL, family = "gaussian", seed = 1234){
  
  formula   <- as.formula(paste0(outcome, "~", paste(c(labeled, covariates), collapse = "+")))
  formula_X <- as.formula(paste0(outcome, "~", paste(c(covariates), collapse = "+")))
  
  mf <- model.frame(formula, data = data)
  Y  <- as.numeric(model.response(mf))
  R <- as.numeric(mf[, labeled])
  X_name <- colnames(model.matrix(formula_X, data = data)) # this is more robust way to handle categorical variables
  X  <- model.matrix(formula, data = data)[, X_name[-1]] # this is more robust way to handle categorical variables
  if (dim(data)[1]==1) {
    message("WARNING: single observation in training dataset, coercing from vector to matrix")
    X <- t(as.matrix(X))
  }
  
  if(method == "grf"){
    # outcome model 
    if(is.null(ps) == FALSE){
      fit_out <- regression_forest(X = X[R == 1, ], Y = Y[R == 1], seed = seed, sample.weights = 1/data[,ps])
    }else if(is.null(ps) == TRUE){
      fit_out <- regression_forest(X = X[R == 1, ], Y = Y[R == 1], seed = seed)
    }
  }else if(method == "glm"){
    fit_out <- glm(formula_X, data = data[data[, labeled] == 1, , drop = FALSE], family = family)
  }
  return(fit_out)
}
