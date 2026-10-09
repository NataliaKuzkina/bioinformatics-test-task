#!/usr/bin/env bash
set -euo pipefail

DBSNP="${1:-GCF_000001405.40.gz}"
RS_LIST="${2:-strand_flip_rs.txt}"

if [[ ! -f "$DBSNP" ]]; then
    echo "ERROR: dbSNP VCF not found: $DBSNP" >&2
    exit 1
fi

if [[ ! -f "$RS_LIST" ]]; then
    echo "ERROR: rsID list not found: $RS_LIST" >&2
    exit 1
fi

echo -e "CHROM\tPOS\tID\tREF\tALT"

while read -r rs; do
    [[ -z "$rs" ]] && continue

    bcftools query \
        -i "ID=\"$rs\"" \
        -f '%CHROM\t%POS\t%ID\t%REF\t%ALT\n' \
        "$DBSNP"
done < "$RS_LIST"
