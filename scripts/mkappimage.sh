#!/usr/bin/env bash

set -e

export APP=MyPaint

export APPIM_SOURCES="${APPIM_SOURCES:-/sources/}"
WORK_DIR="$(mktemp -d)"
export WORK_DIR
export APPROOT=$WORK_DIR/appimage

mkdir -p "$APPROOT/scripts"

DO_BUILD=0
if [ ! -e "$WORK_DIR"/build.done ]; then DO_BUILD=1; fi
if [ x"$DO_BUILD" = "x1" ]; then
    "$APPIM_SOURCES/scripts/build-appimage.sh"
fi

"$APPIM_SOURCES/scripts/package-appimage.sh"

if [ -n "$USERID" ]; then
    chown -R "$USERID:$USERID" "$APPIM_SOURCES/out/"
fi
