#! /bin/bash

# Prefix (without the leading "/") in which RawTherapee and its dependencies are installed:
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

#sudo chown -R "$USER" "/${PREFIX}/"

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
#exit

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
#echo ""
mkdir -p usr/share/applications
cp /usr/local/share/applications/${LOWERAPP}.desktop usr/share/applications || exit 1


echo ""
echo "########################################################################"
echo ""
echo "Creating top-level desktop and icon files, and application launcher"
echo ""

# TODO Might want to "|| exit 1" these, and generate_status
#get_apprun || exit 1
cp -a "${AI_SCRIPTS_DIR}/AppRun" . || exit 1
#cp -a "${AI_SCRIPTS_DIR}/fixes.sh" . || exit 1
cp -a /sources/scripts/helpers/apprun-helper.sh "./apprun-helper.sh" || exit 1
#cp -a "${AI_SCRIPTS_DIR}/check_updates.sh" . || exit 1
#cp -a "${AI_SCRIPTS_DIR}/zenity.sh" usr/bin || exit 1
#wget -q https://raw.githubusercontent.com/aferrero2707/appimage-helper-scripts/master/apprun-helper.sh -O "./apprun-helper.sh" || exit 1
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

export GIT_DESCRIBE=$(cd /sources && git describe)
echo "RT_BRANCH: ${RT_BRANCH}"
echo "GIT_DESCRIBE: ${GIT_DESCRIBE}"



# Generate AppImage; this expects $ARCH, $APP and $VERSION to be set
cd "$APPROOT"
glibcVer="$(glibc_needed)"
#ver="git-${RT_BRANCH}-$(date '+%Y%m%d_%H%M')-glibc${glibcVer}"
if [ "x${RT_BRANCH}" = "xreleases" ]; then
	rtver=$(cat AboutThisBuild.txt | grep "Version:" | head -n 1 | cut -d" " -f 2)
	ver="${rtver}-$(date '+%Y%m%d_%H%M')"
else
	ver="git-${RT_BRANCH}-$(date '+%Y%m%d_%H%M')"
fi
export ARCH="x86_64"
export VERSION="${ver}"
export VERSION2="${RT_BRANCH}-${GIT_DESCRIBE}-$(date '+%Y%m%d')"
echo "VERSION:  $VERSION"
echo "VERSION2: $VERSION2"

echo "${APP}-${RT_BRANCH}" > "$APPDIR/VERSION.txt"
echo "${GIT_DESCRIBE}-$(date '+%Y%m%d')" >> "$APPDIR/VERSION.txt"
echo "${APP}-${VERSION2}.AppImage" >> "$APPDIR/VERSION.txt"

wd="$(pwd)"
mkdir -p ../out/
export NO_GLIBC_VERSION=true
export DOCKER_BUILD=true
#export SIGN="1"
AI_OUT="../out/${APP}-${VERSION}-${ARCH}.AppImage"
generate_type2_appimage

if [ "x" = "y" ]; then
#generate_appimage
# Download AppImageAssistant
URL="https://github.com/AppImage/AppImageKit/releases/download/6/AppImageAssistant_6-x86_64.AppImage"
rm -f AppImageAssistant
wget -c "$URL" -O AppImageAssistant
chmod a+x ./AppImageAssistant
(rm -rf /tmp/squashfs-root && mkdir /tmp/squashfs-root && cd /tmp/squashfs-root && bsdtar xfp $wd/AppImageAssistant) || exit 1
#./AppImageAssistant --appimage-extract
mkdir -p ../out || true
GLIBC_NEEDED=$(glibc_needed)
rm "${AI_OUT}" 2>/dev/null || true
/tmp/squashfs-root/AppRun ./$APP.AppDir/ "${AI_OUT}"
fi

ls ../out/*

rm -f ../out/${APP}-${VERSION2}.AppImage
mv "${AI_OUT}" ../out/${APP}-${VERSION2}.AppImage


########################################################################
# Upload the AppDir
########################################################################

pwd
ls ../out/*
#transfer ../out/*
#echo ""
#echo "AppImage has been uploaded to the URL above; use something like GitHub Releases for permanent storage"
mkdir -p /sources/out
cp ../out/${APP}-${VERSION2}.AppImage /sources/out
cd /sources/out || exit 1
sha256sum ${APP}-${VERSION2}.AppImage > ${APP}-${VERSION2}.AppImage.sha256sum
