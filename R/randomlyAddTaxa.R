#' Add species into phylogeny near hypothesized relatives
#'
#' Given two data frames, one of species in an accepted phylogeny and their corresponding
#' taxonomic assignment, and another of species to be bound in, along with their taxonomic
#' assignment, will bind the missing species in next to a taxonomic relative.
#'
#' @param tree An ape-style phylogenetic tree
#' @param realGroupings A data frame with values of class character. First column,
#' "species", must match a value in tree. Second column, "group", provides the taxonomic
#' assignment of that species. 
#' @param possGroupings A data frame with values of class character. First column,
#' "species", are tips to be added into the input tree. Second column, "group", provides
#' the taxonomic assignment of that species.
#' @param noRandomTrees The number of desired final trees with all species from 
#' possGroupings added.
#' @param saveToFile Default is FALSE. To automatically save the multiPhylo object to file
#' set to TRUE. The object will not be stored directly in memory, but it is calculated in
#' memory. The function could probably be sped up by having this save directly to file,
#' appending each tree instead of first saving them all to memory.
#' 
#' @details Given two data frames with values class CHARACTER (it is critical they are 
#' not of class factor), both with column names c("species", "group"), will take a species,
#' e.g., spA from the possGroupings data frame, find a species in the realGroupings frame, 
#' e.g., spB with the the same taxonomic group, and bind spA into the tree by creating a
#' new node at half the distance between spB and its most recent common ancestor. spA is 
#' assigned a branch length from the new node of half the original distance of the spB
#' to its original most recent common ancestor. Thus, if the input trees are ultrametric,
#' the output trees should also remain ultrametric. Currently, no effort is made to ensure
#' that the input data frames truly are of class character, nor is any effort made to
#' confirm that all taxonomic groups from possGroupings are to be found in realGroupings.
#' These checks should be built in at some point.
#'
#' @return A multiPhylo object with number of trees as determined by noRandomTrees
#'
#' @export
#'
#' @references Eliot Miller unpublished
#'
#' @examples

randomlyAddTaxa <- function(tree, realGroupings, possGroupings, noRandomTrees, saveToFile=FALSE)
{
	require(phytools)
	random.trees <- list()
	for(i in 1:noRandomTrees)
	{
		new.tree <- tree
		for(j in 1:dim(possGroupings)[1])
		{
			#subset the real groupings to those instances where the group matches the sp
			#you are adding in. then randomly choose one of those species in that group in
			#the genetic phylogeny. then identify which "node" that tip is
			bindingToList <- realGroupings$species[realGroupings$group == possGroupings$group[j]]
			bindingToSpecies <- sample(bindingToList, 1)
			bindingTo <- which(new.tree$tip.label==bindingToSpecies)

			#this identifies the node that subtends the species you are binding to
			cameFrom <- new.tree$edge[,1][new.tree$edge[,2]==bindingTo]

			#set up this temporary matrix so you can give it row names and subset according
			#to the row name. this row name becomes index, which is what you use to subset
			#to find the right edge length
			tempMatrix <- new.tree$edge
			rownames(tempMatrix) <- 1:dim(tempMatrix)[1]
			index <- rownames(tempMatrix)[tempMatrix[,1]==cameFrom & tempMatrix[,2]==bindingTo]
			index <- as.numeric(index)

			#determine what the distance from that node to the tips is
			wholeDistance <- new.tree$edge.length[index]

			#use bind.tip to add in the tip
			new.tree <- bind.tip(tree=new.tree, tip.label=possGroupings$species[j], edge.length=wholeDistance/2, where=bindingTo, position=wholeDistance/2)
		}		
		#add the last version of new tree in as a new element in the list of random, final trees
		random.trees[[i]] <- new.tree
	}

	class(random.trees) <- "multiPhylo"

	if(saveToFile == FALSE)
	{
		return(random.trees)
	}
	else
	{
		write.tree(random.trees, file="randomized_trees.tre")
		print("Trees saved to working directory")
	}
}