# Bioinformatics Test Task

Docker image based on Ubuntu 22.04 with the following bioinformatics tools built from source:

- libdeflate 1.26
- HTSlib 1.24
- Samtools 1.24
- BCFtools 1.24
- VCFtools 0.1.17

The image also includes Python 3 with `pysam` and `rich`, and the SNP processing scripts in `/scripts/`.

## Build

```bash
docker build -t samtools-toolkit .
```

## Run

Mount a local data directory and, if needed, a reference genome directory:

```bash
docker run --rm -it \
    -v /path/to/data:/data \
    -v /path/to/reference:/ref \
    samtools-toolkit
```

The container starts in `/data`. All SNP processing scripts are available under `/scripts/`.
