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


if [ -e "/usr/share/gir-1.0" ]; then
	cp -a "/usr/share/gir-1.0" "$APPDIR/usr/share"
fi

if [ -e "/usr/lib64/girepository-1.0" ]; then
	cp -a "/usr/lib64/girepository-1.0" "$APPDIR/usr/lib"
fi

set -e

cd "$APPDIR"


# Copy in the dependencies that cannot be assumed to be available
# on all target systems
copy_deps2; copy_deps2; copy_deps2;


echo ""
echo "########################################################################"
echo ""
echo "Copy MIME files"
echo ""

# Copy MIME files
mkdir -p usr/share/image
cp -a /usr/share/mime/image/x-*.xml usr/share/image


echo ""
echo "########################################################################"
echo ""
echo "Move all libraries into $APPDIR/usr/lib"
echo ""

# Move all libraries into $APPDIR/usr/lib
move_lib


echo ""
echo "########################################################################"
echo ""
echo "Delete blacklisted libraries"
echo ""

# Delete dangerous libraries; see
# https://github.com/probonopd/AppImages/blob/master/excludelist
delete_blacklisted2

# Remove .pyc and .pyo files - prioritizing bundle size
# over a slight increase in load times
find "$APPDIR/usr" -name "*.py[co]" -exec rm -f {} +

# Delete the tests directories in the bundled numpy
find "$APPDIR/usr/lib" -type d -wholename "*numpy*tests*" -exec rm -rf {} +


echo ""
echo "########################################################################"
echo ""
echo "Copy libfontconfig into the AppImage"
echo ""

# Copy libfontconfig into the AppImage
# It will be used if they are newer than those of the host
# system in which the AppImage will be executed
mkdir -p usr/optional/fontconfig
fc_prefix="$(pkg-config --variable=libdir fontconfig)"
cp -a "${fc_prefix}/libfontconfig"* usr/optional/fontconfig


echo ""
echo "########################################################################"
echo ""
echo "Copy libstdc++.so.6 and libgomp.so.1 into the AppImage"
echo ""

copy_gcc_libs


echo ""
echo "########################################################################"
echo ""
echo "Copy desktop file and application icon"

# Copy hicolor icon theme (mypaint only)
mkdir -p usr/share/icons
echo "cp -r \"/usr/local/share/icons/\"* \"usr/share/icons\""
cp -r "/usr/local/share/icons/"* "usr/share/icons"
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
wget "$aux_bundle_url" -O gtk-data.tar.gz
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


# Workaround for:
# ImportError: /usr/lib/x86_64-linux-gnu/libgdk-x11-2.0.so.0: undefined symbol: XRRGetMonitors
cp "$(ldconfig -p | grep libgdk-x11-2.0.so.0 | cut -d ">" -f 2 | xargs)" ./usr/lib/
cp "$(ldconfig -p | grep libgtk-x11-2.0.so.0 | cut -d ">" -f 2 | xargs)" ./usr/lib/

set -e

(cd "$APPIM_SOURCES/scripts/helpers/appimage-exec-wrapper2" && make && cp -a exec.so "$APPDIR/usr/lib/exec_wrapper2.so")

echo ""
echo "########################################################################"
echo ""
echo "Stripping binaries"
echo ""

# Strip binaries.
strip_binaries

GIT_DESCRIBE=$(cd "$APPIM_SOURCES/mypaint" && git describe --tags)
export GIT_DESCRIBE
echo "GIT_DESCRIBE: ${GIT_DESCRIBE}"

cd "$APPROOT"
export ARCH="x86_64"
export VERSION="${GIT_DESCRIBE}"
VERSION_FULL="${GIT_DESCRIBE}-$(date '+%Y-%m-%d_%H:%M')"
export VERSION_FULL
echo "VERSION:  $VERSION"
echo "VERSION_FULL: $VERSION_FULL"

echo "${APP}" > "$APPDIR/VERSION.txt"
echo "${VERSION_FULL}" >> "$APPDIR/VERSION.txt"

export NO_GLIBC_VERSION=true
export DOCKER_BUILD=true

# Generate AppImage; this expects $ARCH, $APP and $VERSION to be set
generate_type2_appimage

APPIM_FILE_NAME="${APP}-${VERSION_FULL}.AppImage"

mkdir -p "$APPIM_SOURCES/out"
cp ../out/*.AppImage "$APPIM_SOURCES/out/${APPIM_FILE_NAME}"
cd "$APPIM_SOURCES/out"
sha256sum "${APPIM_FILE_NAME}" > "${APPIM_FILE_NAME}".sha256sum
