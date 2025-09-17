args <- commandArgs(trailingOnly = TRUE)

# Get project directory from command line arguments
project_dir <- args[2]

table <- read.csv(args[1], stringsAsFactors=F, header=T, sep="\t")
subset_table <- subset(table, select=c("id","gene","motif"))

# multiply the motif by 10 to create a sequence
subset_table$motif <- strrep(subset_table$motif,10)

# Use absolute path for S2SNet directory
s2snet_path <- file.path(project_dir, "S2SNet", "seqs.txt")
write.table(subset_table, file=s2snet_path, quote=F, row.names=F, col.names=F, sep="\t")
