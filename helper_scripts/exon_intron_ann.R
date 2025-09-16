if(!require(dplyr)){install.packages("dplyr",repos = "http://cran.us.r-project.org", quiet=TRUE)}
suppressMessages(library("dplyr"))


args <- commandArgs(trailingOnly = TRUE)

# import data
table <- read.csv(args[1], stringsAsFactors=F, header=F, sep="\t")
header <- read.table(args[2], header=T, stringsAsFactors=F, sep="\t")
canonical <- read.csv(args[3], header=F, stringsAsFactors=F, sep="\t")

# add header and ID column
colnames(table) <- colnames(header)
table$id = paste(table$chr,table$start,table$end,table$motif,table$sampleID, sep="_")

# create a function to mark the canonical transcript
mark_canonical <- function(table){
  table$canonical = "no"
  table$canonical[table$tx %in% canonical$V5] = "yes"
  return(table)
}

# add a column to note whether the TR is annotated 
annotated <- mark_canonical(table)


# create a function which prioritizes which annotation is used for each TR
# majority of TRs intersect with multiple UCSC annotations (different transcripts)
prioritization_algorithm <- function(table){
  # create prioritization order for the different categories
  gene_types= c("protein_coding ", "processed_transcript ", "lincRNA ", "antisense ", "snRNA", "pseudogene ", "polymorphic_pseudogene ", "sense_overlapping ", "IG_C_gene " , "Unknown", ".","intergenic")
  regions = c("exon", "intron",".","intergenic")
  locations = c("First", "Last", "Middle",".","intergenic")
  canonicals = c("yes","no")
  # convert columns to factors with the appropriate levels and then arrange so that for each TR, the highest ranked annotation will be first
  annotated = table %>% mutate(gene_type=  factor(gene_type, levels = gene_types)) %>% mutate(canonical=  factor(canonical, levels = canonicals)) %>% mutate(region=factor(region, levels=regions)) %>% mutate(location=factor(location,levels=locations)) %>% arrange(chr,start,id,gene_type,canonical,region,location) 
  return(annotated)
}

annotated <- prioritization_algorithm(annotated)


# write a function to remove columns that are not required
subset_columns <- function(table){
  cols <- c("chr.1","start.1","end.1","width","strand","tx","rank","total","canonical")
  annotated = table[, !(colnames(table) %in% cols)]
  return(annotated)
}

annotated <- subset_columns(annotated)


# write a function to annotate intergenic TRs with "intergenic" in the appropriate columns
mark_intergenic <- function(table){
#  levels(table$gene) <- c(levels(factor(table$gene)), "intergenic")
  table$gene[table$gene_distance >= 500] = "intergenic"
  table$location[table$gene_distance >= 500] = "intergenic"
  table$region[table$gene_distance >= 500] = "intergenic"
  table$gene_type[table$gene_distance >= 500] = "intergenic"
  return(table)
}

annotated <- mark_intergenic(annotated)


# remove duplicate rows for each TR
remove_duplicates <- function(table){
  annotated <- table[!duplicated(table$id),]
  return(annotated)
}

annotated <- remove_duplicates(annotated)

# save output
write.table(annotated, file="final_annotated.txt", quote=F, row.names=F, sep="\t")


