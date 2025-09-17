if(!require(stringr)){install.packages("stringr", repos = "http://cran.us.r-project.org", quiet = TRUE)}
suppressMessages(library("stringr"))
args <- commandArgs(trailingOnly = TRUE)

# Use absolute path for input file
input_file <- args[1]
output_file <- args[2]

table <- read.csv(input_file, stringsAsFactors=F, header=T, sep="\t")

table$per_g <- ((str_count(table$motif, "G")) / (str_length(table$motif))) * 100
table$per_c <- ((str_count(table$motif, "C")) / (str_length(table$motif))) * 100
table$per_a <- ((str_count(table$motif, "A")) / (str_length(table$motif))) * 100
table$per_t <- ((str_count(table$motif, "T")) / (str_length(table$motif))) * 100
table$gc_content <- table$per_g + table$per_c

write.table(table, file = output_file, quote=F, sep="\t", row.names=F, col.names=T)
