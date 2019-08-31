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
echo "  AI_SCRIPTS_DIR: \"${AI_SCRIPTS_DIR}\""
echo ""

source /sources/scripts/helpers/functions.sh


#locale-gen en_US.UTF-8
export LANG="en_US.UTF-8"
export LANGUAGE="en_US:en"
export LC_ALL="en_US.UTF-8"


echo ""
echo "########################################################################"
echo ""
echo "Creating and cleaning AppImage folder"

cp /sources/scripts/helpers/excludelist "$APPROOT/excludelist"

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

cp -a /usr/local/bin/$LOWERAPP "$APPDIR/usr/bin"
cp -a /usr/local/lib/*${LOWERAPP}* "$APPDIR/usr/lib"
cp -a /usr/local/share/*${LOWERAPP}* "$APPDIR/usr/share"

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


cd "$APPDIR" || exit 1


# Copy in the dependencies that cannot be assumed to be available
# on all target systems
copy_deps2; copy_deps2; copy_deps2;



if [ "x" = "x" ]; then
echo ""
echo "########################################################################"
echo ""
echo "Copy MIME files"
echo ""

# Copy MIME files
mkdir -p usr/share/image
cp -a /usr/share/mime/image/x-*.xml usr/share/image || exit 1
fi



echo ""
echo "########################################################################"
echo ""
echo 'Move all libraries into $APPDIR/usr/lib'
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
cp -a "${fc_prefix}/libfontconfig"* usr/optional/fontconfig || exit 1


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

# Copy hicolor icon theme
mkdir -p usr/share/icons
echo "cp -r \"/usr/local/share/icons/\"* \"usr/share/icons\""
cp -r "/usr/local/share/icons/"* "usr/share/icons" || exit 1
mkdir -p usr/share/applications
cp /usr/local/share/applications/${LOWERAPP}.desktop usr/share/applications || exit 1


echo ""
echo "########################################################################"
echo ""
echo "Creating top-level desktop and icon files, and application launcher"
echo ""

cp -a "${AI_SCRIPTS_DIR}/AppRun" . || exit 1
cp -a /sources/scripts/helpers/apprun-helper.sh "./apprun-helper.sh" || exit 1
get_desktop || exit 1
get_icon || exit 1


echo ""
echo "########################################################################"
echo ""
echo "Copy locale messages"
echo ""

# The fonts configuration should not be patched, copy back original one
if [[ -e /usr/local/share/locale ]]; then
    mkdir -p usr/share/locale
    cp -a "/usr/local/share/locale/"* usr/share/locale || exit 1
fi


echo ""
echo "########################################################################"
echo ""
echo "Run get_desktopintegration"
echo ""

# desktopintegration asks the user on first run to install a menu item
get_desktopintegration "$LOWERAPP"
cp -a "/sources/ci/$LOWERAPP.wrapper" "$APPDIR/usr/bin/$LOWERAPP.wrapper"

#DESKTOP_NAME=$(cat "$APPDIR/$LOWERAPP.desktop" | grep "^Name=.*")
#sed -i -e "s|${DESKTOP_NAME}|${DESKTOP_NAME} (AppImage)|g" "$APPDIR/$LOWERAPP.desktop"


# Workaround for:
# ImportError: /usr/lib/x86_64-linux-gnu/libgdk-x11-2.0.so.0: undefined symbol: XRRGetMonitors
cp "$(ldconfig -p | grep libgdk-x11-2.0.so.0 | cut -d ">" -f 2 | xargs)" ./usr/lib/
cp "$(ldconfig -p | grep libgtk-x11-2.0.so.0 | cut -d ">" -f 2 | xargs)" ./usr/lib/


(cd /sources/scripts/helpers/appimage-exec-wrapper2 && make && cp -a exec.so "$APPDIR/usr/lib/exec_wrapper2.so") || exit 1



echo ""
echo "########################################################################"
echo ""
echo "Stripping binaries"
echo ""

# Strip binaries.
strip_binaries

export GIT_DESCRIBE=$(cd /sources/mypaint && git describe --tags)
echo "GIT_DESCRIBE: ${GIT_DESCRIBE}"

cd "$APPROOT"
export ARCH="x86_64"
export VERSION="${GIT_DESCRIBE}"
export VERSION_FULL="${GIT_DESCRIBE}-$(date '+%Y-%m-%d_%H:%M')"
echo "VERSION:  $VERSION"
echo "VERSION_FULL: $VERSION_FULL"

echo "${APP}" > "$APPDIR/VERSION.txt"
echo "${VERSION_FULL}" >> "$APPDIR/VERSION.txt"

export NO_GLIBC_VERSION=true
export DOCKER_BUILD=true

# Generate AppImage; this expects $ARCH, $APP and $VERSION to be set
generate_type2_appimage

APPIM_FILE_NAME="${APP}-${VERSION_FULL}.AppImage"

mkdir -p /sources/out
cp ../out/*.AppImage "/sources/out/${APPIM_FILE_NAME}"
cd /sources/out
sha256sum "${APPIM_FILE_NAME}" > "${APPIM_FILE_NAME}".sha256sum
