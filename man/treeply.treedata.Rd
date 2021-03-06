% Generated by roxygen2 (4.0.1): do not edit by hand
\name{treeply}
\alias{treeply}
\alias{treeply.treedata}
\title{Run a function on the phylogeny of a 'treedata' object}
\usage{
treeply(tdObject, ...)

\method{treeply}{treedata}(tdObject, FUN, ...)
}
\arguments{
\item{tdObject}{An object of class 'treedata'}

\item{FUN}{A function that operates on an object of class 'phylo'}
}
\value{
An object of class 'treedata'
}
\description{
Applies a function to the phylogeny in a 'treedata' object. If the order of tips are changed, or if tips are dropped, then the data are automatically reordered to match the tree.
}
\examples{
data(anolis)
td <- make.treedata(anolis$phy, anolis$dat, name_column=1)
td_OU <- treeply(td, rescale, model="OU", 10)

par(mfrow=c(1,2))
plot(td$phy)
plot(td_OU$phy)
}

