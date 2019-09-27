#!/bin/bash

set -e

SCRIPTDIR=$(dirname "$(readlink -f "$0")")
APPIM_INIT_SCRIPT="mkappimage.sh"

# If provided, the first argument should be the name
# of the docker image that the build will be run on
DOCKER_IMAGE="mypaint/appimage-base:1.0.0"
if [ -n "$1" ]; then
    DOCKER_IMAGE="$1"
fi

function check_prerequisites
{
    local FAILED=0
    local GH_LOC="https://github.com/mypaint"
    for dir in "$@"; do
	# If the repo directory is not present: issue warning, set failure flag
        if [ ! -e "$SCRIPTDIR/$dir" ]; then
	    echo "============================================================"
	    echo "Project directory \"$dir\" not in $SCRIPTDIR, fetch it with:"
	    # Make the command easier to copy/paste by making it a
	    # one-liner even when running from another directory
	    local DST=""
	    if [ "$(readlink -f "$(pwd)")" != "$SCRIPTDIR" ]; then
		DST=" $SCRIPTDIR/$dir"
	    fi
	    echo "git clone --depth=1 $GH_LOC/$dir"".git""$DST"
	    echo "============================================================"
	    FAILED=1
	fi
    done
    if [ $FAILED != 0 ]; then
	echo "Cancelling build, required files are missing (see above)."
    fi
    return $FAILED
}

# Check whether all required external repositories are present
check_prerequisites mypaint libmypaint mypaint-brushes

# If the check passes, start the appimage build in a docker container
# Pass in the USER envvar for convenience when building images locally,
# so that permissions don't have to be updated after each build.
docker run -it -eUSERID="$(id -u)" -v "${SCRIPTDIR}:/sources" \
       "$DOCKER_IMAGE" "sources/$APPIM_INIT_SCRIPT"
