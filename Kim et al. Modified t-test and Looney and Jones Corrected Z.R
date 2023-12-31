types_of_pairs<-function(x,y){
  if(length(x) == 0 & length(y) == 0)
    stop("error: no data to interpret")
  temp <- data.frame(x,y)
  complete_pairs <- temp[!is.na(x) & !is.na(y),]
  
  # Group 2: Only Sample 1 is missing
  sample1_missing <- temp[is.na(x) & !is.na(y),]
  
  # Group 3: Only Sample 2 is missing
  sample2_missing <- temp[!is.na(x) & is.na(y),]
  
  # Group 4: Both Sample 1 and Sample 2 are missing
  both_missing <- temp[is.na(x) & is.na(y),]
  
  result <- list(n1 = complete_pairs,
                 n3 = sample1_missing,
                 n2 = sample2_missing,
                 n4 = both_missing)
  return(result)
}

Kim_modified_t<-function(x,y, alternative = "two.sided", conf.level = 0.95, mu = 0, independence = "independent"){
  #makes sure there is a valid confidence level
  if(conf.level < 0 | conf.level > 1)
    stop("please input a confidence level that is bewteen 0 and 1")
  
  #makes sure there is a valid alternative
  allowed_alternatives = c("two.sided", "less", "greater")
  if (!any(alternative %in% allowed_alternatives))
    stop("Invalid alternative. Choose one of: two.sided, greater, less.")
  
  #makes sure there is a valid indpendence
  allowed_independence = c("both", "independent", "dependent")
  if (!any(alternative %in% allowed_alternatives))
    stop("Invalid alternative. Choose one of: both, independent, dependent")
  
  #CASE 1: all n's are 0
  if(missing(x)| missing(y))
    stop("please make sure there are values for both Sample1(x) and Sample2(y)")
  
  #get the values of n1, n2, n3, and n4 where x is sample1 and y is sample2
  n1_df <- types_of_pairs(x,y)$n1
  n2_df <- types_of_pairs(x,y)$n2
  n3_df <- types_of_pairs(x,y)$n3
  n4_df <- types_of_pairs(x,y)$n4
  
  #get the amount of pairs that each group has
  n1<- length(n1_df[,1])
  n2<- length(n2_df[,1])
  n3<- length(n3_df[,1])
  n4<- length(n4_df[,1])
  
  #CASE 1: all data is missing n1,n2,n3 = 0
  if(n4 == length(x)){
    stop("error: all data is missing")
  }
  #CASE 2: all pairs are matched --> the data must be paired and n1 > 0
  else if(n1 == length(x) - n4){
    difference <- n1_df[,1]-n1_df[,2]
    if(length(difference) >= 3 & length(difference) < 5000){
      
      #testing normalicy
      if((length(difference) >=3 & length(difference) <= 5000) & shapiro.test(difference)$p.value > (1-conf.level)){
        cat(paste("The data is normally distributed. Attempting a paired t-test since the shapiro test p value is greater than",(1-conf.level), "\n"))
        return(t.test(n1_df[,1], n1_df[,2],paired = TRUE, alternative = alternative,mu=mu, conf.level = conf.level)) 
      }
      
      cat("The data is NOT normally distributed. Attempting a paried wilcox-test\n")
      return(wilcox.test(n1_df[,1],n1_df[,2],paired = TRUE, alternative = alternative, mu=mu, conf.level = conf.level))
    }
    stop("Error: there are not enough values to do a paried test with Sample1 and Sample2 data")
  }
  
  #CASE 3: only n2 > 0
  else if(n1 == 0 & n3 == 0 & n2 >0){
    return(single_Variable(n2_df[,1], conf.level = conf.level, alternative = alternative, mu = mu))
  }
  
  #CASE 4: n3 > 0
  else if(n1 == 0 & n2 == 0 & n3 >0){
    return(single_Variable(n3_df[,2], conf.level=conf.level, alternative = alternative, mu=mu))
  }
  
  #CASE 5: n1,n2,n3 > 0 do the Kim et. al Modifed t statistic
  else if(n1 > 0 & n2 > 0 & n3 > 0){
    if(n2< 1 | n3 < 1) stop("not enough values to do this calculation on. There must be at least 2 values for each n2, and n3")
    
    D <- n1_df[,1]-n1_df[,2] #mean difference of the n1 paried
    dbar <- mean(D)
    tbar <- mean(n2_df[,1]) #mean of x in n2
    nbar <- mean(n3_df[,2]) #mean of y in n3
    n_H <- 2/(1/n2 + 1/n3) #the harmonic mean
    
    numerator <- n1*dbar + n_H*(tbar - nbar) - mu
    denominator <- sqrt(n1 * var(D) + n_H^2 * (var(n2_df[, 1]) / n2 + var(n3_df[, 2]) / n3))
    if(denominator == 0) stop("Error: dividing by 0")
    t3<- numerator/denominator
    
    p.value <- 0
    df <- n1+n2+n3
    if(alternative == "two.sided") {
      p.value <- 2*(1- pnorm(abs(t3)))
      conf.int <- c(t3 - qt(conf.level, df), t3 + qt(conf.level, df)) #fix this 
    }else if(alternative == "greater") {
      p.value <- 1 - pnorm(t3)
      conf.int <-  c(t3 - qt(conf.level, df), Inf) 
      
    }else{
      p.value <- pnorm(t3)
      conf.int <- c(-Inf, t3 + qt(conf.level, df))
    }
    
    #this is used for pretty printing to make it look like R standard
    names(t3) <- "t"
    names(df) <- "df"
    attr(conf.int,"conf.level") <- conf.level
    names(mu) <- if(!is.null(y)) "difference in means" else "mean"
    result <- list(statistic = t3, parameter = df, p.value = p.value,
                   conf.int = conf.int,
                   alternative = alternative,
                   method = "Kim's et. al Modified t Test", data.name = paste(deparse(substitute(x)), "and", deparse(substitute(y))),
                   null.value = mu)
    
    class(result) <- "htest"
    return(result)
  }
  
  #CASE 6: n2,n3 > 0
  else if (n1 == 0 & n2 > 0 & n3 > 0) {
    # do we have enough data for the test to be completed
    if ((n2 < 3 & n2 > 5000) | (n3 < 3 & n3 > 5000)) stop("not enough data for analysis")
    normal <- shapiro.test(n2_df[, 1])$p.value > (1-conf.level) & shapiro.test(n3_df[, 2])$p.value > (1-conf.level)
    var_equals <- var.test(n2_df[,2],n3_df[,1])$p.value > (1-conf.level)
    
    if (independence == "independent") {
      if(normal)
        return(t.test(n2_df[,2], n3_df[,1], var_equal = var_equals, alternative = alternative, conf.level, mu=mu))
      return(wilcox.text(n2_df[,2], n3_df[,1],alternative = alternative, conf.level, mu=mu))
      
    } else if (independence == "dependent") {
      if(normal)
        return(t.test(n2_df[,2], n3_df[,1], paired = TRUE, alternative = alternative,var_equal = var_equals, conf.level,mu = mu))
      return(wilcox.text(n2_df[,2], n3_df[,1], paried = TRUE, alternative = alternative, conf.level,mu = mu))
      
    } else if (independence == "both") {
      if(normal){
        tTESTN <- t.test(n2_df[,2], n3_df[,1], var_equal = var_equals, alternative = alternative, conf.level,mu = mu)
        pairedTESTN<-t.test(n2_df[,2], n3_df[,1], paired = TRUE, alternative = alternative, conf.level,mu = mu)
        return(list(tTESTN, pairedTESTN))
      }else
        wTEST<- wilcox.text(n2_df[,2], n3_df[,1], alternative = alternative, conf.level=conf.level,mu=mu)
      pairedWTEST <- wilcox.text(n2_df[,2], n3_df[,1], paried = TRUE, alternative = alternative, conf.level,mu = mu)
      return(list(wTEST, pairedWTEST))
    }
  }
  
  #CASE 7: n1,n2 > 0
  else if(n3 == 0 & n1 > 0 & n2 > 0) { 
    if ((n1 < 3 & n1 > 5000) | (n2 < 3 & n2 > 5000)) stop("not enough data for analysis")
    cat("Since there are no good tests for when n1 and n2 are >0 but n3 =0, we will use known preexiting tests with the limitations they have. Since you chose ", independence, " the appropriate test will be conducted\n\n")
    x <- c(n1_df[,1],n2_df[,1])
    return(two_Varaible(x,conf.level,alternative, independence, n1_df,mu = mu))
  }
  
  #CASE 8: n1,n3 > 0
  else if(n2 == 0 & n1 > 0 & n3 > 0){
    if ((n2 < 3 & n2 > 5000) | (n3 < 3 & n3 > 5000)) stop("not enough data for analysis")
    cat("Since there are no good tests for when n1 and n2 are >0 but n3 =0, we will use known preexiting tests with the limitations they have. Since you chose", independence, "the appropriate test will be conducted\n\n")
    y <- c(n1_df[,1],n3_df[,2])
    return(two_Varaible(y,conf.level = conf.level,alternative = alternative, independence = independence, n1_df,mu = mu))
  }
  else
    return("missing case")
}
single_Variable <- function(x, conf.level = .95, alternative = "two.sided",mu = 0){
  #check to see if we have enough data to do a test on
  if(length(x)>=3 & length(x)<= 5000){
    #checks for normalcy
    value <- shapiro.test(x)$p.value
    if(shapiro.test(x)$p.value > c(1-conf.level)){
      cat(paste("The data is normally distributed. Attempting a t-test since the shapiro test p value is greater than",(1-conf.level)))
      return(t.test(x, conf.level = conf.level, alternative = alternative,mu = mu))
    }
    cat("The data is NOT normally distributed. Attempting a  wilcox-test. Attempting a t-test since the shapiro test p value is less than",(1-conf.level),"\n")
    return(wilcox.test(x, conf.level = conf.level, alternative = alternative,mu = mu)) 
  }
  stop("Error: there are not enough values to do a test with Sample1 data")
}

two_Varaible <- function(x, conf.level = .95, alternative = "two.sided", independence = "both", n1_samples, mu = 0){
  n1_df <- n1_samples
  normal <- shapiro.test(x)$p.value > (1-conf.level)
  difference <- n1_df[,1]-n1_df[,2]
  difference.normal <- shapiro.test(difference)$p.value > (1-conf.level) #testing the normalicy of the difference
  
  if(independence == "dependent"){
    if(difference.normal){
      cat(paste("The data is normally distributed. Attempting a paired t-test since the shapiro test p value is greater than",(1-conf.level), "\n"))
      return(t.test(n1_df[,1], n1_df[,2],paired = TRUE, alternative = alternative,var.equals = var_equals,conf.level,mu = mu)) 
    }
    cat("The data is NOT normally distributed. Attempting a paried wilcox-test\n")
    return(wilcox.test(n1_df[,1],n1_df[,2],paired = TRUE, alternative = alternative,conf.level = conf.level,mu = mu))
  }
  else if(independence == "independent"){
    if(normal){
      cat(paste("The data is normally distributed. Attempting a two sample t-test since the shapiro test p value is greater than",(1-conf.level), "\n"))
      return(t.test(x,alternative = alternative,var.equals = var_equals,conf.level = conf.level,mu = mu))
    }else{
      cat("The data is NOT normally distributed. Attempting a two sample wilcox-test\n")
      return(wilcox.test(x,alternative = alternative,conf.level = conf.level,mu = mu))
    }
  }else{
    if(difference.normal){
      dependT <- t.test(n1_df[,1], n1_df[,2],paired = TRUE, alternative = alternative,conf.level,mu = mu)
    }else{        
      dependW <- wilcox.test(n1_df[,1],n1_df[,2],paired = TRUE, alternative = alternative,conf.level,mu = mu)
    }
    if(normal){
      indepenT <- t.test(x,alternative = alternative,var.equals = var_equals,conf.level = conf.level,mu = mu)
      if(difference.normal) 
        return(list(dependT,indepenT))
      return(list(dependW,indepenT))
    }else{
      indepenW <- wilcox.test(x,alternative = alternative,conf.level = conf.level,mu = mu)
      if(difference.normal) 
        return(list(dependT,indepenW))
      return(list(dependW,indepenW))
    }
  }
}

Looney_Jones_CorrectedZ <- function(x,y, conf.level = 0.95, alternative = "two.sided",mu = 0){
  if(conf.level < 0 | conf.level > 1) stop("please input a confidence level that is bewteen 0 and 1")
  
  allowed_alternatives = c("two.sided", "less", "greater")
  if (!any(alternative %in% allowed_alternatives)) stop("Invalid alternative. Choose one of: two.sided, greater, less.")
  
  #get the values of n1, n2, n3, and n4 where x is sample1 and y is sample2
  n1_df <- types_of_pairs(x,y)$n1
  n2_df <- types_of_pairs(x,y)$n2
  n3_df <- types_of_pairs(x,y)$n3
  n4_df <- types_of_pairs(x,y)$n4
  
  #get the amount of pairs that each group has
  n1 <- length(n1_df[,1])
  n2 <- length(n2_df[,1])
  n3 <- length(n3_df[,1])
  n4 <- length(n4_df[,1])
  
  if(n1 == 0 & n2 == 0 & n3 == 0) stop("Error: please input numerical values")
  
  #we do two sample test
  if(n1 == 0 & n2 >0 & n3 > 0){
    variance <- var.test(n2_df[,1], n3_df[,2])$p.value >= (1-conf.level)
    normal <- shapiro.test(n2_df[,1])$p.value > (1-conf.level) & 
      shapiro.test(n3_df[,2])$p.value > (1-conf.level)
    if(normal)
      return(t.test(n2_df[,1], n3_df[,2], var.equal = variance,mu = mu, alternative = alternative))
    return(wilcox.test(n2_df[,1], n3_df[,2],mu = mu, alternative = alternative))
  }
  
  #we do a paired t test
  else if(n2 == 0 & n3 == 0 & n1>0){
    variance <- var.test(n1_df[,1], n1_df[,2])$p.value >= (1-conf.level)
    normal <- shapiro.test(n1_df[,1])$p.value > (1-conf.level) & shapiro.test(n1_df[,2])$p.value > (1-conf.level)
    if(normal)
      return(t.test(n1_df[,1], n1_df[,2], var.equal = variance, paired= TRUE,alternative = alternative,mu=mu))
    return(wilcox.test(n1_df[,1], n1_df[,2], paried = TRUE,alternative = alternative, mu=mu))
  }
  
  tStar <- mean(c(n1_df[,1], n2_df[,1]))
  nStar <- mean(c(n1_df[,2], n3_df[,2]))
  sTvar <- var(c(n1_df[,1], n2_df[,1]))
  sNvar <- var(c(n1_df[,2], n3_df[,2]))
  sTNvar <- cov(n1_df[,1],n1_df[,2])
  
  if(tStar == 0 | nStar == 0 |sTvar == 0 |sNvar == 0 |sTNvar == 0) stop("Artimetic Error: Dividing by 0")
  
  numerator <- tStar - nStar - mu
  denominator <-sqrt(sTvar/(n1 + n2) + sNvar/(n1+n3) - 2*n1*sTNcov/((n1+n2*(n1+n3))))
  zcorr <- numerator/denominator
  
  if(alternative == "two.sided") {
    pval <- 2 * pnorm(-abs(zcorr))
    alpha <- 1 - conf.level
    cint <- c(zcorr - qnorm((1 - alpha/2)) * (denominator/sqrt(n1+n2+n3)), zcorr + qnorm((1 - alpha/2))* (denominator/sqrt(n1+n2+n3)))
    
  }else if(alternative == "greater") {
    p.value <- 1 - pnorm(zcorr)
    conf.int <- c(zcorr-qnorm(conf.level) * (denominator/sqrt(n1+n2+n3)), Inf)
    
  }else{
    pvalue <- pnorm(zobs)
    conf.int <- c(-Inf, zcorr + qnorm(conf.level) * (denominator/sqrt(n1+n2+n3))) 
  }
  p.value <- 0
  df <- n1+n2+n3
  names(t3) <- "z"
  names(df) <- "df"
  attr(conf.int,"conf.level") <- conf.level
  names(mu) <- if(!is.null(y)) "difference in means" else "mean"
  result <- list(statistic = t3, parameter = df, p.value = p.value,
                 conf.int = conf.int,
                 alternative = alternative,
                 method = "Looney and Jones Corrected Z Test", data.name = paste(deparse(substitute(x)), "and", deparse(substitute(y))),
                 null.value = mu)
  class(result) <- "htest"
  return(result)
}

data <- data.frame(
  Sample1 = c(1, 3, 5, 8, 6, NA, 5, NA, NA, 2, NA, NA, 1),
  Sample2 = c(NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA, NA)
)
data1 <- data.frame(
  Sample1 = c(1, 2,  7,  8,  3, NA, 1,  99, 4,  2,  NA,7,  9),
  Sample2 = c(NA, 2, NA, NA, 3, NA, NA, 67, NA, NA, NA, 2, NA)
)





