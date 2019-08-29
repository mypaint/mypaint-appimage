#! /bin/bash

export APP=MyPaint

(yum update -y && yum install -y git wget file) || exit 1
mkdir -p /work
export AI_SCRIPTS_DIR="/sources"
export APPROOT=/work/appimage

mkdir -p "$APPROOT/scripts"
cp -a /sources/scripts/helpers/bundle-python.sh "$APPROOT/scripts"
cp -a /sources/scripts/helpers/bundle-gtk2.sh "$APPROOT/scripts"

DO_BUILD=0
if [ ! -e /work/build.done ]; then DO_BUILD=1; fi
if [ x"$DO_BUILD" = "x1" ]; then
	bash /sources/build-appimage.sh || exit 1
fi

bash /sources/package-appimage.sh || exit 1
