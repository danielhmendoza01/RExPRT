args <- commandArgs(trailingOnly = TRUE)

table <- read.csv(args[1], stringsAsFactors=F, header=T, sep="\t")
subset_table <- subset(table, select=c("id","gene","motif"))

# multiply the motif by 10 to create a sequence
subset_table$motif <- strrep(subset_table$motif,10)

write.table(subset_table, file="S2SNet/seqs.txt", quote=F, row.names=F, col.names=F, sep="\t")
