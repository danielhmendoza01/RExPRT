args <- commandArgs(trailingOnly = TRUE)

table <- read.csv(args[1], stringsAsFactors=F, header=T, sep="\t")

table$promoter[table$promoter>=1] = 1
table$opReg[table$opReg>=1] = 1
table$eSTR[table$eSTR>=1] = 1
table$TAD[table$TAD>=1] = 1
table$UTR_3[table$UTR_3>=1] = 1
table$UTR_5[table$UTR_5>=1] = 1

cols <- c("per_g", "per_c","per_a", "per_t", "gc_content", "eSh0", "eSh1", "eSh2", "eSh3", "eSh4", "eSh5", "eTr0", "eTr1", "eTr2", "eTr3", "eTr4", "eTr5", "eH", "eW", "eS6", "eS","J", "eX0", "eX1R", "eX2", "eX3", "eX4", "eX5")

table[cols] = round(table[cols], digits=2)
table$gerp = round(table$gerp, digits=3)


write.table(table, file="final_annotated.txt", quote=F, row.names=F, sep="\t")



