# This file is supposed to be sourced by each Recipe
# that wants to use the functions contained herein
# like so:
# wget -q https://github.com/AppImage/AppImages/raw/${PKG2AICOMMIT}/functions.sh -O ./functions.sh
# . ./functions.sh

# Detect system architecture to know which binaries of AppImage tools
# should be downloaded and used.
case "$(uname -i)" in
  x86_64|amd64)
#    echo "x86-64 system architecture"
    SYSTEM_ARCH="x86_64";;
  i?86)
#    echo "x86 system architecture"
    SYSTEM_ARCH="i686";;
#  arm*)
#    echo "ARM system architecture"
#    SYSTEM_ARCH="";;
  unknown|AuthenticAMD|GenuineIntel)
#         uname -i not answer on debian, then:
    case "$(uname -m)" in
      x86_64|amd64)
#        echo "x86-64 system architecture"
        SYSTEM_ARCH="x86_64";;
      i?86)
#        echo "x86 system architecture"
        SYSTEM_ARCH="i686";;
    esac ;;
  *)
    echo "Unsupported system architecture"
    exit 1;;
esac

# Copy the library dependencies of all exectuable files in the current directory
# (it can be beneficial to run this multiple times)
copy_deps2()
{
  mkdir -p usr/lib
  PWD=$(readlink -f .)
  FILES=$(find . -type f -executable -or -name *.so.* -or -name *.so | sort | uniq )
  for FILE in $FILES ; do
    ldd "${FILE}" | grep "=>" | awk '{print $3}' | xargs -I '{}' echo '{}' >> DEPSFILE
  done
  DEPS=$(cat DEPSFILE | sort | uniq)
  for FILE in $DEPS ; do
    if [ -e $FILE ] && [[ $(readlink -f $FILE)/ != $PWD/* ]] ; then
      echo "Copying library \"$FILE\"..."
      PARENT=""
      if [[ -h "$FILE" ]]; then
        PARENT=$(readlink "$FILE")
      fi
      #echo "  parent: $PARENT"
      while [ -n "$PARENT" ]; do
        DIR=$(dirname "$FILE")
        PDIR=$(dirname "$PARENT")
        if [ "$PDIR" != "." ]; then
          cp -u -v -L "$FILE" ./usr/lib
        else
          cp -u -v -a "$FILE" ./usr/lib
        fi

        ROOT=$(echo "$PARENT" | cut -c 1)
        if [ x"$ROOT" != "x/" ]; then
          FILE="$DIR/$PARENT"
        else
          FILE="$PARENT"
        fi

        #echo "  file: $FILE"
        PARENT=""
        if [[ -h "$FILE" ]]; then
          PARENT=$(readlink "$FILE")
        fi
        #echo "  parent: $PARENT"
      done
      cp -u -v -a "$FILE" ./usr/lib
    fi
  done
  rm -f DEPSFILE
}

# Move ./lib/ tree to ./usr/lib/
move_lib()
{
  mkdir -p ./usr/lib ./lib && find ./lib/ -exec cp -v --parents -rfL {} ./usr/ \; && rm -rf ./lib
  mkdir -p ./usr/lib ./lib64 && find ./lib64/ -exec cp -v --parents -rfL {} ./usr/ \; && rm -rf ./lib64
}

# Delete blacklisted libraries
delete_blacklisted2()
{
    while IFS= read -r line; do
        FLIST=$(find . -name "${line}*")
        for F in $FLIST; do
          rm -v -f "$F"
        done
    done < <(cat "$APPDIR/../excludelist" | sed '/^\s*$/d' | sed '/^#.*$/d')
}


# Echo highest glibc version needed by the executable files in the current directory
glibc_needed()
{
  find . -name *.so -or -name *.so.* -or -type f -executable  -exec strings {} \; | grep ^GLIBC_2 | sed s/GLIBC_//g | sort --version-sort | uniq | tail -n 1
}


# Remove debugging symbols from bundled executables and libraries
strip_binaries()
{
  chmod u+w -R "$APPDIR"
  find "$APPDIR" -type f -regex '.*\.so\(\.[0-9.]+\)?$' -print0 |
      xargs -0 --no-run-if-empty --verbose -n1 strip
}


# Generate AppImage type 2
# Additional parameters given to this routine will be passed on to appimagetool
#
# If the environment variable NO_GLIBC_VERSION is set, the required glibc version
# will not be added to the AppImage filename
generate_type2_appimage()
{
  URL="https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-${SYSTEM_ARCH}.AppImage"
  LOCAL_TOOL="${APPIM_SOURCES}/appimagetool-${SYSTEM_ARCH}.AppImage"
  [ -e "${LOCAL_TOOL}" ] && cp "${LOCAL_TOOL}" ./appimagetool
  [ -e appimagetool ] || wget -c "$URL" -O appimagetool
  chmod a+x ./appimagetool
  appimagetool=$(readlink -f appimagetool)

  if [ "$DOCKER_BUILD" ]; then
    appimagetool_tempdir=$(mktemp -d)
    mv appimagetool "$appimagetool_tempdir"
    pushd "$appimagetool_tempdir" &>/dev/null
    ls -al
    ./appimagetool --appimage-extract
    rm appimagetool
    appimagetool=$(readlink -f squashfs-root/AppRun)
    popd &>/dev/null
    _appimagetool_cleanup() { [ -d "$appimagetool_tempdir" ] && rm -r "$appimagetool_tempdir"; }
    trap _appimagetool_cleanup EXIT
  fi

  if [ -z ${NO_GLIBC_VERSION+true} ]; then
    GLIBC_NEEDED=$(glibc_needed)
    VERSION_EXPANDED=$VERSION.glibc$GLIBC_NEEDED
  else
    VERSION_EXPANDED=$VERSION
  fi

  echo "generate_type2_appimage: VERSION_EXPANDED=\"${VERSION_EXPANDED}\""

  set +x
  GLIBC_NEEDED=$(glibc_needed)
  if ( [ ! -z "$KEY" ] ) && ( ! -z "$TRAVIS" ) ; then
    wget https://github.com/AppImage/AppImageKit/files/584665/data.zip -O data.tar.gz.gpg
    ( set +x ; echo $KEY | gpg2 --batch --passphrase-fd 0 --no-tty --skip-verify --output data.tar.gz --decrypt data.tar.gz.gpg )
    tar xf data.tar.gz
    sudo chown -R $USER .gnu*
    mv $HOME/.gnu* $HOME/.gnu_old ; mv .gnu* $HOME/
    VERSION=$VERSION_EXPANDED "$appimagetool" $@ -n -s --bintray-user $BINTRAY_USER --bintray-repo $BINTRAY_REPO -v ./$APP.AppDir/
  else
    SIGN_OPT=""
    if [ ! -z "$SIGN" ]; then SIGN_OPT="-s"; fi

    echo "generate_type2_appimage: GEN_UPDATE_ZSYNC_GITHUB=${GEN_UPDATE_ZSYNC_GITHUB}"
    if [ x"${GEN_UPDATE_ZSYNC_GITHUB}" = "x1" ]; then
      echo "AppImageTool command: \"$appimagetool\" $@ -n ${SIGN_OPT} -u \"gh-releases-zsync|${GITHUB_USER}|${GITHUB_REPO}|continuous|${APP}-${GEN_UPDATE_VERSION}-*.zsync\" -v ./$APP.AppDir/"
      VERSION=$VERSION_EXPANDED "$appimagetool" $@ -n ${SIGN_OPT} -u "gh-releases-zsync|${GITHUB_USER}|${GITHUB_REPO}|continuous|${APP}-${GEN_UPDATE_VERSION}-*.zsync" -v ./$APP.AppDir/
    else
      echo "AppImageTool command: \"$appimagetool\" $@ -n ${SIGN_OPT} -v ./$APP.AppDir/"
      VERSION=$VERSION_EXPANDED "$appimagetool" $@ -n ${SIGN_OPT} -v ./$APP.AppDir/
    fi
  fi

  set -x
  mkdir -p ../out/ || true
  mv *.AppImage* ../out/
}

# Find the desktop file and copy it to the AppDir
get_desktop()
{
   find usr/share/applications -iname "*${LOWERAPP}.desktop" -exec cp {} . \; || true
}

# Find the icon file and copy it to the AppDir
get_icon()
{
  local ICON_NAME
  ICON_NAME="org.${LOWERAPP}.${APP}"
  find ./usr/share/pixmaps/$ICON_NAME.png -exec cp {} . \; 2>/dev/null || true
  find ./usr/share/icons -path *64* -name $ICON_NAME.png -exec cp {} . \; 2>/dev/null || true
  find ./usr/share/icons -path *128* -name $ICON_NAME.png -exec cp {} . \; 2>/dev/null || true
  find ./usr/share/icons -path *512* -name $ICON_NAME.png -exec cp {} . \; 2>/dev/null || true
  find ./usr/share/icons -path *256* -name $ICON_NAME.png -exec cp {} . \; 2>/dev/null || true
  find ./usr/share/icons -path *scalable* -name $ICON_NAME.svg -exec cp {} . \; 2>/dev/null || true
  ls -lh $ICON_NAME.svg || ls -lh $ICON_NAME.png || true
}

# Find out the version
get_version()
{
  THEDEB=$(find ../*.deb -name $LOWERAPP"_*" | head -n 1)
  if [ -z "$THEDEB" ] ; then
    echo "Version could not be determined from the .deb; you need to determine it manually"
  fi
  VERSION=$(echo $THEDEB | cut -d "~" -f 1 | cut -d "_" -f 2 | cut -d "-" -f 1 | sed -e 's|1%3a||g' | sed -e 's|.dfsg||g' )
  echo $VERSION
}
