#!/usr/bin/env bash

set -e

export APP=MyPaint

export AI_SCRIPTS_DIR="/sources"
export WORK_DIR="$(mktemp -d)"
export APPROOT=$WORK_DIR/appimage

mkdir -p "$APPROOT/scripts"
cp -a /sources/scripts/helpers/bundle-python.sh "$APPROOT/scripts"
cp -a /sources/scripts/helpers/bundle-gtk3.sh "$APPROOT/scripts"

DO_BUILD=0
if [ ! -e $WORK_DIR/build.done ]; then DO_BUILD=1; fi
if [ x"$DO_BUILD" = "x1" ]; then
    /sources/build-appimage.sh
fi

/sources/package-appimage.sh

if [ -n "$USERID" ]; then
    chown -R "$USERID:$USERID" /sources/out/
fi
