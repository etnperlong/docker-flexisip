ARG DEBIAN_VERSION=trixie
ARG FLEXISIP_VERSION
ARG FLEXISIP_BRANCH=master
ARG BUILD_TYPE=Release

##############
# Build stage
##############
FROM debian:${DEBIAN_VERSION} AS build

# Re-declare ARGs for use in this stage
ARG FLEXISIP_VERSION
ARG FLEXISIP_BRANCH
ARG BUILD_TYPE

# Install dependencies
RUN apt-get -y update \
  && apt-get -y install \
  # Common tools
  sudo \
  vim \
  wget \
  file \
  # Dev tools
  build-essential \
  llvm \
  ccache \
  clang \
  cmake \
  doxygen \
  g++ \
  gdb \
  git \
  make \
  ninja-build \
  dpkg-dev \
  python3 \
  python3-pystache \
  python3-six \
  python3-setuptools \
  yasm \
  # Dev dependencies for Flexisip
  libssl-dev \
  libboost-dev \
  libboost-system-dev \
  libboost-thread-dev \
  libcpp-jwt-dev \
  libhiredis-dev \
  libjansson-dev \
  libjsoncpp-dev \
  libnghttp2-dev \
  libsqlite3-dev \
  libpq-dev \
  libmariadb-dev \
  libmariadb-dev-compat \
  libsnmp-dev \
  libxerces-c-dev \
  libsrtp2-dev \
  libgsm1-dev \
  libopus-dev \
  libmbedtls-dev \
  libspeex-dev \
  libspeexdsp-dev \
  libxml2-dev \
  redis-server \
  # Dev Dependencies of the B2BUA
  libvpx-dev \
  # Clean up
  && apt-get -y autoremove \
  && apt-get -y clean \
  && rm -rf /var/lib/apt/lists/*

# Install dependencies from external sources
# Install libnghttp2_asio
# Downloading the gz source and not bz2 to avoid installing bzip2.
# nghttp2-asio has been moved out of nghttp2 from v1.52.0 onward.
# Static build
RUN wget https://github.com/nghttp2/nghttp2/releases/download/v1.51.0/nghttp2-1.51.0.tar.gz && \
  tar xf nghttp2-1.51.0.tar.gz && \
  cd nghttp2-1.51.0 && \
  CC="ccache clang" CXX="ccache clang++" ./configure --prefix=/usr/local --disable-shared --disable-examples --disable-python-bindings --enable-lib-only --enable-asio-lib && \
  make -j4 && \
  sudo make -C src install && \
  cd - && \
  rm -rf nghttp2-1.51.0.tar.gz nghttp2-1.51.0

# Clone Flexisip sources at specific version or commit
RUN if echo "${FLEXISIP_VERSION}" | grep -qE '^[0-9a-f]{40}$'; then \
      # For commit hash: clone branch first, then checkout specific commit \
      git clone --branch "${FLEXISIP_BRANCH}" \
        https://gitlab.linphone.org/BC/public/flexisip.git /flexisip && \
      cd /flexisip && \
      git checkout "${FLEXISIP_VERSION}" && \
      git submodule update --init --recursive; \
    else \
      # For version tags: use shallow clone with --branch \
      git clone --depth 1 --branch "${FLEXISIP_VERSION}" --recurse-submodules \
        https://gitlab.linphone.org/BC/public/flexisip.git /flexisip; \
    fi && \
  cd /flexisip && \
  echo "=== Flexisip Version ===" && \
  echo "Version: $(git describe --tags --always)" && \
  echo "=== Submodule Status ===" && \
  git submodule status | head -5

# Build debian package
WORKDIR /flexisip
RUN export CC="ccache clang" && export CXX="ccache clang++" && \
  cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DENABLE_UNIT_TESTS=OFF -DCPACK_GENERATOR=DEB && \
  cmake --build build -j$(nproc) --target package

##############
# Dist stage
##############
FROM debian:${DEBIAN_VERSION}-slim AS dist

COPY --from=build /flexisip/build/*.deb /tmp/
RUN apt-get -y update \
  && apt-get install -y --no-install-recommends /tmp/*.deb \
  && apt-get -y autoremove \
  && apt-get -y clean \
  && rm -rf /var/lib/apt/lists/* /tmp/*.deb

EXPOSE 5060/udp
EXPOSE 5060/tcp
VOLUME [ "/usr/local/etc/flexisip", "/usr/local/var/log/flexisip" ]

ENTRYPOINT [ "flexisip" ]