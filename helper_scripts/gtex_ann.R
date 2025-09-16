if(!require(plyr)){install.packages("plyr", repos = "http://cran.us.r-project.org", quiet = TRUE)}
suppressMessages(library(plyr))
args <- commandArgs(trailingOnly = TRUE)

table <- read.csv(args[1],stringsAsFactors=F, sep="\t", header=T)
gtex <- read.csv(args[2], stringsAsFactors=F, sep="\t", header=T)

names(gtex)[names(gtex)=="Gene"] = "gene"

annotated <- join(table, gtex, by="gene")
cols <- c("max_tissue","ts_score","tpm")
annotated = annotated[, !(colnames(annotated) %in% cols)]

# for all TRs that do not intersect with the GTEx table, note as not expressed
annotated$tissue_simple[which(is.na(annotated$tissue_simple))] = "No_expression"


write.table(annotated, file="final_annotated.txt", quote=F, row.names=F, sep="\t")


