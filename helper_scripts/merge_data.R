if(!require(dplyr)){install.packages("dplyr", repos = "http://cran.us.r-project.org", quiet = TRUE)}
suppressMessages(library("dplyr"))


args <- commandArgs(trailingOnly = TRUE)


gerp <- read.csv(args[1], stringsAsFactors=F, header=T, sep="\t")
table <- read.csv(args[2], header=T, stringsAsFactors=F, sep="\t") 
annotated <- inner_join(table, gerp)
write.table(annotated, file="final_annotated.txt", quote=F, row.names=F, sep="\t", col.names=T)
