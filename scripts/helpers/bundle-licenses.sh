#!/bin/bash

# Bundles the licenses of the libraries and assets in the appimage

normalized_md5() {
    # Creates a hash identity/file pair, normalizing the input data
    # to ignore differences in wrapping or whitespace use.
    local oldaddr;
    local newaddr;
    # Normalize and use correct FSF address for GPL-licenses,
    # to avoid practically identical duplicate license files.
    oldaddr='5. [^0-9]*[35]..[,.]? Boston,? MA[,.]? 0211.-13..[,.]? USA[,.]?'
    newaddr='51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA'
    # Replace newlines and tabs and consecutive spaces with single spaces
    tr '	' ' ' < "$1" | tr '\n' ' ' | sed -E 's/ +/ /g' |
        sed -E 's/^ //; s/ $//;'"s/$oldaddr/$newaddr/g" | md5sum  | sed -E 's; -$;'"$1"';';
}

(
    cd /usr/share/licenses/
    # Remove licenses for some of the libs which are not bundled
    # (some of them have dummy symlinks bundled, but not the actual libs)
    rm -rf gmp-6* krb5* cryptsetup* swig3* openss* glib-networking* nss-pem*
    # Fetch licenses for mypaint/libmypaint/mypaint-brushes
    mkdir mypaint libmypaint mypaint-brushes
    cp $APPIM_SOURCES/mypaint/COPYING mypaint
    cp $APPIM_SOURCES/libmypaint/COPYING libmypaint
    cp $APPIM_SOURCES/mypaint-brushes/COPYING mypaint-brushes
    cp $APPIM_SOURCES/mypaint-brushes/Licenses* mypaint-brushes

    # De-duplicate functionally identical licenses by linking to the same file.
    export IFS=$'\n'
    for hashpair in $(for f in $(find . -type f); do normalized_md5 "$f"; done | sort -k1,1)
    do
        IFS=' ' read -r hash file <<< "$hashpair"
        if [ -n "$hash" -a "$hash" = "$PREVHASH" ]
        then
            rm "$file" && ln "$PREVFILE" "$file"
        fi
        PREVHASH="$hash"
        PREVFILE="$file"
    done

    ARCH="licenses.tar.xz"
    # Bundle together in a compressed archive
    tar -I"xz" -cf "$ARCH" *
    mv "$ARCH" "$APPDIR/"
)
