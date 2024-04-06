#!/usr/bin/env bash
###############################################################
#
# Copyright (C) 2023 James Fuller, <jim@webcomposite.com>, et al.
#
# SPDX-License-Identifier: curl-container
###############################################################
#
# Create a dev image
# ex.
#   > create_dev_image.sh {arch} {base image} {compiler} {deps} {build_opts} {branch or tag} {resultant_image_name} {run_tests}
#
#

echo "####### creating curl dev image."

# get invoke opts
platform=${1}
dist=${2}
compiler_deps=${3}
deps=${4}
build_opts=${5}
branch_or_tag=${6}
image_name=${7}
run_tests=${8}

# set base and platform
if [[ -n $platform ]]; then
  echo "creating with platform=${platform}"
  bdr=$(buildah --platform ${platform} from ${dist})
else
  echo "creating ..."
  bdr=$(buildah from ${dist})
fi

# label/env
buildah config --label maintainer="James Fuller <jim.fuller@webcomposite.com>" $bdr
buildah config --label name="${image_name}" $bdr

# determine dist package manager
if [[ "$dist" =~ .*"alpine".* ]]; then
  package_manage_update="apk upgrade"
  package_manage_add="apk add "
fi
if [[ "$dist" =~ .*"fedora".* ]]; then
  package_manage_update="dnf update upgrade"
  package_manage_add="dnf -y install"
fi
if [[ "$dist" =~ .*"debian".* ]]; then
  package_manage_update="apt-get update"
  package_manage_add="apt-get -y install "
fi


# install deps using specific dist package manager
buildah run $bdr ${package_manage_update}
buildah run $bdr ${package_manage_add} ${deps}

# setup curl source derived from branch or tag
echo "get curl source"
buildah run $bdr mkdir /src

# Install quictls, nghttp3, ngtcp2
# See: https://curl.se/docs/http3.html
if [[ "$dist" =~ .*"debian".* ]]; then
  # build quictls
  buildah config --workingdir /src/ $bdr
  buildah run $bdr git clone --depth 1 -b openssl-3.1.4+quic https://github.com/quictls/openssl
  buildah config --workingdir /src/openssl $bdr
  buildah run $bdr ./config enable-tls1_3 --prefix=/usr
  buildah run $bdr make -j$(nproc)
  buildah run $bdr make install
  buildah run $bdr make clean

  # build nghttp3
  buildah config --workingdir /src/ $bdr
  buildah run $bdr git clone -b v1.1.0 https://github.com/ngtcp2/nghttp3
  buildah config --workingdir /src/nghttp3 $bdr
  buildah run $bdr git submodule update --init
  buildah run $bdr autoreconf -fi
  buildah run $bdr ./configure --prefix=/usr --enable-lib-only
  buildah run $bdr make -j$(nproc)
  buildah run $bdr make install
  buildah run $bdr make clean
  
  # build ngtcp2
  buildah config --workingdir /src/ $bdr
  buildah run $bdr git clone -b v1.2.0 https://github.com/ngtcp2/ngtcp2
  buildah config --workingdir /src/ngtcp2 $bdr
  buildah run $bdr autoreconf -fi
  buildah run $bdr ./configure PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/lib64/pkgconfig LDFLAGS="-Wl,-rpath,/usr/lib" --prefix=/usr --enable-lib-only
  buildah run $bdr make -j$(nproc)
  buildah run $bdr make install
  buildah run $bdr make clean
  
  buildah config --workingdir / $bdr
fi

if [ "${branch_or_tag:0:4}" = "curl" ]; then
  # its a tag, retrieve release source
  buildah run $bdr /usr/bin/curl -L -o curl.tar.gz "https://github.com/curl/curl/releases/download/${branch_or_tag}/curl-${release_tag}.tar.gz"
  buildah run $bdr tar -xvf curl.tar.gz
  buildah run $bdr rm curl.tar.gz
  buildah run $bdr mv curl-${release_tag} /src/curl-${release_tag}
  buildah config --workingdir /src/curl-${release_tag} $bdr
else
  # its a branch, retrieve archive source
  buildah run $bdr /usr/bin/curl -L -o curl.tar.gz https://github.com/curl/curl/archive/refs/heads/${branch_or_tag}.tar.gz
  buildah run $bdr tar -xvf curl.tar.gz
  buildah run $bdr rm curl.tar.gz
  buildah run $bdr mv curl-${branch_or_tag} /src/curl-${branch_or_tag}
  buildah config --workingdir /src/curl-${branch_or_tag} $bdr
fi

# build curl
buildah run $bdr autoreconf -fi
buildah run --env "LDFLAGS=-Wl,-rpath,/usr/lib64" $bdr ./configure ${build_opts}
buildah run $bdr make -j$(nproc)

# run tests
if [[ $run_tests -eq 1 ]]; then
  buildah run $bdr make test
fi

# install curl in /build
#buildah run $bdr make DESTDIR="/build/" install  -j$(nproc)

# install curl in /usr/local
buildah run $bdr make install  -j$(nproc)

# install useful dev deps¡
buildah run $bdr python3 -m ensurepip
#buildah run $bdr pip3 --no-input install -r ./requirements.txt

# label image
buildah config --label org.opencontainers.image.source="https://github.com/curl/curl-container" $bdr
buildah config --label org.opencontainers.image.description="minimal dev image for curl" $bdr
buildah config --label org.opencontainers.image.licenses="MIT" $bdr

# commit image
buildah commit $bdr "${image_name}" # --disable-compression false --squash --sign-by --tls-verify

