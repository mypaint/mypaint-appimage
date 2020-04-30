#!/bin/bash
# Build using specified clean versions of each major dependency.

URL_PREF=https://github.com/mypaint

# Allows use of alternative repository locations,
# e.g. the local file system, or publically hosted forks.
BRUSH_SOURCE=${BRUSH_SOURCE:-$URL_PREF/mypaint-brushes.git}
MAIN_SOURCE=${MAIN_SOURCE:-$URL_PREF/mypaint.git}
LIB_SOURCE=${LIB_SOURCE:-$URL_PREF/libmypaint.git}

# Which branch/tag to use for each dependency
BRUSH_BRANCH=${BRUSH_BRANCH:-master}
MAIN_BRANCH=${MAIN_BRANCH:-master}
LIB_BRANCH=${LIB_BRANCH:-master}

# Create a fresh directory for the build
DIR_BASE=$(echo "build-$MAIN_BRANCH-$BRUSH_BRANCH-$LIB_BRANCH" | sed -E 's/\s+/_/g')
N=0
while [ -e "$DIR_BASE-$N" ]
do
    let N=(N+1)
done
DIR="$DIR_BASE-$N"
mkdir "$DIR"

# Shallow clone the appimage build repo itself into the build directory
cd "$DIR"
git clone file://"$(pwd)/.." .

# Clone the dependencies
git clone --depth=1 --branch "$BRUSH_BRANCH" "$BRUSH_SOURCE" mypaint-brushes
git clone --depth=1 --branch "$MAIN_BRANCH" "$MAIN_SOURCE" mypaint
git clone --depth=1 --branch "$LIB_BRANCH" "$LIB_SOURCE" libmypaint

# Run the build script
./build-on-docker.sh
