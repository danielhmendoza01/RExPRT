if(!require(dplyr)){install.packages("dplyr", repos = "http://cran.us.r-project.org", quiet = TRUE)}
suppressMessages(library("dplyr"))


args <- commandArgs(trailingOnly = TRUE)


table <- read.csv(args[1], stringsAsFactors=F, header=F, sep="\t")
header <- read.table(args[2], header=T, stringsAsFactors=F, sep="\t") 


colnames(table) <- colnames(header)
cols <- c("chr.1","start.1","end.1","width","strand","tx","rank","total","gene.1","location.1","region.1","gene_type.1")
annotated = table[, !(colnames(table) %in% cols)]

write.table(annotated, file="final_annotated.txt", quote=F, row.names=F, sep="\t")





