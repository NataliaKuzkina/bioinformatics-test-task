#!/usr/bin/env bash
set -euo pipefail

URL="https://www.ncbi.nlm.nih.gov/projects/gap/cgi-bin/GetZip.cgi?zip_name=GRAF_files.zip"

ARCHIVE="GRAF_files.tar.gz"
SNP_FILE="FP_SNPs.txt"
OUTPUT="FP_SNPs_10k_GB38_twoAllelsFormat.tsv"

# Download GRAF 2.4 archive
if [[ ! -f "$ARCHIVE" ]]; then
    echo "Downloading GRAF files..."
    curl -L "$URL" -o "$ARCHIVE"
    echo "Downloaded: $ARCHIVE"
else
    echo "$ARCHIVE already exists, skipping download."
fi

# Extract FP_SNPs.txt
if [[ ! -f "$SNP_FILE" ]]; then
    echo "Extracting $SNP_FILE..."
    tar -xzf "$ARCHIVE" data/FP_SNPs.txt
    mv data/FP_SNPs.txt "$SNP_FILE"
    rmdir data
    echo "Extracted: $SNP_FILE"
else
    echo "$SNP_FILE already exists, skipping extraction."
fi

# Convert FP_SNPs.txt to:
# #CHROM  POS  ID  allele1  allele2
#
# - use GRCh38 coordinates
# - add chr prefix
# - add rs prefix
# - remove chromosome 23 (X chromosome)

echo "Preprocessing $SNP_FILE..."

awk 'BEGIN {OFS="\t"}
NR==1 {
    print "#CHROM", "POS", "ID", "allele1", "allele2"
    next
}
$2 != 23 {
    print "chr"$2, $4, "rs"$1, $5, $6
}' "$SNP_FILE" > "$OUTPUT"

echo "Created: $OUTPUT"
wc -l "$OUTPUT"
