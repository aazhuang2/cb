FROM ubuntu:18.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

SHELL ["/bin/bash", "-c"]

# Setup cross compilers
RUN dpkg --add-architecture i386 && \
    apt-get -y update && \
    apt-get install --allow-downgrades -y \
    wget \
    linux-libc-dev:i386 \
    gcc-7-multilib \
    gcc-arm-linux-gnueabi \
    gcc-arm-linux-gnueabihf \
    musl-dev musl-tools \
    gcc-aarch64-linux-gnu \
    gcc-mips64el-linux-gnuabi64 \
    gcc-s390x-linux-gnu \
    # gcc-powerpc64le-linux-gnu \
    gcc-riscv64-linux-gnu

RUN <<EOF
apt-get update
apt-get install -y --no-install-recommends curl
curl -L https://dot.net/v1/dotnet-install.sh -o - | bash -s -- --install-dir /usr/share/dotnet --channel LTS
EOF

ENV PATH="$PATH:/usr/share/dotnet"

FROM builder AS packager

# run build scripts
RUN --mount=type=bind,from=project_root,target=/a/cb,rw <<EOF
set -e
cd /a/cb/bld
export DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
dotnet run
rm -rf /a/cb/bld/bin/*
for f in linux_e_sqlite3_{x86,x64,arm64,armhf,armsf}.sh; do
    bash "$f" &
done
wait

cd /a/cb/SQLitePCLRaw.lib.e_sqlite3
dotnet pack

mkdir /output
cp -r /a/cb/bld/bin/* /output
cp -r /a/cb/nupkgs/* /output
EOF

# pull end build products out into scratch image to simplify extraction
FROM scratch

COPY --from=packager /output /
