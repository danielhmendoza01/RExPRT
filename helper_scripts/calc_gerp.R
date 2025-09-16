if(!require(dplyr)){install.packages("dplyr", repos = "http://cran.us.r-project.org", quiet = TRUE)}
suppressMessages(library("dplyr"))
args <- commandArgs(trailingOnly = TRUE)

table <- read.csv(args[1], header=T, sep="\t", stringsAsFactors=F)
if (nrow(table) <= 1){
	quit()
}

# calculate the mean GERP score for each TR (a separate score is provided for each bp position)

table <- subset(table, select=c(chr, id, gerp_score))
annotated <- table %>% group_by(chr, id) %>% summarize(gerp_score=mean(gerp_score))
name=paste("./gerp_annotated/",unique(annotated$chr),"_annotated",sep="")
write.table(annotated, file=name, quote=F, row.names=F, sep="\t", col.names=F)
