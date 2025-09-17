#!/bin/bash
set -eou pipefail

# Auto-detect project directory (handles symlinks correctly)
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Parse command line arguments
CONFIG_FILE=""
INPUT_FILE=""

# Determine config file location (current dir first, then project dir)
if [ -f "rexprt_config.yml" ]; then
    CONFIG_FILE="rexprt_config.yml"
elif [ -f "$PROJECT_DIR/rexprt_config.yml" ]; then
    CONFIG_FILE="$PROJECT_DIR/rexprt_config.yml"
else
    CONFIG_FILE="rexprt_config.yml"  # Default, will show error later
fi

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
    eval "$(python3 "$PROJECT_DIR/helper_scripts/parse_config.py" "$CONFIG_FILE")"
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

# Create data directory if it doesn't exist
mkdir -p data

# Create temporary directory if configured
if [ -n "$TEMP_DIR" ] && [ "$TEMP_DIR" != "./tmp" ]; then
    mkdir -p "$TEMP_DIR"
    export TMPDIR="$TEMP_DIR"
fi

#Download Annotation files
if [ -d "$PROJECT_DIR/data/annotation_files" ]; then
    echo "Using existing annotation files from project directory..."
    mkdir -p data
    ln -sf "$PROJECT_DIR/data/annotation_files" "data/annotation_files" 2>/dev/null || \
    cp -r "$PROJECT_DIR/data/annotation_files" "data/annotation_files"
elif [ ! -d "data/annotation_files" ]; then
    echo "Downloading annotation files..."
    mkdir -p data
    wget -qO- https://zuchnerlab.s3.amazonaws.com/RExPRT_public/annotation_files.tar.gz | tar xvz -C data/
fi

#Download GERP files
if [ -d "$PROJECT_DIR/data/gerp_files" ]; then
    echo "Using existing GERP files from project directory..."
    mkdir -p data
    ln -sf "$PROJECT_DIR/data/gerp_files" "data/gerp_files" 2>/dev/null || \
    cp -r "$PROJECT_DIR/data/gerp_files" "data/gerp_files"
elif [ ! -d "data/gerp_files" ]; then
    echo "Downloading GERP files..."
    mkdir -p data
    wget -qO- https://zuchnerlab.s3.amazonaws.com/RExPRT_public/gerp_files.tar.gz | tar xvz -C data/
fi

#Download ML models
if [ -f "$PROJECT_DIR/data/SVM.pckl" ]; then
    echo "Using existing SVM model from project directory..."
    mkdir -p data
    ln -sf "$PROJECT_DIR/data/SVM.pckl" "data/SVM.pckl" 2>/dev/null || \
    cp "$PROJECT_DIR/data/SVM.pckl" "data/SVM.pckl"
elif [ ! -f "data/SVM.pckl" ]; then
    echo "Downloading SVM model..."
    mkdir -p data
    wget -q https://zuchnerlab.s3.amazonaws.com/RExPRT_public/SVM.pckl -P data/
fi

if [ -f "$PROJECT_DIR/data/XGB.pckl" ]; then
    echo "Using existing XGB model from project directory..."
    mkdir -p data
    ln -sf "$PROJECT_DIR/data/XGB.pckl" "data/XGB.pckl" 2>/dev/null || \
    cp "$PROJECT_DIR/data/XGB.pckl" "data/XGB.pckl"
elif [ ! -f "data/XGB.pckl" ]; then
    echo "Downloading XGB model..."
    mkdir -p data
    wget -q https://zuchnerlab.s3.amazonaws.com/RExPRT_public/XGB.pckl -P data/
fi

# download bedtools
if [ -f "$PROJECT_DIR/data/bedtools.static.binary" ]; then
    echo "Using existing bedtools from project directory..."
    mkdir -p data
    ln -sf "$PROJECT_DIR/data/bedtools.static.binary" "data/bedtools.static.binary" 2>/dev/null || \
    cp "$PROJECT_DIR/data/bedtools.static.binary" "data/bedtools.static.binary"
    chmod u+x data/bedtools.static.binary
elif [ ! -f "data/bedtools.static.binary" ]; then
    echo "Downloading bedtools..."
    mkdir -p data
    wget -q https://github.com/arq5x/bedtools2/releases/download/v2.29.2/bedtools.static.binary -P data/
    chmod u+x data/bedtools.static.binary
fi

# Annotate variants
repeats=$INPUT_FILE

head -1 "$INPUT_FILE" > header
tail -n +2 "$INPUT_FILE" > repeats
./data/bedtools.static.binary sort -i repeats > del && mv del repeats
cat header repeats > sorted_repeats


start_timer "Exon and Intron annotation"
log_message "Annotating Exon and Intron"
head -q -n 1 sorted_repeats data/annotation_files/Exons_and_introns_UCSC.sorted.bed | paste -sd "\t" > header
awk '{print $0 "\tgene_distance"}' header > head && mv head header
sed 's/#//g' header > changed.txt && mv changed.txt header
./data/bedtools.static.binary closest -a sorted_repeats -b data/annotation_files/Exons_and_introns_UCSC.sorted.bed -d > intersection
Rscript --vanilla "$PROJECT_DIR/helper_scripts/exon_intron_ann.R" intersection header data/annotation_files/UCSC_canonical.txt
log_message "Finished Exon Intron annotation"
end_timer "Exon and Intron annotation"

start_timer "GERP annotation"
log_message "Annotating gerp scores"
awk '{print $1}' sorted_repeats | uniq | grep -wv "chr" > list.txt
time "$PROJECT_DIR/helper_scripts/gerp_ann.sh"
log_message "Finished annotating gerp scores"
end_timer "GERP annotation"


echo "Annotating genomic features..."

# Check if we should use parallel bedtools
if command -v parallel >/dev/null 2>&1 && [ -f "$PROJECT_DIR/helper_scripts/parallel_bedtools.sh" ]; then
    "$PROJECT_DIR/helper_scripts/parallel_bedtools.sh" final_annotated.txt
    if [ -f "final_annotated_parallel.txt" ]; then
        mv final_annotated_parallel.txt final_annotated.txt
    fi
fi

# Fallback to sequential operations if parallel failed or not available
if [ ! -f "final_annotated_parallel.txt" ]; then

    echo "Annotating TAD boundaries"
    head -1 final_annotated.txt > header
    awk '{print $0 "\tTAD"}' header > head && mv head header
    ./data/bedtools.static.binary intersect -a final_annotated.txt -b data/annotation_files/TADboundaries_CpGcount.bed -c > intersection
    cat header intersection > final_annotated.txt
    echo "Finished annotating TAD boundaries"

    echo "Annotating eSTR"
    head -1 final_annotated.txt > header
    awk '{print $0 "\teSTR"}' header > head && mv head header
    ./data/bedtools.static.binary intersect -a final_annotated.txt -b data/annotation_files/eSTR_loci_hg19.sorted.bed -c > intersection
    cat header intersection > final_annotated.txt
    echo "Finished annotating eSTR"

    echo "Annotating opRegRegions"
    head -1 final_annotated.txt > header
    awk '{print $0 "\topReg"}' header > head && mv head header
    ./data/bedtools.static.binary intersect -a final_annotated.txt -b data/annotation_files/openRegulatoryRegions_hg19.sorted.bed -c > intersection
    cat header intersection > final_annotated.txt
    echo "Finished annotating opRegRegions"

    echo "Annotating promoter regions"
    head -1 final_annotated.txt > header
    awk '{print $0 "\tpromoter"}' header > head && mv head header
    ./data/bedtools.static.binary intersect -a final_annotated.txt -b data/annotation_files/promoters.sorted.bed -c > intersection
    cat header intersection > final_annotated.txt
    echo "Finished annotating promoter regions"
fi

echo "Annotating GTEx"
Rscript --vanilla "$PROJECT_DIR/helper_scripts/gtex_ann.R" final_annotated.txt data/annotation_files/max_tissueExpression_perGene.txt final_annotated.txt
echo "Finished annotating GTEX"

echo "Annotating 3'UTR"
head -1 final_annotated.txt > header
awk '{print $0 "\tUTR_3"}' header > head && mv head header
./data/bedtools.static.binary intersect -a final_annotated.txt -b data/annotation_files/3primeUTR.sorted.bed -c > intersection
cat header intersection > final_annotated.txt
echo "Finished annotating 3'UTR"

echo "Annotating 5'UTR"
head -1 final_annotated.txt > header
awk '{print $0 "\tUTR_5"}' header > head && mv head header
./data/bedtools.static.binary intersect -a final_annotated.txt -b data/annotation_files/5primeUTR.sorted.bed -c > intersection
cat header intersection > final_annotated.txt
echo "Finished annotating 5'UTR"

echo "Annotating pLi and loeuf scores"
head -1 final_annotated.txt > header
awk '{print $0 "\tchrom\tcstart\tcend\tloeuf\tpLi"}' header > head && mv head header
./data/bedtools.static.binary intersect -a final_annotated.txt -b data/annotation_files/pLI_scores_hg19.sorted.bed -loj > intersection
cat header intersection > final_annotated.txt
Rscript --vanilla "$PROJECT_DIR/helper_scripts/pLi_ann.R" final_annotated.txt
echo "Finished annotating pLi and loeuf scores"

echo "Annotating RAD21 binding sites"
head -1 final_annotated.txt > header
awk '{print $0 "\tRAD21"}' header > head && mv head header
cut -f2- data/annotation_files/NeuralCell_RAD21bindingSites_hg19.txt > file
./data/bedtools.static.binary intersect -a final_annotated.txt -b file -c > intersection
cat header intersection > final_annotated.txt
echo "Finished annotating RAD21"

echo "Annotating SMC3"
head -1 final_annotated.txt > header
awk '{print $0 "\tSMC3"}' header > head && mv head header
cut -f2- data/annotation_files/NeuralCell_SMC3bindingSites_hg19.txt > file
./data/bedtools.static.binary intersect -a final_annotated.txt -b file -c > intersection
cat header intersection > final_annotated.txt
echo "Finished annotating SMC3"

echo "Annotating percent GC"
Rscript --vanilla "$PROJECT_DIR/helper_scripts/perGC.R" final_annotated.txt final_annotated.txt
echo "Finished Annotating percent GC"

start_timer "S2S annotation"
log_message "Adding S2S annotations"
Rscript --vanilla "$PROJECT_DIR/helper_scripts/create_S2S_files.R" final_annotated.txt "$PROJECT_DIR"
(cd "$PROJECT_DIR/S2SNet" || exit 1; python S2SNet_noGUI_emb_py3_repeats.py) > text_delete
cut --complement -d$'\t' -f1,2,3 "$PROJECT_DIR/S2SNet/S2SNetTIs_Emb.txt" > values
paste final_annotated.txt values > combined && mv combined final_annotated.txt
log_message "Finished annotating S2S markers"
end_timer "S2S annotation"

start_timer "Data formatting"
log_message "Converting columns into binary"
Rscript --vanilla "$PROJECT_DIR/helper_scripts/convert_cols_binary.R" final_annotated.txt final_annotated.txt
log_message "Finished converting columns into binary"

log_message "Formatting for machine learning"
Rscript "$PROJECT_DIR/helper_scripts/format_final_annotated.R" final_annotated.txt
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
python3 "$PROJECT_DIR/helper_scripts/rexprt.py"
log_message "ML prediction completed"
end_timer "ML prediction"

start_timer "Post-processing"
log_message "Post-processing results..."
Rscript --vanilla "$PROJECT_DIR/helper_scripts/remove_duplicates.R" TRsAnnotated_RExPRTscoresDups.txt RExPRT_scoresDups.txt

base=$(basename "$repeats")
filename="${base%.*}"
mv TRsAnnotated_RExPRTscores.txt ${filename}_TRsAnnotated_RExPRTscores.txt
mv RExPRTscores.txt ${filename}_RExPRTscores.txt
rm -f final_annotated.txt TRsAnnotated_RExPRTscoresDups.txt RExPRT_scoresDups.txt
log_message "Post-processing completed"
end_timer "Post-processing"

log_message "=== RExPRT Pipeline Completed Successfully! ==="
log_message "Output files: ${filename}_TRsAnnotated_RExPRTscores.txt, ${filename}_RExPRTscores.txt"
