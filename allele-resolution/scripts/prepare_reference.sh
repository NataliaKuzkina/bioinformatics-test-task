#!/usr/bin/env bash
set -euo pipefail

REF_DIR="${1:-./reference/GRCh38.d1.vd1_mainChr}"
ARCHIVE="GRCh38.d1.vd1.fa.tar.gz"
FASTA="GRCh38.d1.vd1.fa"

mkdir -p "${REF_DIR}"
cd "${REF_DIR}"

# Download GRCh38.d1.vd1 reference genome from GDC
if [[ ! -f "$ARCHIVE" ]]; then
    echo "Downloading GRCh38.d1.vd1 reference genome..."
    wget -O "$ARCHIVE" "https://api.gdc.cancer.gov/data/254f697d-310d-4d7d-a27b-27fbf767a834"
else
    echo "$ARCHIVE already exists, skipping download."
fi

# Extract reference
tar -xzf "${ARCHIVE}"

# Index complete reference
samtools faidx "${FASTA}"

# Create chromosome directory
mkdir -p sepChrs

# Extract chr1-22, chrX, chrY and chrM
for chr in {1..22} X Y M; do
    samtools faidx "${FASTA}" "chr${chr}" > "sepChrs/chr${chr}.fa"
done

# Index individual chromosome FASTA files
for fasta in sepChrs/*.fa; do
    samtools faidx "${fasta}"
done

# Check result
echo "FASTA files:"
find sepChrs -name '*.fa' | wc -l

echo "FASTA indexes:"
find sepChrs -name '*.fa.fai' | wc -l
