#!/bin/bash

# Parallel bedtools operations for RExPRT
# This script runs independent bedtools intersect operations in parallel

set -e

if [ $# -lt 1 ]; then
    echo "Usage: $0 input_file"
    exit 1
fi

INPUT_FILE=$1
OUTPUT_DIR="parallel_temp"
mkdir -p $OUTPUT_DIR

echo "Running parallel bedtools operations..."

# Function to run a single bedtools operation
run_bedtools_operation() {
    local operation=$1
    local output_file=$2
    local annotation_file=$3
    local column_name=$4

    echo "Starting $operation..."

    head -1 $INPUT_FILE > $OUTPUT_DIR/header_$operation
    awk -v col="$column_name" '{print $0 "\t" col}' $OUTPUT_DIR/header_$operation > $OUTPUT_DIR/head_$operation && mv $OUTPUT_DIR/head_$operation $OUTPUT_DIR/header_$operation

    ./data/bedtools.static.binary intersect -a $INPUT_FILE -b $annotation_file -c > $OUTPUT_DIR/intersection_$operation
    cat $OUTPUT_DIR/header_$operation $OUTPUT_DIR/intersection_$operation > $output_file

    echo "Completed $operation"
}

export -f run_bedtools_operation
export INPUT_FILE
export OUTPUT_DIR

# Check if GNU parallel is available
if command -v parallel >/dev/null 2>&1; then
    echo "Using GNU parallel for bedtools operations..."

    # Define parallel operations (operations that don't depend on each other)
    parallel --no-notice -j 4 ::: \
        "run_bedtools_operation TAD $OUTPUT_DIR/tad_annotated.txt data/annotation_files/TADboundaries_CpGcount.bed TAD" \
        "run_bedtools_operation eSTR $OUTPUT_DIR/estr_annotated.txt data/annotation_files/eSTR_loci_hg19.sorted.bed eSTR" \
        "run_bedtools_operation opReg $OUTPUT_DIR/opreg_annotated.txt data/annotation_files/openRegulatoryRegions_hg19.sorted.bed opReg" \
        "run_bedtools_operation promoter $OUTPUT_DIR/promoter_annotated.txt data/annotation_files/promoters.sorted.bed promoter"

    # Wait for parallel operations to complete
    wait

    # Now run sequential operations that depend on previous results
    echo "Running sequential bedtools operations..."

    # Start with the first parallel result
    cp $OUTPUT_DIR/tad_annotated.txt final_annotated_parallel.txt

    # Add eSTR
    head -1 final_annotated_parallel.txt > header
    awk '{print $0 "\teSTR"}' header > head && mv head header
    ./data/bedtools.static.binary intersect -a final_annotated_parallel.txt -b data/annotation_files/eSTR_loci_hg19.sorted.bed -c > intersection
    cat header intersection > final_annotated_parallel.txt

    # Add opReg
    head -1 final_annotated_parallel.txt > header
    awk '{print $0 "\topReg"}' header > head && mv head header
    ./data/bedtools.static.binary intersect -a final_annotated_parallel.txt -b data/annotation_files/openRegulatoryRegions_hg19.sorted.bed -c > intersection
    cat header intersection > final_annotated_parallel.txt

    # Add promoter
    head -1 final_annotated_parallel.txt > header
    awk '{print $0 "\tpromoter"}' header > head && mv head header
    ./data/bedtools.static.binary intersect -a final_annotated_parallel.txt -b data/annotation_files/promoters.sorted.bed -c > intersection
    cat header intersection > final_annotated_parallel.txt

else
    echo "GNU parallel not available, running sequential operations..."
    # Fallback to original sequential approach
    cp $INPUT_FILE final_annotated_parallel.txt
fi

# Clean up
rm -rf $OUTPUT_DIR

echo "Parallel bedtools operations completed!"
