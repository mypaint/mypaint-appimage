#!/bin/bash

echo ""
echo "########################################################################"
echo ""
echo "Copying GTK libraries and configuration files"
echo ""

set -e

# Manually copy librsvg, because it is not picked automatically by copy_deps
echo "========= copying LibRSVG ========="
mkdir -p "$APPDIR/usr/lib"
RSVG_LIBDIR=$(pkg-config --variable=libdir librsvg-2.0)
if [ -n "${RSVG_LIBDIR}" ]; then
	cp -a "${RSVG_LIBDIR}"/librsvg*.so* "$APPDIR/usr/lib"
fi


echo ""
echo "========= compile Glib schemas ========="
# Compile Glib schemas
glib_prefix="$(pkg-config --variable=prefix glib-2.0)"
mkdir -p "$APPDIR/usr/share/glib-2.0/schemas/"
cp -a "${glib_prefix}"/share/glib-2.0/schemas/* "$APPDIR/usr/share/glib-2.0/schemas"
cd "$APPDIR/usr/share/glib-2.0/schemas/"
glib-compile-schemas .
cd -


echo ""
echo "========= copy gdk-pixbuf modules and cache file ========="
# Copy gdk-pixbuf modules and cache file, and patch the cache file
# so that modules are picked from the AppImage bundle
gdk_pixbuf_moduledir="$(pkg-config --variable=gdk_pixbuf_moduledir gdk-pixbuf-2.0)"
gdk_pixbuf_cache_file="$(pkg-config --variable=gdk_pixbuf_cache_file gdk-pixbuf-2.0)"
gdk_pixbuf_libdir_bundle="lib/gdk-pixbuf-2.0"
gdk_pixbuf_cache_file_bundle="$APPDIR/usr/${gdk_pixbuf_libdir_bundle}/loaders.cache"

mkdir -p "$APPDIR/usr/${gdk_pixbuf_libdir_bundle}"
cp -a "$gdk_pixbuf_moduledir" "$APPDIR/usr/${gdk_pixbuf_libdir_bundle}"
cp -a "$gdk_pixbuf_cache_file" "$APPDIR/usr/${gdk_pixbuf_libdir_bundle}"
sed -i -e "s|${gdk_pixbuf_moduledir}/||g" "$gdk_pixbuf_cache_file_bundle"

printf '%s\n' "" "==================" "gdk-pixbuf cache:"
cat "$gdk_pixbuf_cache_file_bundle"
printf '%s\n' "==================" "gdk-pixbuf loaders:"
ls "$APPDIR/usr/${gdk_pixbuf_libdir_bundle}/loaders"
printf '%s\n' "=================="


echo "GTK bundling finished"
