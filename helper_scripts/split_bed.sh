#!/bin/sh

## Usage ./splitBed.sh input.bed

# the TR file will be split into separate files by chromosome

input=$1
mkdir repeats_by_chrom
while read chr;
do
	file=repeats_by_chrom/${chr}.bed.gz
	#echo $chr
	grep -w $chr $input | gzip > $file
done < list.txt
