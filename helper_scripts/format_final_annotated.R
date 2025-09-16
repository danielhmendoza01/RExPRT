data = read.csv("final_annotated.txt", stringsAsFactors=F, header=T, sep="\t")

# manual OneHotEncoding to prevent missing columns for small TR datasets

data$tissue_simple_No_expression = 0
data$tissue_simple_No_expression[which(data$tissue_simple=="No_expression")] = 1
data$tissue_simple_Nervous_System = 0
data$tissue_simple_Nervous_System[which(data$tissue_simple=="Nervous_System")] = 1
data$tissue_simple_Other = 0
data$tissue_simple_Other[which(data$tissue_simple=="Other")] = 1
data$region_intergenic = 0
data$region_intergenic[which(data$region=="intergenic")] = 1
data$region_intron = 0
data$region_intron[which(data$region=="intron")] = 1
data$region_exon = 0
data$region_exon[which(data$region=="exon")] = 1
data$location_First = 0
data$location_Middle = 0
data$location_Last = 0
data$location_Last[which(data$location=="Last")] = 1
data$location_Middle[which(data$location=="Middle")] = 1
data$location_First[which(data$location=="First")] = 1


write.table(data, file="final_annotated.txt", quote=F, row.names=F, sep="\t")
