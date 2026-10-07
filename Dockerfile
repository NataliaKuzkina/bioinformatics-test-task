FROM ubuntu:22.04
LABEL image.authors="natalia.kouzkina@gmail.com"

ARG DEBIAN_FRONTEND=noninteractive

ENV SOFT "/soft"
ENV TMP "/tmp"

ARG LIBDEFLATE_VERSION=1.26
ARG LIBDEFLATE_DIR=${SOFT}/libdeflate-${LIBDEFLATE_VERSION}

ARG HTSLIB_VERSION=1.24
ARG HTSLIB_DIR=${SOFT}/htslib-${HTSLIB_VERSION}

ARG SAMTOOLS_VERSION=1.24
ARG SAMTOOLS_DIR=${SOFT}/samtools-${SAMTOOLS_VERSION}

ARG BCFTOOLS_VERSION=1.24
ARG BCFTOOLS_DIR=${SOFT}/bcftools-${BCFTOOLS_VERSION}

ARG VCFTOOLS_VERSION=0.1.17
ARG VCFTOOLS_DIR=${SOFT}/vcftools-${VCFTOOLS_VERSION}

# ============================================================
# Build dependencies for bioinformatics tools
# Python runtime and pip for the SNP allele python task, bash-completion - for convenience
# ============================================================
RUN apt-get update && apt-get --yes --no-install-recommends install \
    bash-completion \
    build-essential \
    bzip2 \
    cmake \
    libbz2-dev \
    libcurl4-openssl-dev \
    liblzma-dev \
    libncurses5-dev \
    libssl-dev \
    pkg-config \
    python3 \
    python3-pip \
    python-is-python3 \
    wget \
    zlib1g-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Python dependencies for the SNP allele task
RUN python3 -m pip install --no-cache-dir pysam rich

WORKDIR ${TMP}

# ============================================================
# Libdeflate 1.26
# Release date: 22 Aug 2026
# ============================================================
RUN wget "https://github.com/ebiggers/libdeflate/releases/download/v${LIBDEFLATE_VERSION}/libdeflate-${LIBDEFLATE_VERSION}.tar.gz" \
        -O libdeflate-${LIBDEFLATE_VERSION}.tar.gz && \
    tar -xzf libdeflate-${LIBDEFLATE_VERSION}.tar.gz && \
    cd libdeflate-${LIBDEFLATE_VERSION} && \
    cmake -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=${LIBDEFLATE_DIR} && \
    cmake --build build --parallel "$(nproc)" && \
    cmake --install build && \
    cd .. && \
    rm -rf libdeflate-${LIBDEFLATE_VERSION}.tar.gz  libdeflate-${LIBDEFLATE_VERSION}

# ============================================================
# HTSlib 1.24
# Release date: 9 July 2026
# ============================================================
RUN wget "https://github.com/samtools/htslib/releases/download/${HTSLIB_VERSION}/htslib-${HTSLIB_VERSION}.tar.bz2" \
        -O htslib-${HTSLIB_VERSION}.tar.bz2 && \
    tar -xjf htslib-${HTSLIB_VERSION}.tar.bz2 && \
    cd htslib-${HTSLIB_VERSION} && \
    ./configure CPPFLAGS="-I${LIBDEFLATE_DIR}/include" LDFLAGS="-L${LIBDEFLATE_DIR}/lib -Wl,-R${LIBDEFLATE_DIR}/lib"\
        --prefix=${HTSLIB_DIR}\
        --with-libdeflate && \
    make -j"$(nproc)" && \
    make install && \
    cd .. && \
    rm -rf htslib-${HTSLIB_VERSION} htslib-${HTSLIB_VERSION}.tar.bz2

# ============================================================
# Samtools 1.24
# Release date: 9 July 2026
# ============================================================

RUN wget "https://github.com/samtools/samtools/releases/download/${SAMTOOLS_VERSION}/samtools-${SAMTOOLS_VERSION}.tar.bz2" \
        -O samtools-${SAMTOOLS_VERSION}.tar.bz2 && \
    tar -xjf samtools-${SAMTOOLS_VERSION}.tar.bz2 && \
    cd samtools-${SAMTOOLS_VERSION} && \
    CPPFLAGS="-I${HTSLIB_DIR}/include -I${LIBDEFLATE_DIR}/include" \
    LDFLAGS="-L${HTSLIB_DIR}/lib -L${LIBDEFLATE_DIR}/lib -Wl,-rpath,${HTSLIB_DIR}/lib -Wl,-rpath,${LIBDEFLATE_DIR}/lib" \
    ./configure \
        --prefix=${SAMTOOLS_DIR} \
        --with-htslib=${HTSLIB_DIR} && \
    make -j"$(nproc)" && \
    make install && \
    cd .. && \
    rm -rf samtools-${SAMTOOLS_VERSION} samtools-${SAMTOOLS_VERSION}.tar.bz2

# ============================================================
# BCFtools 1.24
# Release date: 9 July 2026
# ============================================================

RUN wget "https://github.com/samtools/bcftools/releases/download/${BCFTOOLS_VERSION}/bcftools-${BCFTOOLS_VERSION}.tar.bz2" \
        -O bcftools-${BCFTOOLS_VERSION}.tar.bz2 && \
    tar -xjf bcftools-${BCFTOOLS_VERSION}.tar.bz2 && \
    cd bcftools-${BCFTOOLS_VERSION} && \
    ./configure \
        --prefix=${BCFTOOLS_DIR} \
        --with-htslib=${HTSLIB_DIR} && \
    make -j"$(nproc)" && \
    make install && \
    cd .. && \
    rm -rf bcftools-${BCFTOOLS_VERSION} bcftools-${BCFTOOLS_VERSION}.tar.bz2

# ============================================================
# VCFtools 0.1.17
# Release date: 15 May 2025
# ============================================================
RUN wget "https://github.com/vcftools/vcftools/releases/download/v${VCFTOOLS_VERSION}/vcftools-${VCFTOOLS_VERSION}.tar.gz" \
        -O vcftools-${VCFTOOLS_VERSION}.tar.gz && \
    tar -xzf vcftools-${VCFTOOLS_VERSION}.tar.gz && \
    cd vcftools-${VCFTOOLS_VERSION} && \
    ./configure \
        --prefix=${VCFTOOLS_DIR} && \
    make -j"$(nproc)" && \
    make install && \
    cd .. && \
    rm -rf vcftools-${VCFTOOLS_VERSION} vcftools-${VCFTOOLS_VERSION}.tar.gz

# ============================================================
# Runtime environment
# ============================================================

ENV PATH="${SAMTOOLS_DIR}/bin:${HTSLIB_DIR}/bin:${BCFTOOLS_DIR}/bin:${VCFTOOLS_DIR}/bin:${LIBDEFLATE_DIR}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${HTSLIB_DIR}/lib:${LIBDEFLATE_DIR}/lib"

# Main tools
ENV SAMTOOLS="${SAMTOOLS_DIR}/bin/samtools"
ENV BCFTOOLS="${BCFTOOLS_DIR}/bin/bcftools"
ENV VCFTOOLS="${VCFTOOLS_DIR}/bin/vcftools"

# Additional tools
ENV BGZIP="${HTSLIB_DIR}/bin/bgzip"
ENV TABIX="${HTSLIB_DIR}/bin/tabix"
ENV HTSFILE="${HTSLIB_DIR}/bin/htsfile"
ENV LIBDEFLATEGZIP="${LIBDEFLATE_DIR}/bin/libdeflate-gzip"


WORKDIR /data

ENTRYPOINT ["/bin/bash"]


