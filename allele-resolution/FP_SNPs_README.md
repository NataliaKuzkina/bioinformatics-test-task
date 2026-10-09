# FP SNP REF/ALT Resolution

This directory contains scripts used to preprocess the GRAF 2.4 fingerprinting SNP set and resolve REF/ALT alleles against the GRCh38 reference genome.

## Files

- `scripts/download_snps.sh` — downloads the GRAF 2.4 archive, extracts `FP_SNPs.txt`, and converts it to the input format required by the Python script.
- `scripts/prepare_reference.sh` — downloads and prepares the GRCh38.d1.vd1 reference genome.
- `resolve_alleles.py` — determines REF and ALT alleles by comparing the input alleles with the GRCh38 reference sequence.
- `FP_SNPs_10k_GB38_twoAllelsFormat.tsv` — preprocessed SNP input.
- `FP_SNPs_10k_GB38_REF_ALT.tsv` — output produced by `resolve_alleles.py`.

## 1. Download and preprocess GRAF SNPs

Run:

```bash
./scripts/download_snps.sh
```

The script downloads the GRAF 2.4 archive and extracts:

```text
FP_SNPs.txt
```

The original GRAF file contains both GRCh37 and GRCh38 coordinates. The preprocessing step uses the GRCh38 coordinates and converts the data to the following format:

```text
#CHROM    POS    ID    allele1    allele2
```

The preprocessing also:

- adds the `chr` prefix to chromosome names;
- adds the `rs` prefix to SNP identifiers;
- removes chromosome 23 (X chromosome), leaving the 10,000 autosomal fingerprinting SNPs.

The resulting file is:

```text
FP_SNPs_10k_GB38_twoAllelsFormat.tsv
```

It contains 10,000 variants plus the header.

## 2. Prepare the GRCh38 reference

Run:

```bash
./scripts/prepare_reference.sh
```

By default, the reference is stored under:

```text
./reference/GRCh38.d1.vd1_mainChr/
```

A different directory can be supplied as the first argument:

```bash
./scripts/prepare_reference.sh /path/to/reference
```

The script:

1. downloads the `GRCh38.d1.vd1` reference genome from GDC;
2. extracts the FASTA archive;
3. creates a FASTA index using `samtools faidx`;
4. extracts chromosomes 1–22, X, Y and M into separate FASTA files;
5. creates a `.fai` index for each chromosome FASTA.

The resulting chromosome reference files are stored in sepChrs/

`samtools` is provided by the Docker image described in the repository Dockerfile.

## 3. Resolve REF and ALT alleles

`resolve_alleles.py` compares `allele1` and `allele2` for each SNP with the nucleotide found at the corresponding GRCh38 position.

Conceptually, for each variant:

```text
GRCh38 base == allele1  -> REF = allele1, ALT = allele2
GRCh38 base == allele2  -> REF = allele2, ALT = allele1
```

If neither allele matches the reference, the variant is not written as a resolved REF/ALT record.

The script additionally checks whether the reverse-complement representation of the supplied alleles is compatible with the reference. Such records are reported as possible strand-flipped variants for diagnostic purposes; the script does not automatically modify their alleles.

### Input format

```text
#CHROM    POS    ID    allele1    allele2
chr1      12345  rs123  A          G
```

### Output format

```text
#CHROM    POS    ID    REF    ALT
chr1      12345  rs123  A      G
```

The script accepts named command-line arguments for the input file, output file and reference directory.

Example:

```bash
python resolve_alleles.py \
    --input FP_SNPs_10k_GB38_twoAllelsFormat.tsv \
    --output FP_SNPs_10k_GB38_REF_ALT.tsv \
    --reference /path/to/GRCh38.d1.vd1_mainChr/sepChrs
```

Use:

```bash
python resolve_alleles.py --help
```

to see all available command-line options.
## 4. Example: checking variants against dbSNP

`check_dbsnp.sh` provides an example of checking SNP identifiers and reference alleles against a dbSNP VCF, particularly for variants reported as possibly strand-flipped.

The dbSNP VCF must be downloaded separately before running the script.

Example using the NCBI GRCh38 dbSNP release (`GCF_000001405.40.gz`):

```bash
./scripts/check_dbsnp.sh GCF_000001405.40.gz strand_flip_rs.txt
```

Here, `strand_flip_rs.txt` is a text file containing one rsID per line. The script uses `bcftools` to print matching chromosome, position, ID, REF and ALT values.


## Workflow

The complete workflow is:

```text
GRAF 2.4
   |
   v
FP_SNPs.txt
   |
   | download_snps.sh
   v
FP_SNPs_10k_GB38_twoAllelsFormat.tsv
   |
   | resolve_alleles.py + GRCh38
   v
FP_SNPs_10k_GB38_REF_ALT.tsv
 { |
   v check flipped variants with check_dbsnp.sh }
   
```
