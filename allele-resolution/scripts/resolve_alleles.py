
#!/usr/bin/env python3
import argparse
import logging
import os
import sys

import pysam
from rich.progress import track

EXPECTED_HEADER = ["#CHROM", "POS", "ID", "allele1", "allele2"]
OUTPUT_HEADER = ["#CHROM", "POS", "ID", "REF", "ALT"]
VALID_CHROMS = {f"chr{i}" for i in range(1, 23)} | {"chrX", "chrY", "chrM"}
COMPLEMENT = {"A": "T", "T": "A", "C": "G", "G": "C"}


def parse_arguments():
    parser = argparse.ArgumentParser(description="Determine REF and ALT alleles using a reference genome.")
    parser.add_argument("-i", "--input", required=True, help="Input TSV file")
    parser.add_argument("-o", "--output", required=True, help="Output TSV file")
    parser.add_argument("-r", "--reference-dir", required=True, help="Directory containing chromosome FASTA files")
    parser.add_argument("-l", "--log", default="FP_SNPs_conversion.log", help="Log file")
    parser.add_argument("--skip-invalid", action="store_true", help="Skip invalid lines instead of stopping")
    return parser.parse_args()


def setup_logging(log_file):
    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s",
                        handlers=[logging.FileHandler(log_file, mode="w"), logging.StreamHandler(sys.stdout)])


def handle_wrong_line(message, skip_invalid, warnings):
    if not skip_invalid:
        raise ValueError(message)
    warnings.append(message)

def check_header(header):
    if header.rstrip("\r\n").split("\t") != EXPECTED_HEADER:
        raise ValueError(f"Invalid input header. Expected: {' '.join(EXPECTED_HEADER)}; found: {header.strip()}")


def validate_line(line, line_number):
    columns = line.rstrip("\r\n").split("\t")
    if len(columns) != 5:
        raise ValueError(f"Invalid number of columns at line {line_number}: expected 5, found {len(columns)}")
    chrom, pos_string, snp_id, allele1, allele2 = columns
    allele1, allele2 = allele1.upper(), allele2.upper()
    if chrom not in VALID_CHROMS:
        raise ValueError(f"Invalid chromosome at line {line_number}: {chrom}")
    try:
        pos = int(pos_string)
    except ValueError:
        raise ValueError(f"Invalid position at line {line_number}: {pos_string}") from None
    if pos < 1:
        raise ValueError(f"Position must be >= 1 at line {line_number}: {pos}")
    if not allele1 or not allele2 or any(base not in COMPLEMENT for base in allele1 + allele2) or allele1 == allele2:
        raise ValueError(f"Invalid alleles at line {line_number}: {allele1}/{allele2}")
    return chrom, pos, snp_id, allele1, allele2


def get_fasta(chrom, reference_dir, fasta_files):
    if chrom not in fasta_files:
        path = os.path.join(reference_dir, f"{chrom}.fa")
        if not os.path.isfile(path) or not os.path.isfile(path + ".fai"):
            raise FileNotFoundError(f"Reference FASTA or index not found: {path}")
        fasta_files[chrom] = pysam.Fastafile(path)
    return fasta_files[chrom]


# Main function to process file
def process_variants(args):
    fasta_files = {}
    warnings = {"flipped": [], "unknown": [], "wrong": []}
    counts = {"total": 0, "converted": 0, "flipped": 0, "unknown": 0, "wrong": 0}

    try:
        with open(args.input) as infile:
            number_of_variants = max(sum(1 for _ in infile) - 1, 0)

        with open(args.input) as infile:
            header = infile.readline()
            if not header:
                raise ValueError("Input file is empty")
            check_header(header)

            with open(args.output, "w") as outfile:
                outfile.write("\t".join(OUTPUT_HEADER) + "\n")

                for line_number, line in enumerate(track(infile, total=number_of_variants, description="Processing variants"), start=2):
                    if not line.strip():
                        continue

                    try:
                        chrom, pos, snp_id, allele1, allele2 = validate_line(line, line_number)
                        fasta = get_fasta(chrom, args.reference_dir, fasta_files)
                        ref_base = fasta.fetch(chrom, pos - 1, pos).upper()
                        if len(ref_base) != 1:
                            raise ValueError(f"Position outside chromosome at line {line_number}: {chrom}:{pos}")
                    except (ValueError, KeyError) as error:
                        counts["wrong"] += 1
                        handle_wrong_line(str(error), args.skip_invalid, warnings["wrong"])
                        continue

                    counts["total"] += 1
                    if ref_base in (allele1, allele2):
                        # good variant, resolve alleles and write it to the output file
                        alt = allele2 if ref_base == allele1 else allele1
                        outfile.write(f"{chrom}\t{pos}\t{snp_id}\t{ref_base}\t{alt}\n")
                        counts["converted"] += 1
                    else:
                        # ref_base not in (allele1, allele2) - we can't convert variant.
                        # But we can suggest if it's strand-flipped and mark such variants in log.
                        # Otherwise, mark variant as 'unresolved' with unknown reason
                        comp1 = "".join(COMPLEMENT[b] for b in allele1)
                        comp2 = "".join(COMPLEMENT[b] for b in allele2)
                        category = "flipped" if ref_base in (comp1, comp2) else "unknown"
                        counts[category] += 1
                        warnings[category].append(f"{chrom}:{pos} {snp_id} allele1={allele1} allele2={allele2} reference={ref_base}")
    finally:
        for fasta in fasta_files.values():
            fasta.close()

    for category, label in [("flipped", "Not recognized (probably strand-flipped)"),
                            ("unknown", "Not recognized (unknown reason)"),
                            ("wrong", "Wrong line skipped")]:
        for message in warnings[category]:
            logging.warning("%s: %s", label, message)

    return counts


def main():
    args = parse_arguments()
    setup_logging(args.log)
    logging.info("Starting allele conversion")
    logging.info("Input: %s; Output: %s; Reference: %s", args.input, args.output, args.reference_dir)

    try:
        if not os.path.isfile(args.input):
            raise FileNotFoundError(f"Input file does not exist: {args.input}")
        if not os.path.isdir(args.reference_dir):
            raise FileNotFoundError(f"Reference directory does not exist: {args.reference_dir}")
        counts = process_variants(args)
    except (FileNotFoundError, ValueError, OSError, pysam.PysamError) as error:
        logging.error("%s", error)
        sys.exit(1)

    logging.info("Conversion finished")
    for key, label in [("total", "Total valid variants"),
                       ("converted", "Converted variants"),
                       ("flipped", "Not recognized (probably strand-flipped)"),
                       ("unknown", "Not recognized (unknown reason)"), ("wrong", "Wrong lines")]:
        logging.info("%s: %d", label, counts[key])


if __name__ == "__main__":
    main()

