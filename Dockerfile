FROM ubuntu:25.10

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential clang flex bison g++ gawk gcc-multilib g++-multilib \
    gettext git libncurses5-dev libssl-dev     python3-setuptools \
    rsync swig unzip zlib1g-dev file wget \
    xsltproc libelf-dev ecj fastjar java-propose-classpath \
    python3 python3-dev curl zstd \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -u 1000 -o builder
USER builder
WORKDIR /home/builder

COPY --chown=builder:builder pkgs.txt /home/builder/pkgs.txt
COPY --chown=builder:builder build.sh /home/builder/build.sh

ENTRYPOINT ["/home/builder/build.sh"]
