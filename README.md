# Bioinformatics Test Task

Docker image based on Ubuntu 22.04 with the following bioinformatics tools built from source:

- libdeflate 1.26
- HTSlib 1.24
- Samtools 1.24
- BCFtools 1.24
- VCFtools 0.1.17

## Build

```bash
docker build -t samtools-toolkit .

## Build

```bash
docker run --rm -it -v /path/to/data:/data samtools-toolkit
