#! /bin/bash
LOWERAPP=${APP,,}
export PATH="/usr/local/bin:${PATH}"
export LD_LIBRARY_PATH="/usr/local/lib64:/usr/local/lib:${LD_LIBRARY_PATH}"
export PKG_CONFIG_PATH="/usr/local/lib64/pkgconfig:/usr/local/lib/pkgconfig:/usr/local/share/pkgconfig:${PKG_CONFIG_PATH}"

echo ""
echo "########################################################################"
echo ""
echo "AppImage configuration:"
echo "  APP: \"$APP\""
echo "  LOWERAPP: \"$LOWERAPP\""
echo "  APPIM_SOURCES: \"${APPIM_SOURCES}\""
echo ""

source "$APPIM_SOURCES/scripts/helpers/functions.sh"


#locale-gen en_US.UTF-8
export LANG="en_US.UTF-8"
export LANGUAGE="en_US:en"
export LC_ALL="en_US.UTF-8"


echo ""
echo "########################################################################"
echo ""
echo "Creating and cleaning AppImage folder"

cp "$APPIM_SOURCES/scripts/helpers/excludelist" "$APPROOT/excludelist"

# Remove old AppDir structure (if existing)
export APPDIR="${APPROOT}/${APP}.AppDir"
rm -rf "${APPDIR}"
mkdir -p "${APPDIR}/usr/"
echo "  APPROOT: \"$APPROOT\""
echo "  APPDIR: \"$APPDIR\""
echo ""

mkdir -p "$APPDIR/usr/bin"
mkdir -p "$APPDIR/usr/lib"
mkdir -p "$APPDIR/usr/share"

cp -a "/usr/local/bin/$LOWERAPP" "$APPDIR/usr/bin"
cp -a /usr/local/lib/*"${LOWERAPP}"* "$APPDIR/usr/lib"
cp -a /usr/local/share/*"${LOWERAPP}"* "$APPDIR/usr/share"

# Not all distros have the strings utility in the base install
# Used at startup to check whether to use bundled or installed libs
cp -L /usr/bin/strings "$APPDIR/usr/bin"

run_hooks

if [ -e "/usr/lib64/girepository-1.0" ]; then
    cp -a "/usr/lib64/girepository-1.0" "$APPDIR/usr/lib"
fi

set -e

cd "$APPDIR"



echo ""
echo "########################################################################"
echo ""
echo "Copy dependencies, excluding blacklisted libraries"
echo ""

copy_deps2; delete_blacklisted2;
copy_deps2; delete_blacklisted2;
copy_deps2; delete_blacklisted2;
copy_deps2; delete_blacklisted2;


# Copy in the dependencies that cannot be assumed to be available
# on all target systems


echo ""
echo "########################################################################"
echo ""
echo "Move all libraries into $APPDIR/usr/lib"
echo ""

move_lib

echo ""
echo "########################################################################"
echo ""
echo "Copy desktop file and application icon"

# Copy hicolor icon theme (mypaint only)
mkdir -p usr/share/icons
echo "cp -r \"/usr/local/share/icons/\"* \"usr/share/icons\""
cp -r "/usr/local/share/icons/"* "usr/share/icons"
# Remove some larger scalable icons which have better rasterized equivalents
(
  pref=mypaint-tool
  cd usr/share/icons/hicolor/scalable/actions
  rm -f $pref-*wheel* $pref-*cube* $pref-component-sliders*
)

mkdir -p usr/share/applications
cp /usr/local/share/applications/"${LOWERAPP}".desktop usr/share/applications

echo ""
echo "########################################################################"
echo ""
echo "Copy the subset of Adwaita icons we need"

adwaita_dir="/usr/share/icons/Adwaita"
mkdir -p "$APPDIR/$adwaita_dir"
cp -rat "$APPDIR/$adwaita_dir" \
   $adwaita_dir/scalable $adwaita_dir/index.theme
scl_dir="$APPDIR/$adwaita_dir/scalable/"
# Most of the icons don't need to be bundled. Adjust the list of
# removed directories below, if something turns out to be missing.
( cd "$scl_dir"; rm -r apps categories emblems emotes devices mimetypes status )
gtk-update-icon-cache "$APPDIR/$adwaita_dir"


echo ""
echo "########################################################################"
echo ""
echo "Creating top-level desktop and icon files, and application launcher"
echo ""

cp -a -t . \
   "$APPIM_SOURCES/AppRun" \
   "$APPIM_SOURCES/scripts/helpers/apprun-helper.sh" \
   "$APPIM_SOURCES/scripts/helpers/gtk-theme-helper.py"
get_desktop
get_icon


echo ""
echo "########################################################################"
echo ""
echo "Copy locale messages"
echo ""

# The fonts configuration should not be patched, copy back original one
if [[ -e /usr/local/share/locale ]]; then
    mkdir -p usr/share/locale
    cp -a "/usr/local/share/locale/"* usr/share/locale
fi


# Use patched version of gtk so that gtk locale messages can be bundled
echo ""
echo "########################################################################"
echo ""
echo "Replace libgtk with patched version and bundle locales"

cd "$WORK_DIR"
rurl="https://github.com/jplloyd/mypaint-appimage/releases/download/aux_files"
aux_bundle_url="${rurl}/gtk3.22.30-mypaint-appimage-files.tar.gz"
if [ -e "${APPIM_SOURCES}/gtk-data.tar.gz" ]; then
    cp "${APPIM_SOURCES}/gtk-data.tar.gz" .
else
    wget --no-verbose "$aux_bundle_url" -O gtk-data.tar.gz
fi
tar xf gtk-data.tar.gz
cp -a lib/libgtk* -t "${APPDIR}/usr/lib/"

# Copy gtk translation packages (message objects)
loc_dir="${APPDIR}/usr/share/locale"
for loc in "$loc_dir"/*
do
    locale="$(basename "$loc")"
    echo "Copying locale: ${locale}"
    if [ -e po/"$locale".gmo ]; then
        target=$loc/LC_MESSAGES
        mv po/"$locale".gmo "$target"/gtk30.mo
        mv properties/"$locale".gmo "$target"/gtk30-properties.mo
    else
        echo "Warning: no gtk messages found, wrong locale code ($locale)?"
    fi
done

(
    set +e
    cd "$APPIM_SOURCES/scripts/helpers/appimage-exec-wrapper2";
    make && cp -a exec.so "$APPDIR/usr/lib/exec_wrapper2.so"
    true
)

echo ""
echo "########################################################################"
echo ""
echo "Stripping binaries"
echo ""

# Strip binaries.
strip_binaries

echo ""
echo "########################################################################"
echo ""
echo "Cleaning away miscellaneous unused data"
echo ""

# Remove .pyc and .pyo files - prioritizing bundle size
# over a slight increase in load times
find "$APPDIR/usr" -name "*.py[co]" -exec rm -f {} +

# Delete the tests directories in the bundled numpy
find "$APPDIR/usr/lib" -type d -wholename "*numpy*tests*" -exec rm -rf {} +

# Remove unused files
find "$APPDIR/usr/" -name '*egg-info' -o -name '*.txt' -o -name '*.h' | xargs rm -rf
find "$APPDIR/usr/" -wholename '*numpy/*/setup.py' -exec rm {} +


echo ""
echo "########################################################################"
echo ""
echo "Minifying MyPaint modules"
echo ""


minify() {
    local tmpfile
    tmpfile=$(mktemp)
    pyminify --remove-literal-statements \
             --no-convert-posargs-to-args \
             --no-hoist-literals \
             "$1" > "$tmpfile" && mv -f "$tmpfile" "$1"
}

# Parallell function call (w. limited parallell jobs) code taken from:
# https://unix.stackexchange.com/a/216475

# initialize a semaphore with a given number of tokens
open_sem(){
    mkfifo pipe-$$
    exec 3<>pipe-$$
    rm pipe-$$
    local i=$1
    for((;i>0;i--)); do
        printf %s 000 >&3
    done
}

# run the given command asynchronously and pop/push tokens
run_with_lock(){
    local x
    # this read waits until there is something to read
    read -u 3 -n 3 x && ((0==x)) || exit $x
    (
        ( "$@"; )
        # push the return code of the command to the semaphore
        printf '%.3d' $? >&3
    )&
}


open_sem $(nproc || echo "4")
for f in "$APPDIR/usr/bin/mypaint" "$APPDIR/usr/bin/python2.7-config" \
         $(find "$APPDIR/usr/lib/mypaint/" -name "*.py")
do
    run_with_lock minify "$f"
done

echo ""
echo "########################################################################"
echo ""
echo "Stripping xml data"
echo ""

strip_xml_ws_and_comments() {
    # We only strip leading whitespace - it is sufficient for the data processed here
    sed -E 's/^\s*//' | tr -d '\n' | sed -E 's/<!--([^-]|-[^-])*-->//g';
}

strip_xml() {
    local tmpfile
    tmpfile=$(mktemp)
    strip_xml_ws_and_comments < "$1" > $tmpfile && mv -f $tmpfile "$1"
}

for f in $(find "$APPDIR/usr/" -name "*.xml" -or -name "*.glade")
do
    run_with_lock strip_xml "$f"
done


# Run scour on the Adwaita icon subset (non-destructive minification)
minifysvg() {
    tmp=$(mktemp)
    scour --remove-descriptive-elements -q -i "$1" > "$tmp" && mv "$tmp" "$1";
}

(
    cd $scl_dir
    for svg in $(find -name "*.svg")
    do
        run_with_lock minifysvg "$svg"
    done
)

echo ""
echo "########################################################################"
echo ""
echo "Removing/relinking unused shared objects"
echo ""

# This step should be the first to check if things start crashing.
# We remove the things that are not used right now, but they may
# be used at some future point in time (directly or indirectly).
(
    dummy="exec_wrapper2.so"
    pushd "$APPDIR/usr/lib"
    ln -s -f "$dummy" libtatlas.so.3 && rm -f libtatlas.so.3.*
    ln -f "$dummy" libnss3.so
    ln -f "$dummy" libnssutil3.so
    ln -s -f "$dummy" libsqlite3.so.0 && rm -f libsqlite3.so.0.*
    ln -s -f "$dummy" librpm.so.3 && rm -f librpm.so.3.*
    ln -s -f "$dummy" libcurl.so.4 && rm -f libcurl.so.4.*
    ln -s -f "$dummy" libtiff.so.5 && rm -f libtiff.so.5.*
    ln -s -f "$dummy" libssh.so.2 && rm -f libssh.so.2.*
    popd
)

echo ""
echo "########################################################################"
echo ""
echo "Generating AppImage(s)"
echo ""

GIT_DESCRIBE=$(cd "$APPIM_SOURCES/mypaint" && git describe --tags || echo "tagless")
export GIT_DESCRIBE
echo "GIT_DESCRIBE: ${GIT_DESCRIBE}"

cd "$APPROOT"
export ARCH="x86_64"
export VERSION="${GIT_DESCRIBE}"
VERSION_FULL="${GIT_DESCRIBE}-$(date '+%Y-%m-%d_%H:%M')"
export VERSION_FULL
echo "VERSION:  $VERSION"
echo "VERSION_FULL: $VERSION_FULL"

echo "${APP}" > "$APPDIR/version.txt"
echo "${VERSION_FULL}" >> "$APPDIR/version.txt"

export NO_GLIBC_VERSION=true
export DOCKER_BUILD=true

# Store the exact commits the build is based on.
githash(){ git show -s --format="%H" HEAD; }
myp_hash="mypaint: $(cd "$APPIM_SOURCES/mypaint/" && githash)"
lib_hash="libmypaint: $(cd "$APPIM_SOURCES/libmypaint/" && githash)"
echo "$myp_hash
$lib_hash" > "${APPDIR}/build_source_commits.txt"


# Generate AppImage; this expects $ARCH, $APP and $VERSION to be set
generate_type2_appimage --comp=xz

APPIM_FILE_NAME="${APP}-${VERSION_FULL}.AppImage"

mkdir -p "$APPIM_SOURCES/out"
mv ../out/*.AppImage "$APPIM_SOURCES/out/${APPIM_FILE_NAME}"
pushd "$APPIM_SOURCES/out"
sha256sum "${APPIM_FILE_NAME}" > "${APPIM_FILE_NAME}".sha256sum

popd

# Generate AppImage without bundled translations
find "$APPDIR" -name "*.mo" -exec rm {} +
rm -rf "$APPDIR/usr/share/locale/"
echo "
supported_locales = []
" >> "$APPDIR"/usr/lib/mypaint/lib/config.py


# For the no-translations version, remove all unused encodings
(
    cd "$APPDIR"/usr/lib/python2.7
    pref=$APPIM_SOURCES/scripts/helpers
    for f in $(cat $pref/"unimported-encodings")
    do
        rm -f $f
    done
)

generate_type2_appimage --comp=xz

APPIM_FILE_NAME="${APP}-${VERSION_FULL}-no-translations.AppImage"

mv ../out/*.AppImage "$APPIM_SOURCES/out/${APPIM_FILE_NAME}"
pushd "$APPIM_SOURCES/out"
sha256sum "${APPIM_FILE_NAME}" > "${APPIM_FILE_NAME}".sha256sum
