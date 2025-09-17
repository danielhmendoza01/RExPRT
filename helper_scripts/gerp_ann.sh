#!/bin/bash

set -e  # Exit on any error

# Auto-detect project directory (where this script is located)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Starting enhanced GERP annotation with parallel processing..."

head -1 final_annotated.txt > header
awk '{print $0 "\tchr_gerp\tstart_gerp\tend_gerp\tgerp_score"}' header > head && mv head header

# split the TR file into separate files for each chromosome
echo "Splitting TR file by chromosome..."
"$PROJECT_DIR/helper_scripts/split_bed.sh" final_annotated.txt
mkdir -p intersections
mkdir -p gerp_annotated

# Check if GNU parallel is available
if command -v parallel >/dev/null 2>&1; then
    echo "Using GNU parallel for enhanced parallelization..."
    USE_PARALLEL=true
    # Use configured CPU cores (from rexprt_config.yml)
    if [ -n "${MAX_CPU_CORES:-}" ]; then
        PARALLEL_JOBS=$MAX_CPU_CORES
    else
        # Fallback to system detection
        CPU_CORES=$(nproc 2>/dev/null || echo 4)
        PARALLEL_JOBS=$CPU_CORES
    fi
    echo "Using $PARALLEL_JOBS parallel jobs"
else
    echo "GNU parallel not available, using standard background jobs..."
    USE_PARALLEL=false
fi

# intersect the TR file with the gerp files to add the gerp scores for each bp position of the repeat region
echo "Intersecting TRs with GERP files..."
if [ "$USE_PARALLEL" = true ]; then
    # Use GNU parallel for better load balancing
    cat list.txt | parallel --no-notice --progress -j $PARALLEL_JOBS \
        "$PROJECT_DIR/data/bedtools.static.binary intersect -a repeats_by_chrom/{}.bed.gz -b $PROJECT_DIR/data/gerp_files/{}_gerp.bed.gz -sorted -wb > intersections/{}.intersection"
else
    # Use traditional background jobs
    while read chr; do
        "$PROJECT_DIR/data/bedtools.static.binary" intersect -a repeats_by_chrom/$chr.bed.gz -b "$PROJECT_DIR/data/gerp_files/${chr}_gerp.bed.gz" -sorted -wb > intersections/$chr.intersection &
    done < list.txt
    wait
fi

# add the header to the resulting file
echo "Adding headers to intersection files..."
if [ "$USE_PARALLEL" = true ]; then
    cat list.txt | parallel --no-notice -j $PARALLEL_JOBS \
        'cat header intersections/{}.intersection > intersections/del_{}.intersection && mv intersections/del_{}.intersection intersections/{}.intersection'
else
    while read chr; do
        cat header intersections/$chr.intersection > intersections/del_$chr.intersection && mv intersections/del_$chr.intersection intersections/$chr.intersection &
    done < list.txt
    wait
fi

# calculate the mean gerp score for each TR (since we get separate scores for each bp position)
echo "Calculating mean GERP scores..."
if [ "$USE_PARALLEL" = true ]; then
    cat list.txt | parallel --no-notice --progress -j $PARALLEL_JOBS \
        "Rscript --vanilla $PROJECT_DIR/helper_scripts/calc_gerp.R intersections/{}.intersection"
else
    while read chr; do
        Rscript --vanilla "$PROJECT_DIR/helper_scripts/calc_gerp.R" intersections/$chr.intersection &
    done < list.txt
    wait
fi

# combine the TRs annotated with gerp scores into a single file
echo "Combining GERP annotations..."
echo -e "chr\tid\tgerp" > header
cat header gerp_annotated/* > combined_gerp.txt
Rscript --vanilla "$PROJECT_DIR/helper_scripts/merge_data.R" combined_gerp.txt final_annotated.txt

echo "GERP annotation completed successfully!"
