#' Reconstructing ancestral states of discrete and continuous characters
#'
#' This function returns ancestral state estimates using a variety of methods
#'
#' @param td An object of class 'treedata'
#' @param colID A column selector for the dataframe in td
#' @param charType specifies the type of character, either:
#' \describe{
#' 		\item{"discrete"}{a character with a discrete number of states}
#' 		\item{"continuous"}{a continuously varying character}	
#' 		\item{"fromData"}{will attempt to determine the data type from the data itself; DO NOT USE YET!}
#'	}
#' @param aceType specifies the method used to reconstruct ancestral character states:
#' \describe{
#' 		\item{"marginal"}{marginal ancestral state reconstructions, which reconstruct each node integrating over all possibilities at all other nodes in the tree; this is typically the method used in the literature to reconstruce ACEs}
#' 		\item{"joint"}{joint ancestral reconstructions, which give the configuration of ancestral states that together maximize the likelihood of the data given model parameters}	
#' 		\item{"mcmc"}{reconstruct ancestral states using Bayesian MCMC. Note that the discrete version of this doesn't seem to work, and even if it did work it is not a full MCMC ancestral state method}
#'		\item{"stochastic"}{create stochastic character map}
#'	}	
#' @param discreteModelType One of ER, SYM, or ARD; see geiger's fitDiscrete for full description
#' @param plot If true, make a plot of ancestral states.
#' @export

aceArbor<-function(td, charType="continuous", aceType="marginal", discreteModelType="ER", na.rm="bytrait") {
	
	# check character type
	ctype = match.arg(charType, c("discrete", "continuous"))
	discreteModelType = match.arg(discreteModelType, c("ER", "SYM", "ARD"))
	aceType = match.arg(aceType, c("marginal", "joint", "MCMC", "stochastic"))
	
	
	# check that the data actually make sense - this is a pretty weak test
	if(charType=="continuous") {
    td <- checkNumeric(td, return.numeric=TRUE)
	}
	if(charType=="discrete") {
	  td <- checkFactor(td, return.factor=TRUE)
	}
	
  if(any(is.na(td$dat))){
    if(na.rm=="bytrait"){
      res <- lapply(1:ncol(td$dat), function(i) {
        tdi <- select(td, i);
        tdi <- filter(tdi, !is.na(tdi$dat[,1]));
        aceArborCalculator(tdi$phy, setNames(tdi$dat[,1], rownames(tdi$dat)), charType, aceType, discreteModelType)
      })
    }
    if(na.rm=="all"){
      td <- filter(td, apply(apply(td$dat, 1, function(x) !is.na(x)), 2, all))
      res <- lapply(td$dat, function(x) aceArborCalculator(td$phy, setNames(x, rownames(td$dat)), charType, aceType, discreteModelType))
    }
  } else {
	  res <- lapply(td$dat, function(x) aceArborCalculator(td$phy, setNames(x, rownames(td$dat)), charType, aceType, discreteModelType))
  }
  class(res) <- c("asrArbor", class(res))
  attributes(res)$td <- td
	attributes(res)$charType <- charType
	attributes(res)$aceType <- aceType
  if(charType=="discrete"){
    attributes(res)$discreteModelType = discreteModelType
    attributes(res)$charStates = lapply(1:ncol(td$dat), function(x) levels(td$dat[,x]))
    attributes(res)$aceType <- aceType

  }
  if(any(is.na(td$dat))){
    attributes(res)$na.drop <- lapply(td$dat, function(x) rownames(td$dat)[which(is.na(x))])
  }
	# Note discrete "joint" and "MCMC" return weird stuff and don't work
	names(res) <- colnames(td$dat)
	return(res)
	
}	

aceArborCalculator<-function(phy, dat, charType="continuous", aceType="marginal", discreteModelType="ER", mcmcGen=10000, mcmcBurnin=1000, names=NULL) {
	
	# this function requires a phylo object
 	# and a dat
	# and a colID that tells which column to use
  
	# optional arguments:
	# charType allows the user to force the data to be treated as continuous or discrete.
	# otherwise, factors are treated as discrete and anything else is treated as continuous
	# it might be nice to change this so that continuous data that only has a small number of values is discrete e.g. 0 and 1
	
	# "model" is there for users to pass through details of model specificiation.
	# e.g. OU for continuous, or sym/ard for discrete
	# this is not yet implemented
	
	# check character type
	ctype = match.arg(charType, c("discrete", "continuous"))
	discreteModelType = match.arg(discreteModelType, c("ER", "SYM", "ARD"))
	aceType = match.arg(aceType, c("marginal", "joint", "MCMC", "stochastic"))
	
	if(ctype=="discrete") {
		
		# this changes the discrete data to 1:n and remembers the original charStates
		fdat<-as.factor(dat)
		charStates<-levels(fdat)
		k<-nlevels(fdat)
		
		ndat<-as.numeric(fdat)
    	names(ndat) <- names(fdat)
		
		if(!is.null(names)) names(ndat)<-names
		
		if(aceType=="marginal") {
			zz<- getDiscreteAceMarginal(phy, ndat, k, discreteModelType);
		} else if(aceType=="joint") { # this should be modified to average over many reps
			zz<- getDiscreteAceJoint(phy, ndat, k, discreteModelType)
		} else if(aceType=="MCMC"){
			zz<- getDiscreteAceMCMC(phy, ndat, k, discreteModelType)
		} else if(aceType=="stochastic"){
			zz<-getDiscreteAceStochastic(phy, ndat, k, discreteModelType)
		}
		
		#if(plot) plotDiscreteReconstruction(phy, zz, dat, charStates)
    	
    	if(aceType != "stochastic") colnames(zz)<-charStates
		return(zz)	
			
	} else if(ctype=="continuous") {
		if(aceType=="marginal") {
			zz<-fastAnc(phy, dat, CI=T)
			ancestralStates<-data.frame(lowerCI95 = zz$CI95[,1], estimate = zz$ace, upperCI95=zz$CI95[,2])
			rownames(ancestralStates)<-names(zz$ace)
			names(dat)<-phy$tip.label 
			#phenogram(phy, dat)
			return(ancestralStates)
		} else if (aceType=="MCMC") {
			names(dat)<-phy$tip.label 
			bayesOutput<-anc.Bayes(phy, dat, ngen= mcmcGen)
			bayesChar<-bayesOutput[,-which(colnames(bayesOutput) %in% c("gen", "sig2", "logLik"))]
			aceStates<-apply(bayesChar, 2, mean)
			CI95 <-t(apply(bayesChar, 2, function(x) quantile(x, c(0.025, 0.975))))
			ancestralStates<-cbind(CI95[,1], aceStates, CI95[,2])
			rownames(ancestralStates)<-names(aceStates)
			zz<-list(ancestralStates= ancestralStates, bayesOutput=bayesOutput)
			return(zz)
		} else {
			stop("Not supported yet")
		}
		
	} else stop("Invalid character type in aceArbor.\n")
	
}

getDiscreteAceMarginal<-function(phy, ndat, k, discreteModelType) {
	
	if(discreteModelType =="ER") extra="q" else extra=NULL

	lik<-make.mkn(phy, ndat, k=k)
	con<-makeMkConstraints(k=k, modelType= discreteModelType)
	ltemp<-lik
	
	if(!is.null(con))
		for(i in 1:length(con)) ltemp<-constrain(ltemp, con[[i]], extra=extra)
	
	lik<-ltemp
	
	pnames<-argnames(lik)
	fit<-find.mle(lik, setNames(rep(1,length(pnames)), argnames(lik)))
	
	zz<-t(asr.marginal(lik, coef(fit)))
  attributes(zz)$fit <- fit
	zz		
}

#' @export
plotDiscreteReconstruction<-function(phy, zz, dat, charStates, pal=rainbow, cex=1, cex.asr=0.5, ...) {
	plot(phy, cex=cex, ...)
	nodelabels(pie=zz, piecol=pal(length(charStates)), cex=cex.asr, frame="circle")
	tiplabels(pch=21, bg=pal(length(charStates))[as.numeric(factor(dat, levels=charStates))], cex=2*cex.asr) 
	legend("bottomleft", fill=pal(length(charStates)), legend=charStates)
}

#' @export
plot.asrArbor <- function(asrArbor, ...){
  type <- attributes(asrArbor)$charType
  td <- attributes(asrArbor)$td
  na.drop <- attributes(asrArbor)$na.drop
  if(type=="discrete"){
    charStates <- attributes(asrArbor)$charStates
    if("list" %in% class(asrArbor)){
      for(i in 1:length(asrArbor)){
        if(length(asrArbor) > 1) par(ask=TRUE)
        if(attributes(asrArbor)$aceType=="stochastic") {
        	plot(asrArbor[[1]], td$phy)
        } else {
        	plotDiscreteReconstruction(drop.tip(td$phy, na.drop[[i]]), asrArbor[[i]], td$dat[!(rownames(td$dat) %in% na.drop[[i]]),i], charStates[[i]], main=colnames(td$dat)[i], ...)
        }
      }
      par(ask=FALSE)
    } else {
      plotDiscreteReconstruction(drop.tip(td$phy, na.drop[[1]]), asrArbor, td$dat[!(rownames(td$dat) %in% na.drop[[1]])], charStates, colnames(td$dat)[i], ...)
    }
  }
  if(type=="continuous"){
    if("list" %in% class(asrArbor)){
      for(i in 1:length(asrArbor)){
        if(length(asrArbor) > 1) par(ask=TRUE)
        plotContAce(td, colnames(td$dat)[i], asrArbor[[i]],  ...)
      }
      par(ask=FALSE)
    } else {
        plotContAce(td, colnames(td$dat)[1], asrArbor, ...)
    }
  }
}

#' @export
print.asrArbor <- function(x, ...){
  names <- attributes(x)$names
  attributes(x) <- NULL
  attributes(x)$names <-  names
  print(x)
}

#' @export
plotContAce <- function(td, trait, asr, pal=colorRampPalette(colors=c("darkblue", "lightblue", "green", "yellow", "red")), n=100, adjp=c(0.5,0.5), cex.asr=1, cex=1, ...){
  plot(td$phy, cex=cex, ...)
  lastPP <- get("last_plot.phylo", envir = .PlotPhyloEnv)
  node <- (lastPP$Ntip + 1):length(lastPP$xx)
  XX <- lastPP$xx[node]
  YY <- lastPP$yy[node]
  make.index <- function(n=100, min, max){
    fn <- function(x){
      ramp <- seq(min, max, length.out=n)
      sapply(x, function(x) which(abs(x-ramp)==min(abs(x-ramp))))
    }
    attributes(fn)$n <- n
    return(fn)
  }
  errorpolygon <- function(x, y, lo, est, hi, pal, indexfn, cex.asr=1, adj=c(0.75, 0.5)){
    n <- attributes(indexfn)$n
    lastPP <- get("last_plot.phylo", envir = .PlotPhyloEnv)
    cex.x.scalar <- cex.asr/(100*diff(lastPP$x.lim))*adj[2]
    cex.yh.scalar <- (indexfn(hi)-indexfn(est))*adj[1]*diff(lastPP$y.lim)/n
    cex.yl.scalar <- (indexfn(est)-indexfn(lo))*adj[1]*diff(lastPP$y.lim)/n
    polygon(matrix(c(x, y+cex.yh.scalar, x-cex.x.scalar, y, x+cex.x.scalar, y), byrow=TRUE, ncol=2), border=NA, col=pal(n)[indexfn(hi)])
    polygon(matrix(c(x, y-cex.yl.scalar, x-cex.x.scalar, y, x+cex.x.scalar, y), byrow=TRUE, ncol=2), border=NA, col=pal(n)[indexfn(lo)])
    points(x, y, pch=21, cex=cex.asr, col=pal(n)[indexfn(est)], bg=pal(n)[indexfn(est)])
  }
  get.index <- make.index(100, min(asr), max(asr))
  gb <- lapply(1:length(XX), function(i) errorpolygon(XX[i], YY[i], asr[i,1], asr[i,2], asr[i,3], pal=pal, indexfn=get.index, cex.asr=cex.asr, adj=adjp))
  add.color.bar(0.5, pal(100), title = trait, lims <- c(min(asr), max(asr)), digits=2, prompt=FALSE, x=0, y=1*par()$usr[3], lwd=10, fsize=1)
  tiplabels(pch=21, bg=pal(100)[get.index(td$dat[,trait])], col=pal(100)[get.index(td$dat[,trait])] ,cex=2*cex.asr)
}


getDiscreteAceJoint<-function(phy, ndat, k, discreteModelType) {
	reps <- 1000
	
	
	if(discreteModelType =="ER") extra="q" else extra=NULL
	
  lik<-make.mkn(phy, ndat, k=k)
	con<-makeMkConstraints(k=k, modelType= discreteModelType)
	if(!is.null(con))
		lik<-constrain(lik, formulae=con, extra=extra)
				
	pnames<-argnames(lik)
	fit<-find.mle(lik, setNames(rep(1,length(pnames)), argnames(lik)))
	
	xx <-sapply(1:reps, function(x) asr.joint(lik, coef(fit)))
  zz<-matrix(0, nrow=length(xx), ncol=k)
	zz[,1]<- apply(xx, 1, function(x) sum(x==1)/reps)
	zz[,2]<- apply(xx, 1, function(x) sum(x==2)/reps)
	attributes(zz)$fit <- fit
	zz
}

getDiscreteAceMCMC<-function(phy, ndat, k, discreteModelType) { # results do not look correct to me
	lik<-make.mkn(phy, ndat, k=k)
	con<-makeMkConstraints(k=k, modelType= discreteModelType)
	if(!is.null(con))
		lik<-constrain(lik, con)
				
	set.seed(1) # this is not general
	prior <- make.prior.exponential(.5) # NOT GENERAL - we need arguments for this
	pars<-exp(prior(1))
	samples <- mcmc(lik, pars, 1000, w=1, prior=prior, print.every=10) # likewise, need control arguments here
	aceSamp <- apply(samples[c(-1, -dim(samples)[2])], 1, asr.joint, lik=lik)
	zz<-apply(aceSamp, 2, table)/1000
	attributes(zz)$fit <- fit
	t(zz)
}

getDiscreteAceStochastic<-function(phy, ndat, k, discreteModelType) {
	
	if(discreteModelType =="ER") extra="q" else extra=NULL

	lik<-make.mkn(phy, ndat, k=k)
	con<-makeMkConstraints(k=k, modelType= discreteModelType)
	ltemp<-lik
	
	if(!is.null(con))
		for(i in 1:length(con)) ltemp<-constrain(ltemp, con[[i]], extra=extra)
	
	lik<-ltemp
	
	pnames<-argnames(lik)
	fit<-find.mle(lik, setNames(rep(1,length(pnames)), argnames(lik)))
	
	zz<-asr.stoch(lik, coef(fit))
 	attributes(zz)$fit <- fit
	zz		
}
	


			