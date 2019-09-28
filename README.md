# mypaint-appimage
Scripts and resources for building and uploading Mypaint Appimages

## Overview

The scripts and data contained in this repo is used to build an
Appimage for MyPaint. An Appimage is a binary containing an application
and all dependencies that are not assumed to be part of the target systems
(the linux distributions that the Appimage can be run on).

The build process is set up to run on a docker image with preinstalled
dependencies that are necessary to build all components.
See `docker/Dockerfile` for the instructions that the build image is
based on.
It is possible to run the build "locally", but some paths may need to
be adapted depending on the system the build is being run on.

To build on docker, the root directory of this repo must contain
repos for mypaint, libmypaint and mypaint-brushes, in directories
with those same names. Symlinks cannot be used for this, as the root
dir is mounted on the docker container, and the links won't resolve
(unless they are relative and point to somewhere in the same subtree).

> :warning:
> These build scripts have been adapted from appimage builds from
> multiple different projects. Just because something exists in these
> scripts does not mean that it is actually used or needed.
> When cleaning up seemingly unused stuff, err on the side of caution
> since it is difficult to test on enough systems to be _sure_ whether
> something is needed or not. However, if something is _definitely_ not
> needed, please do remove it.

## Basic organisation

The basic callchain is this:
```
build-on-docker.sh
|-> scripts/mkappimage.sh
    | -> scripts/build-appimage.sh
	| -> scripts/package-appimage.sh
	     | -> scripts/helpers/...
```

`build-appimage.sh` builds mypaint, libmypaint and mypaint-brushes.

`package-appimage.sh` creates the directory structure for the Appimage,
moves and modifies direct and indirect dependencies and adds additional
data required to allow the final binary to be able to run on its own.
This process makes use of additional helper scripts to bundle gtk,
python and to perform a number of the modifications required.

When running on Travis CI, the docker build is run directly from the
`.travis.yml` instructions without going via `build-on-docker.sh`.


## Non-standard stuff

The gtk3.22 library we bundle is a patched to allow the locale search
path to be set at runtime. This is needed to bundle gtk .mo files
to properly support the languages that MyPaint supports.

The library is located in a compressed archive alongside all .mo files that
gtk supports - we only bundle the ones with corresponding installed `mypaint.mo` files.
The patch is also contained in the archive.

The archive itself is downloaded from a github release in order to not inflate the size of this repo.
Search for `gtk3.22` in package-appimage for details about the procedure.
