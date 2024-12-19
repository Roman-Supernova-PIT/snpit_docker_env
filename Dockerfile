# ROB WRITE BUILD NOTES
# (See README.md for instructions.)

# The base image (in the first FROM statement) is the Daedalus release
# of Devuan.  Devuan is a close derivative of Debian that isn't based on
# systemd.  I strongly suspect that the Dockerfile would build if we
# used the corresponding Debian base image.  To see the mapping of
# Debian and Devuan versions, see: https://www.devuan.org/os/releases
#
# This base devuan image should exist on docker.io, so things should
# "just work".  However, in the unlikely even that you you have to build
# it, you can do so on a Linux machine.
#
#   1. Pull the image
#        sudo debootstrap --verbose --include=iputils-ping daedalus ./devuan-image http://pkgmaster.devuan.org/merged
#
#   2. chroot into the image, do any updates etc. that you want (as root!)
#        (For this image, I did basically nothing.)
#
#   3. Make sure to do `apt clean` and `rm -rf /var/lib/apt/lists` to reduce image bloat
#
#   4. Exit chroot
#
#   5. Make Docker image:
#        cd devuan-image
#        sudo tar cpf - . | docker import - <imagename>
#      where <imagename> is where the image will live.  (I used
#      <imagename>=rknop/devuan-daedalus-rknop, but you shouldn't use
#      exactly that as you won't be able to push to my repo on
#      docker.io.)
#
#   6. Push the docker image as necessary.

FROM rknop/devuan-daedalus-rknop AS base
LABEL maintainer="Rob Knop <raknop@lbl.gov>"

SHELL [ "/bin/bash", "-l", "-c" ]

# Try to set up cuda
RUN cat /etc/apt/sources.list | perl -pe 's/main$/main non-free contrib/' > /etc/apt/sources.list.new \
   && mv /etc/apt/sources.list.new /etc/apt/sources.list
COPY cuda-archive-keyring.gpg /usr/share/keyrings/cuda-archive-keyring.gpg
COPY nvidia-container-toolkit-keyring.gpg /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
COPY cuda-debian12-x86_64.list /etc/apt/sources.list.d/cuda-debian12-x86_64.list
COPY nvidia-container.list /etc/apt/source.list.d/nvidia-container.list

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility
ENV NVIDIA_REQUIRE_CUDA="cuda>=8.0"

RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get -y install -y \
          emacs python3 \
          cuda-cudart-12-2 libcudnn9-cuda-12 libcurand-12-2 libcublas-12-2 \
          tzdata locales curl libbz2-1.0 zlib1g \
          source-extractor swarp \
          cuda-nvrtc-12-2 libcufft-12-2 \
          libcusolver-12-2 \
          libnvjitlink-12-2 libcusparse-12-2 \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# principle of least surprise
RUN ln -s /usr/bin/python3 /usr/bin/python
RUN ln -s /usr/bin/SWarp /usr/bin/swarp
RUN ln -s /usr/bin/source-extractor /usr/bin/sextractor
RUN ln -s /usr/bin/source-extractor /usr/bin/sex

# Grrr.... nvidia apt-get sticks stuff in /usr/local.  That's naughty.
ENV PATH=/usr/local/cuda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# ENV LD_LIBRARY_PATH="/usr/local/cuda/lib64:${LD_LIBRARY_PATH}"
ENV LD_LIBRARY_PATH="/usr/local/cuda/lib64"

# Generate the UTF8 locale
RUN cat /etc/locale.gen | perl -npe 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' > /etc/locale.gen.new \
    && mv /etc/locale.gen.new /etc/locale.gen
RUN locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# ======================================================================

FROM base AS buildbase

RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get -y install -y \
          libcurand-dev-12-2 libcudnn9-dev-cuda-12 libcublas-dev-12-2 cuda-minimal-build-12-2 \
          cuda-command-line-tools-12-2 \
          libbz2-dev zlib1g-dev \
          cuda-nvrtc-dev-12-2 libcufft-dev-12-2 \
          libcusolver-dev-12-2 \
          libnvjitlink-dev-12-2 \
          libcusparse-dev-12-2 \
          nsight-systems-2024.4.2 nsight-compute-2024.3.1 \
          python3-pip python3-venv git wcslib-dev \
          build-essential gfortran cmake g++ gdb valgrind libfmt-dev libspdlog-dev autotools-dev libtool autoconf \
    && apt-get -y autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ======================================================================

FROM buildbase AS pip

RUN python3 -mvenv /venv

RUN source /venv/bin/activate \
    && pip install \
         astropy==7.0 \
         cupy-cuda12x==13.3 \
         fastparquet==2024.11 \
         fastremap==1.15 \
         fitsio==1.2 \
         galsim==2.6 \
         llvmlite==0.43 \
         matplotlib==3.10 \
         numba==0.60 \
         numpy==1.26 \
         nvmath-python[cu12]==0.2 \
         nvtx==0.2.10 \
         pandas==2.2 \
         photutils==2.0 \
         pyarrow==18.1 \
         pyfftw==0.15 \
         pytest==8.3 \
         requests==2.32 \
         scipy==1.14 \
         "scikit-image<=0.18.3" \
         sep==1.2

WORKDIR /usr/src

# Note: as of this writing, the roman_imsim archive has both a branch
#   and a tag "v2.0".  That caused the git archive command to choke.
#   So, we use the specific git commit hash as the argument to git
#   archive.  (This version (or, presumably, later) is needed, at least,
#   for phrosty.)

RUN git clone https://github.com/matroxel/roman_imsim.git \
  && mkdir /roman_imsim \
  && cd roman_imsim \
  && git archive 74a9053 | tar -x -C /roman_imsim  \
  && cd .. \
  && rm -rf roman_imsim

# ======================================================================

FROM base AS runtime

COPY --from=pip /venv /venv
COPY --from=pip /roman_imsim /roman_imsim

ENV PATH=/venv/bin:${PATH}
ENV PYTHONPATH=/venv/lib/python3.11/site-packages:/roman_insim



# =====================================================================

FROM pip AS dev-runtime

WORKDIR /usr/src

ENV PATH=/venv/bin:${PATH}
ENV PYTHONPATH=/venv/lib/python3.11/site-packages:/roman_insim


