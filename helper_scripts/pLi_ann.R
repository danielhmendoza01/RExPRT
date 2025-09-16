if(!require(dplyr)){install.packages("dplyr", repos = "http://cran.us.r-project.org", quiet = TRUE)}
suppressMessages(library("dplyr"))
args <- commandArgs(trailingOnly = TRUE)

table <- read.csv(args[1], stringsAsFactors=F, header=T, sep="\t")

cols <- c("chrom","cstart","cend")
annotated = table[, !(colnames(table) %in% cols)]

# fill in missing data
annotated$loeuf[annotated$loeuf=="."] = 9
annotated$pLi[annotated$pLi==-1] = 0

write.table(annotated, file="final_annotated.txt", quote=F, row.names=F, sep="\t")

