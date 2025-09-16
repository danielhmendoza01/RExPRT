#!/bin/bash
set -eou pipefail

# Parse command line arguments
CONFIG_FILE="rexprt_config.yml"
INPUT_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        -h|--help)
            echo "    RExPRT is a machine learning tool to predict tandem repeat pathogenicity

    Usage: To run RExPRT use the following command:
        ./RExPRT.sh [OPTIONS] TRfile.txt
    TR file should have 5 columns labelled: chr, start, end, motif, and sampleID

    Options:
        -c, --config FILE    Specify custom configuration file (default: rexprt_config.yml)
        -h, --help          Show this help message

    Example of a test file input is located in ./example/input/
    Example of test output files are in ./example/output/

    For full documentation and detailed instructions visit https://github.com/ZuchnerLab/RExPRT

    Configuration: Edit rexprt_config.yml to customize performance settings"
            exit 0
            ;;
        *)
            INPUT_FILE="$1"
            shift
            ;;
    esac
done

# Load configuration file
if [ -f "$CONFIG_FILE" ]; then
    echo "Loading RExPRT configuration from $CONFIG_FILE..."
    eval "$(python3 helper_scripts/parse_config.py "$CONFIG_FILE")"
else
    echo "Error: Configuration file '$CONFIG_FILE' not found!"
    echo "Please ensure rexprt_config.yml exists or specify a custom config with -c option."
    echo "Run '$0 --help' for usage information."
    exit 1
fi

# Function to log messages
log_message() {
    local message="$1"
    if [ "$ENABLE_LOGGING" = true ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" >> "$LOG_FILE"
    fi
    if [ "$VERBOSE_PROGRESS" = true ]; then
        echo "$message"
    fi
}

# Function to time operations
start_timer() {
    if [ "$ENABLE_TIMING" = true ]; then
        START_TIME=$(date +%s)
        log_message "Started: $1"
    fi
}

end_timer() {
    if [ "$ENABLE_TIMING" = true ]; then
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        log_message "Completed: $1 (Duration: ${DURATION}s)"
    fi
}

log_message "=== RExPRT Pipeline Started ==="

if [ -z "$INPUT_FILE" ]; then
    echo "Error: No input file provided!"
    echo "Usage: $0 [OPTIONS] TRfile.txt"
    echo "Run '$0 --help' for more information."
    exit 1
fi

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file '$INPUT_FILE' not found!"
    exit 1
fi

# Create temporary directory if configured
if [ -n "$TEMP_DIR" ] && [ "$TEMP_DIR" != "./tmp" ]; then
    mkdir -p "$TEMP_DIR"
    export TMPDIR="$TEMP_DIR"
fi

#Download Annotation files
if [ ! -d "./annotation_files" ]
then
    wget -qO- https://zuchnerlab.s3.amazonaws.com/RExPRT_public/annotation_files.tar.gz | tar xvz
fi

#Download GERP files
if [ ! -d "./gerp_files" ]
then
    wget -qO- https://zuchnerlab.s3.amazonaws.com/RExPRT_public/gerp_files.tar.gz | tar xvz
fi

#Download ML models
if [ ! -f "SVM.pckl" ]
then
    wget https://zuchnerlab.s3.amazonaws.com/RExPRT_public/SVM.pckl
fi

if [ ! -f "XGB.pckl" ]
then
    wget https://zuchnerlab.s3.amazonaws.com/RExPRT_public/XGB.pckl
fi

# download bedtools
if [ ! -f "bedtools.static.binary" ]
then
    wget -q https://github.com/arq5x/bedtools2/releases/download/v2.29.2/bedtools.static.binary
    chmod u+x bedtools.static.binary
fi

# Annotate variants
repeats=$INPUT_FILE

head -1 "$INPUT_FILE" > header
tail -n +2 "$INPUT_FILE" > repeats
./bedtools.static.binary sort -i repeats > del && mv del repeats
cat header repeats > sorted_repeats


start_timer "Exon and Intron annotation"
log_message "Annotating Exon and Intron"
head -q -n 1 sorted_repeats annotation_files/Exons_and_introns_UCSC.sorted.bed | paste -sd "\t" > header
awk '{print $0 "\tgene_distance"}' header > head && mv head header
sed 's/#//g' header > changed.txt && mv changed.txt header
./bedtools.static.binary closest -a sorted_repeats -b annotation_files/Exons_and_introns_UCSC.sorted.bed -d > intersection
Rscript --vanilla helper_scripts/exon_intron_ann.R intersection header annotation_files/UCSC_canonical.txt
log_message "Finished Exon Intron annotation"
end_timer "Exon and Intron annotation"

chmod u+x helper_scripts/gerp_ann.sh
chmod u+x helper_scripts/split_bed.sh
start_timer "GERP annotation"
log_message "Annotating gerp scores"
awk '{print $1}' sorted_repeats | uniq | grep -wv "chr" > list.txt
time ./helper_scripts/gerp_ann.sh
log_message "Finished annotating gerp scores"
end_timer "GERP annotation"


echo "Annotating genomic features..."

# Check if we should use parallel bedtools
if command -v parallel >/dev/null 2>&1 && [ -f "helper_scripts/parallel_bedtools.sh" ]; then
    echo "Using parallel bedtools for enhanced performance..."

    # Run parallel bedtools operations
    chmod +x helper_scripts/parallel_bedtools.sh
    ./helper_scripts/parallel_bedtools.sh final_annotated.txt

    # Copy result back
    if [ -f "final_annotated_parallel.txt" ]; then
        mv final_annotated_parallel.txt final_annotated.txt
        echo "Parallel bedtools operations completed"
    else
        echo "Parallel bedtools failed, falling back to sequential..."
    fi
fi

# Fallback to sequential operations if parallel failed or not available
if [ ! -f "final_annotated_parallel.txt" ]; then
    echo "Using sequential bedtools operations..."

    echo "Annotating TAD boundaries"
    head -1 final_annotated.txt > header
    awk '{print $0 "\tTAD"}' header > head && mv head header
    ./bedtools.static.binary intersect -a final_annotated.txt -b annotation_files/TADboundaries_CpGcount.bed -c > intersection
    cat header intersection > final_annotated.txt
    echo "Finished annotating TAD boundaries"

    echo "Annotating eSTR"
    head -1 final_annotated.txt > header
    awk '{print $0 "\teSTR"}' header > head && mv head header
    ./bedtools.static.binary intersect -a final_annotated.txt -b annotation_files/eSTR_loci_hg19.sorted.bed -c > intersection
    cat header intersection > final_annotated.txt
    echo "Finished annotating eSTR"

    echo "Annotating opRegRegions"
    head -1 final_annotated.txt > header
    awk '{print $0 "\topReg"}' header > head && mv head header
    ./bedtools.static.binary intersect -a final_annotated.txt -b annotation_files/openRegulatoryRegions_hg19.sorted.bed -c > intersection
    cat header intersection > final_annotated.txt
    echo "Finished annotating opRegRegions"

    echo "Annotating promoter regions"
    head -1 final_annotated.txt > header
    awk '{print $0 "\tpromoter"}' header > head && mv head header
    ./bedtools.static.binary intersect -a final_annotated.txt -b annotation_files/promoters.sorted.bed -c > intersection
    cat header intersection > final_annotated.txt
    echo "Finished annotating promoter regions"
fi

echo "Annotating GTEx"
Rscript --vanilla helper_scripts/gtex_ann.R final_annotated.txt annotation_files/max_tissueExpression_perGene.txt
echo "Finished annotating GTEX"

echo "Annotating 3'UTR"
head -1 final_annotated.txt > header
awk '{print $0 "\tUTR_3"}' header > head && mv head header
./bedtools.static.binary intersect -a final_annotated.txt -b annotation_files/3primeUTR.sorted.bed -c > intersection
cat header intersection > final_annotated.txt
echo "Finished annotating 3'UTR"

echo "Annotating 5'UTR"
head -1 final_annotated.txt > header
awk '{print $0 "\tUTR_5"}' header > head && mv head header
./bedtools.static.binary intersect -a final_annotated.txt -b annotation_files/5primeUTR.sorted.bed -c > intersection
cat header intersection > final_annotated.txt
echo "Finished annotating 5'UTR"

echo "Annotating pLi and loeuf scores"
head -1 final_annotated.txt > header
awk '{print $0 "\tchrom\tcstart\tcend\tloeuf\tpLi"}' header > head && mv head header
./bedtools.static.binary intersect -a final_annotated.txt -b annotation_files/pLI_scores_hg19.sorted.bed -loj > intersection
cat header intersection > final_annotated.txt
Rscript --vanilla helper_scripts/pLi_ann.R final_annotated.txt
echo "Finished annotating pLi and loeuf scores"

echo "Annotating RAD21 binding sites"
head -1 final_annotated.txt > header
awk '{print $0 "\tRAD21"}' header > head && mv head header
cut -f2- annotation_files/NeuralCell_RAD21bindingSites_hg19.txt > file
./bedtools.static.binary intersect -a final_annotated.txt -b file -c > intersection
cat header intersection > final_annotated.txt
echo "Finished annotating RAD21"

echo "Annotating SMC3"
head -1 final_annotated.txt > header
awk '{print $0 "\tSMC3"}' header > head && mv head header
cut -f2- annotation_files/NeuralCell_SMC3bindingSites_hg19.txt > file
./bedtools.static.binary intersect -a final_annotated.txt -b file -c > intersection
cat header intersection > final_annotated.txt
echo "Finished annotating SMC3"

echo "Annotating percent GC"
Rscript --vanilla helper_scripts/perGC.R final_annotated.txt
echo "Finished Annotating percent GC"

start_timer "S2S annotation"
log_message "Adding S2S annotations"
pip install numpy --quiet
Rscript --vanilla helper_scripts/create_S2S_files.R final_annotated.txt
(cd S2SNet || exit 1; python S2SNet_noGUI_emb_py3_repeats.py) > text_delete
cut --complement -d$'\t' -f1,2,3 S2SNet/S2SNetTIs_Emb.txt > values
paste final_annotated.txt values > combined && mv combined final_annotated.txt
log_message "Finished annotating S2S markers"
end_timer "S2S annotation"

start_timer "Data formatting"
log_message "Converting columns into binary"
Rscript --vanilla helper_scripts/convert_cols_binary.R final_annotated.txt
log_message "Finished converting columns into binary"

log_message "Formatting for machine learning"
Rscript helper_scripts/format_final_annotated.R final_annotated.txt
log_message "Data formatting completed"
end_timer "Data formatting"

start_timer "Cleanup"
log_message "Cleaning up temporary files..."
rm -f repeats file header intersection text_delete values list.txt
rm -rf repeats_by_chrom intersections gerp_annotated/ combined_gerp.txt sorted_repeats
log_message "Cleanup completed"
end_timer "Cleanup"

#Use ML models to score annotated repeats
start_timer "ML prediction"
log_message "Running ML prediction models..."
pip install scikit-learn==1.1.3 -q
pip install xgboost -q
pip install category_encoders -q

python3 helper_scripts/rexprt.py
log_message "ML prediction completed"
end_timer "ML prediction"

start_timer "Post-processing"
log_message "Post-processing results..."
Rscript --vanilla helper_scripts/remove_duplicates.R TRsAnnotated_RExPRTscoresDups.txt RExPRT_scoresDups.txt

base=$(basename "$repeats")
filename="${base%.*}"
mv TRsAnnotated_RExPRTscores.txt ${filename}_TRsAnnotated_RExPRTscores.txt
mv RExPRTscores.txt ${filename}_RExPRTscores.txt
rm -f final_annotated.txt TRsAnnotated_RExPRTscoresDups.txt RExPRT_scoresDups.txt
log_message "Post-processing completed"
end_timer "Post-processing"

log_message "=== RExPRT Pipeline Completed Successfully! ==="
log_message "Output files: ${filename}_TRsAnnotated_RExPRTscores.txt, ${filename}_RExPRTscores.txt"
