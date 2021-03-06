discreteCorrelation<-function(phy, charA, charB, modelType="ER") {
	
	# check for perfect name matching
	# this could be improved a lot
	
	td1<-name.check(phy, charA)
	td2<-name.check(phy, charB)

	if(td1 != "OK" | td2 != "OK") stop("Names don't match")
	
	# this changes the discrete data to 1:n and remembers the original charStates
	datA<-as.factor(charA)
	charStatesA<-levels(datA)
	kA<-nlevels(datA)
	
	datB<-as.factor(charB)
	charStatesB<-levels(datB)
	kB<-nlevels(datB)
	
	if(kA != 2 | kB != 2) stop("Only 2-state characters currently supported")
		
	mergedDat<-combineDiscreteCharacters(datA, datB)
			
	charStates<-levels(mergedDat)
	k<-nlevels(mergedDat)
		
	ndat<-as.numeric(mergedDat)
	names(ndat)<-names(mergedDat)
		
	constraint<-makeDiscreteCorrelationConstraints(modelType=modelType)
	
	lik<-make.mkn(phy, ndat, k=k)
	ulik<-constrain(lik, formulae=constraint$uCon, extra=constraint$uExtra)
	clik<-constrain(lik, formulae=constraint$cCon, extra=constraint$cExtra)
	
	unames<-argnames(ulik)
	uML<-find.mle(ulik, setNames(rep(1,length(unames)), argnames(ulik)))
	
	cnames<-argnames(clik)
	cML<-find.mle(clik, setNames(rep(1,length(cnames)), argnames(clik)))
	
	lrStat<-2*(cML$lnLik - uML$lnLik)
	lrDF <- 2*(length(cnames)-length(unames))
	
	lrPVal <- pchisq(lrStat, lrDF, lower.tail=F)
	
	return(list(unames=unames, cnames=cnames, lrStat= lrStat, lrDF= lrDF, lrPVal= lrPVal))

}



combineDiscreteCharacters<-function(dat1, dat2) {
	newDat<-interaction(dat1, dat2, lex.order=T) # lex.order to follow notation order in Pagel
	names(newDat)<-names(dat1)
	return(newDat)
}
