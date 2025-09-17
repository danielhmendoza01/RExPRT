if(!require(plyr)){install.packages("plyr", repos = "http://cran.us.r-project.org", quiet = TRUE)}
suppressMessages(library(plyr))
args <- commandArgs(trailingOnly = TRUE)

# Use absolute paths for input and output files
input_file <- args[1]
gtex_file <- args[2]
output_file <- args[3]

table <- read.csv(input_file, stringsAsFactors=F, sep="\t", header=T)
gtex <- read.csv(gtex_file, stringsAsFactors=F, sep="\t", header=T)

names(gtex)[names(gtex)=="Gene"] = "gene"

annotated <- join(table, gtex, by="gene")
cols <- c("max_tissue","ts_score","tpm")
annotated = annotated[, !(colnames(annotated) %in% cols)]

# for all TRs that do not intersect with the GTEx table, note as not expressed
annotated$tissue_simple[which(is.na(annotated$tissue_simple))] = "No_expression"

write.table(annotated, file=output_file, quote=F, row.names=F, sep="\t")
