if(!require(dplyr)){install.packages("dplyr", repos = "http://cran.us.r-project.org", quiet = TRUE)}
suppressMessages(library("dplyr"))

args <- commandArgs(trailingOnly = TRUE)

dataFull <- read.delim(args[1], sep="\t", header = TRUE)
dataScores <- read.delim(args[2], sep="\t", header = TRUE)

# remove duplicates in the full dataset (scores and all features)
rmDupFull <- dataFull %>% group_by(id) %>% arrange(desc(ensembleScore), .by_group = TRUE) %>% filter(row_number() == 1)

# remove duplicates in the dataset with scores only
dataScores$ID <- paste(dataScores$chr, dataScores$start, dataScores$end, dataScores$motif, dataScores$sampleID, sep="_")
rmDupScores <- dataScores %>% group_by(ID) %>% arrange(desc(ensembleScore), .by_group = TRUE) %>% filter(row_number() == 1)

# save output

write.table(rmDupFull, file="TRsAnnotated_RExPRTscores.txt", quote=FALSE, row.names=FALSE, sep="\t")
write.table(rmDupScores, file="RExPRTscores.txt", quote=FALSE, row.names=FALSE, sep="\t")
