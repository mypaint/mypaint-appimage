#!/usr/bin/env bash

# Set environment variables to allow finding the dependencies that are
# compiled from sources
#export PATH="/${PREFIX}/bin:${PATH}"
export LD_LIBRARY_PATH="/usr/local/lib64:/usr/local/lib:${LD_LIBRARY_PATH}"
export PKG_CONFIG_PATH="/usr/local/lib64/pkgconfig:/usr/local/lib/pkgconfig:/usr/local/share/pkgconfig:${PKG_CONFIG_PATH}"

export LANG="en_US.UTF-8"
export LANGUAGE="en_US:en"
export LC_ALL="en_US.UTF-8"

set -e

# Optimize compiler flags for better perf
# These are pretty generic, ideally one would compile for own native arch
# We could try to target several CPU families in the future and distribute
# several binary packages.
export CFLAGS='-Ofast -ftree-vectorize -fopt-info-vec-optimized -funsafe-math-optimizations -funsafe-loop-optimizations'

cd "$APPIM_SOURCES/libmypaint"
./autogen.sh --prefix=/usr/local
./configure --prefix=/usr/local
make install


cd "$APPIM_SOURCES/mypaint-brushes"
./autogen.sh --prefix=/usr/local
./configure --prefix=/usr/local
make install


cd "$APPIM_SOURCES/mypaint"
python setup.py build_config \
       --brushdir-path="{installation-prefix}/share/mypaint-data/2.0/brushes" \
       install --prefix=/usr/local

touch $WORK_DIR/build.done
